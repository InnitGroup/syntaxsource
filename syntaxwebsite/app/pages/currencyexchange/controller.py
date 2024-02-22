from app.services.economy import GetUserBalance, DecrementTargetBalance, IncrementTargetBalance
from app.enums.TransactionType import TransactionType
from app.models.exchange_offer import ExchangeOffer
from app.models.user import User
from app.util import auth, transactions, redislock, websiteFeatures
from app.extensions import db, limiter, redis_controller
from datetime import datetime, timedelta
from app.pages.messages.messages import CreateSystemMessage
from sqlalchemy import case
from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, flash, abort

import redis_lock
CurrencyExchangeRoute = Blueprint("currencyexchange", __name__, url_prefix="/currency-exchange")

@CurrencyExchangeRoute.errorhandler(429)
def ratelimit_handler(e):
    flash("You are being ratelimited.", "danger")
    return redirect(request.referrer)

@CurrencyExchangeRoute.route("/", methods=["GET"])
@auth.authenticated_required
def index():
    CategoryType : str = request.args.get(
        key = "category",
        default = "all",
        type = str
    )
    SortType : str = request.args.get(
        key = "sort",
        default = "best",
        type = str
    )
    PageNumber : int = request.args.get(
        key = "page",
        default = 1,
        type = int
    )
    
    if CategoryType not in ["tr", "rt", "all"]:
        CategoryType = "all"
    if SortType not in ["best", "worst", "created"]:
        SortType = "best"
    if PageNumber < 1:
        PageNumber = 1

    QueryObj = ExchangeOffer.query
    QueryObj = QueryObj.filter_by(
        reciever_id = None
    )
    if CategoryType == "tr":
        QueryObj = QueryObj.filter_by(
            offer_currency_type = 1
        )
    elif CategoryType == "rt":
        QueryObj = QueryObj.filter_by(
            offer_currency_type = 0
        )
    
    if SortType == "best":
        if CategoryType == "rt":
            QueryObj = QueryObj.order_by(
                ExchangeOffer.ratio.asc()
            )
        elif CategoryType == "tr":
            QueryObj = QueryObj.order_by(
                ExchangeOffer.ratio.desc()
            )
        else:
            QueryObj = QueryObj.order_by(
                ExchangeOffer.worth.desc()
            )
    elif SortType == "worst":
        if CategoryType == "rt":
            QueryObj = QueryObj.order_by(
                ExchangeOffer.ratio.desc()
            )
        elif CategoryType == "tr":
            QueryObj = QueryObj.order_by(
                ExchangeOffer.ratio.asc()
            )
        else:
            QueryObj = QueryObj.order_by(
                ExchangeOffer.worth.asc()
            )
    else:
        QueryObj = QueryObj.order_by(
            ExchangeOffer.created_at.desc()
        )
    
    QueryObj = QueryObj.paginate(
        page = PageNumber,
        per_page = 15,
        error_out = False
    )

    for Offer in QueryObj.items:
        Offer : ExchangeOffer
        if Offer.expires_at < datetime.utcnow():
            IncrementTargetBalance(Offer.creator, Offer.offer_value, Offer.offer_currency_type)
            transactions.CreateTransaction(
                Reciever = Offer.creator,
                Sender = User.query.filter_by(id = 1).first(),
                CurrencyAmount = Offer.offer_value,
                CurrencyType = Offer.offer_currency_type,
                TransactionType = TransactionType.Sale,
                AssetId = None,
                CustomText = "Offer expired."
            )

            db.session.delete(Offer)
            db.session.commit()
            continue

    return render_template(
        "currencyexchange/index.html",
        offers = QueryObj.items,
        hasNextPage = QueryObj.has_next,
        hasPrevPage = QueryObj.has_prev,
        PageCategory = CategoryType,
        SortType = SortType,
        PageNumber = PageNumber
    )

@CurrencyExchangeRoute.route("/view/<int:OfferId>", methods=["GET"])
@auth.authenticated_required
def viewOffer(OfferId : int):
    OfferObj : ExchangeOffer = ExchangeOffer.query.filter_by(
        id = OfferId
    ).first()
    if OfferObj is None:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    return render_template(
        "currencyexchange/view.html",
        offer = OfferObj,
        AuthenticatedUser = AuthenticatedUser
    )

@CurrencyExchangeRoute.route("/delete/<int:OfferId>", methods=["POST"])
@auth.authenticated_required
def deleteOffer(OfferId : int):
    OfferObj : ExchangeOffer = ExchangeOffer.query.filter_by(
        id = OfferId
    ).first()
    if OfferObj is None:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    if OfferObj.creator_id != AuthenticatedUser.id:
        return abort(403)
    
    if websiteFeatures.GetWebsiteFeature("CurrencyExchange") is False:
        flash("Currency exchange is currently disabled.", "error")
        return redirect(f"/currency-exchange/view/{OfferId}")

    try:
        with redis_lock.Lock( redis_client = redis_controller, name = f"currency_exchange_order:{OfferId}", expire = 15, auto_renewal = True ):
            OfferObj : ExchangeOffer = ExchangeOffer.query.filter_by(
                id = OfferId
            ).first()
            if OfferObj.reciever_id is not None:
                return abort(403)
            
            IncrementTargetBalance(OfferObj.creator, OfferObj.offer_value, OfferObj.offer_currency_type)
            transactions.CreateTransaction(
                Reciever = OfferObj.creator,
                Sender = User.query.filter_by(id = 1).first(),
                CurrencyAmount = OfferObj.offer_value,
                CurrencyType = OfferObj.offer_currency_type,
                TransactionType = TransactionType.Sale,
                AssetId = None,
                CustomText = "Offer cancelled."
            )

            db.session.delete(OfferObj)
            db.session.commit()

            flash("Offer successfully deleted.", "success")
            return redirect("/currency-exchange/")
    except AssertionError:
        flash("Failed to delete offer, try again later.", "error")
        return redirect(f"/currency-exchange/view/{OfferId}")

@CurrencyExchangeRoute.route("/fill/<int:OfferId>", methods=["POST"])
@auth.authenticated_required
@limiter.limit("40/minute")
def fillOffer(OfferId : int):
    OfferObj : ExchangeOffer = ExchangeOffer.query.filter_by(
        id = OfferId
    ).first()
    if OfferObj is None:
        return abort(404)
    
    if websiteFeatures.GetWebsiteFeature("CurrencyExchange") is False:
        flash("Currency exchange is currently disabled.", "error")
        return redirect(f"/currency-exchange/view/{OfferId}")
    
    LockName = f"currency_exchange_order:{str(OfferId)}"
    try:
        with redis_lock.Lock( redis_client = redis_controller, name = LockName, expire = 15, auto_renewal = True ):
            OfferObj : ExchangeOffer = ExchangeOffer.query.filter_by(
                id = OfferId
            ).first()

            AuthenticatedUser : User = auth.GetCurrentUser()
            if OfferObj.creator_id == AuthenticatedUser.id:
                return abort(403)
            if OfferObj.reciever_id is not None:
                return abort(403)
            
            if OfferObj.expires_at < datetime.utcnow():
                return abort(403)
            
            SendingCurrencyType : int = 0 if OfferObj.offer_currency_type == 1 else 1
            UserRobuxBal, UserTicketsBal = GetUserBalance(AuthenticatedUser)
            if SendingCurrencyType == 0:
                if UserRobuxBal < OfferObj.receive_value:
                    flash("You do not have enough Robux to fill this offer.", "error")
                    return redirect(f"/currency-exchange/view/{OfferId}")
            else:
                if UserTicketsBal < OfferObj.receive_value:
                    flash("You do not have enough Tickets to fill this offer.", "error")
                    return redirect(f"/currency-exchange/view/{OfferId}")
            
            transactions.CreateTransaction(
                Reciever = OfferObj.creator,
                Sender = User.query.filter_by(id = 1).first(), # Remain anonymous
                CurrencyAmount = OfferObj.receive_value,
                CurrencyType = SendingCurrencyType,
                TransactionType = TransactionType.Sale,
                AssetId = None,
                CustomText = f"Currency Exchange Order ({OfferId}) Filled"
            )
            transactions.CreateTransaction(
                Reciever = AuthenticatedUser,
                Sender = User.query.filter_by(id = 1).first(), # Remain anonymous
                CurrencyAmount = OfferObj.offer_value,
                CurrencyType = OfferObj.offer_currency_type,
                TransactionType = TransactionType.Sale,
                AssetId = None,
                CustomText = f"Currency Exchange Order ({OfferId}) Filled"
            )
            transactions.CreateTransaction(
                Reciever = User.query.filter_by(id = 1).first(), # Remain anonymous
                Sender = AuthenticatedUser,
                CurrencyAmount = OfferObj.receive_value,
                CurrencyType = SendingCurrencyType,
                TransactionType = TransactionType.Purchase,
                AssetId = None,
                CustomText = f"Currency Exchange Order ({OfferId}) Filled"
            )
            DecrementTargetBalance(AuthenticatedUser, OfferObj.receive_value, SendingCurrencyType)
            IncrementTargetBalance(AuthenticatedUser, OfferObj.offer_value, OfferObj.offer_currency_type)
            IncrementTargetBalance(OfferObj.creator, OfferObj.receive_value, SendingCurrencyType)

            OfferObj.reciever_id = AuthenticatedUser.id
            db.session.commit()

            CreateSystemMessage(
                subject = "Offer Filled",
                message = f"Your currency exchange offer ({OfferId}) has been filled, you have received {OfferObj.receive_value} {'Robux' if OfferObj.offer_currency_type == 1 else 'Tickets'} in exchange for {OfferObj.offer_value} {'Robux' if OfferObj.offer_currency_type == 0 else 'Tickets'}.",
                userid = OfferObj.creator_id
            )

            flash("Offer successfully filled.", "success")
            return redirect(f"/currency-exchange/view/{OfferId}")
    except AssertionError:
        flash("Failed to fill offer, try again later.", "error")
        return redirect(f"/currency-exchange/view/{OfferId}")

@CurrencyExchangeRoute.route("/create", methods=["GET"])
@auth.authenticated_required
def createOfferPage():
    return render_template("currencyexchange/create.html")

@CurrencyExchangeRoute.route("/create", methods=["POST"])
@auth.authenticated_required
@limiter.limit("40/minute")
def createOffer():
    AuthenticatedUser : User = auth.GetCurrentUser()

    OfferCurrencyType : int = request.form.get(
        key = "offer-currency-type",
        default = None,
        type = int
    )
    OfferValue : int = request.form.get(
        key = "offer-currency-amount",
        default = None,
        type = int
    )
    ReceiveValue : int = request.form.get(
        key = "exchange-currency-amount",
        default = None,
        type = int
    )
    if OfferCurrencyType is None or OfferValue is None or ReceiveValue is None:
        flash("Invalid request", "error")
        return redirect("/currency-exchange/create")
    
    if OfferValue <= 0 or ReceiveValue <= 0:
        flash("Invalid request", "error")
        return redirect("/currency-exchange/create")
    
    if websiteFeatures.GetWebsiteFeature("CurrencyExchange") is False:
        flash("Currency exchange is currently disabled.", "error")
        return redirect(f"/currency-exchange/create")

    try:
        with redis_lock.Lock( redis_client = redis_controller, name = f"currency_exchange_create_offer:{AuthenticatedUser.id}", expire = 15, auto_renewal = True ):
            ActiveOffers : int = ExchangeOffer.query.filter_by(
                creator_id = AuthenticatedUser.id,
                reciever_id = None
            ).filter(
                ExchangeOffer.expires_at > datetime.utcnow()
            ).count()

            if ActiveOffers >= 25:
                flash("You have too many active offers, please cancel them to create a new offer.", "error")
                return redirect("/currency-exchange/create")

            if OfferCurrencyType == 0:
                if OfferValue < 5:
                    flash("You can only create offers of 5 Robux or more.", "error")
                    return redirect("/currency-exchange/create")
                if OfferValue > 10000:
                    flash("You can only create offers up to 10,000 Robux.", "error")
                    return redirect("/currency-exchange/create")
                Ratio = ReceiveValue / OfferValue
            else:
                if OfferValue < 10:
                    flash("You can only create offers of 10 Tickets or more.", "error")
                    return redirect("/currency-exchange/create")
                if OfferValue > 100000:
                    flash("You can only create offers up to 100,000 Tickets.", "error")
                    return redirect("/currency-exchange/create")
                Ratio = OfferValue / ReceiveValue
            
            if Ratio < 2 or Ratio > 20:
                flash("Bad exchange ratio", "error")
                return redirect("/currency-exchange/create")
            
            UserRobuxBal, UserTicketsBal = GetUserBalance(AuthenticatedUser)
            if OfferCurrencyType == 0 and UserRobuxBal < OfferValue:
                flash("You do not have enough Robux to create this offer.", "error")
                return redirect("/currency-exchange/create")
            elif OfferCurrencyType == 1 and UserTicketsBal < OfferValue:
                flash("You do not have enough Tickets to create this offer.", "error")
                return redirect("/currency-exchange/create")
            
            DecrementTargetBalance(AuthenticatedUser, OfferValue, OfferCurrencyType)
            transactions.CreateTransaction(
                Reciever = User.query.filter_by(id=1).first(),
                Sender = AuthenticatedUser,
                CurrencyAmount = OfferValue,
                CurrencyType = OfferCurrencyType,
                TransactionType = TransactionType.Purchase,
                CustomText = "Created Exchange Order"
            )

            NewOffer : ExchangeOffer = ExchangeOffer(
                creator_id = AuthenticatedUser.id,
                offer_value = OfferValue,
                receive_value = ReceiveValue,
                offer_currency_type = OfferCurrencyType,
                created_at = datetime.utcnow(),
                expires_at = datetime.utcnow() + timedelta(days=31),
                ratio = Ratio,
                worth = abs( 20 - Ratio ) if OfferCurrencyType == 0 else ( 20 - abs( Ratio - 20 ) )
            )
            db.session.add(NewOffer)
            db.session.commit()

            flash("Offer created successfully", "success")
            return redirect("/currency-exchange/")
    except AssertionError:
        flash("Failed to create offer, try again later.", "error")
        return redirect("/currency-exchange/create")