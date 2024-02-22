from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort
from app.util import auth, redislock, websiteFeatures
from app.extensions import limiter, db, csrf, user_limiter
from app.models.user_trade_items import UserTradeItem
from app.models.user_trades import UserTrade
from app.models.user import User
from app.models.asset import Asset
from app.models.userassets import UserAsset
from app.models.usereconomy import UserEconomy
from app.models.asset_rap import AssetRap
from app.models.limited_item_transfers import LimitedItemTransfer
from app.util.membership import GetUserMembership
from app.enums.MembershipType import MembershipType
from app.enums.TradeStatus import TradeStatus
from app.enums.LimitedItemTransferMethod import LimitedItemTransferMethod
from datetime import datetime, timedelta
import math

TradesPageRoute = Blueprint('trades', __name__, template_folder="pages")

@TradesPageRoute.route("/trade", methods=['GET'])
@auth.authenticated_required
def trades():
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeInfo = []

    PageCategory = request.args.get("category", default="inbound", type=str)
    PageCategory = PageCategory.lower()
    PageNumber = request.args.get("page", default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1

    if PageCategory == "inbound":
        TradeListObj : list[UserTrade] = UserTrade.query.filter_by(recipient_userid=AuthenticatedUser.id, status=TradeStatus.Pending).order_by(UserTrade.updated_at.desc()).paginate( per_page=15, page=PageNumber, error_out=False )
        for TradeObj in TradeListObj:
            OppositeUser : User = User.query.filter_by(id=TradeObj.sender_userid).first()
            if OppositeUser is None:
                continue
            TradeInfo.append({
                "TradeID": TradeObj.id,
                "TradeStatus": TradeObj.status,
                "Created": datetime.strftime(TradeObj.created_at, "%d/%m/%Y %H:%M:%S UTC"),
                "Expiration": datetime.strftime(TradeObj.expires_at, "%d/%m/%Y %H:%M:%S UTC"),
                "OppositeUser": OppositeUser
            })
    elif PageCategory == "outbound":
        TradeListObj : list[UserTrade] = UserTrade.query.filter_by(sender_userid=AuthenticatedUser.id, status=TradeStatus.Pending).order_by(UserTrade.updated_at.desc()).paginate( per_page=15, page=PageNumber, error_out=False )
        for TradeObj in TradeListObj:
            OppositeUser : User = User.query.filter_by(id=TradeObj.recipient_userid).first()
            if OppositeUser is None:
                continue
            TradeInfo.append({
                "TradeID": TradeObj.id,
                "TradeStatus": TradeObj.status,
                "Created": datetime.strftime(TradeObj.created_at, "%d/%m/%Y %H:%M:%S UTC"),
                "Expiration": datetime.strftime(TradeObj.expires_at, "%d/%m/%Y %H:%M:%S UTC"),
                "OppositeUser": OppositeUser
            })
    elif PageCategory == "completed":
        TradeListObj : list[UserTrade] = UserTrade.query.filter((UserTrade.recipient_userid == AuthenticatedUser.id) | (UserTrade.sender_userid == AuthenticatedUser.id)).filter_by(status=TradeStatus.Accepted).order_by(UserTrade.updated_at.desc()).paginate( per_page=15, page=PageNumber, error_out=False )
        for TradeObj in TradeListObj:
            if TradeObj.recipient_userid == AuthenticatedUser.id:
                OppositeUser : User = User.query.filter_by(id=TradeObj.sender_userid).first()
            else:
                OppositeUser : User = User.query.filter_by(id=TradeObj.recipient_userid).first()
            if OppositeUser is None:
                continue
            TradeInfo.append({
                "TradeID": TradeObj.id,
                "TradeStatus": TradeObj.status,
                "Created": datetime.strftime(TradeObj.created_at, "%d/%m/%Y %H:%M:%S UTC"),
                "Expiration": datetime.strftime(TradeObj.expires_at, "%d/%m/%Y %H:%M:%S UTC"),
                "OppositeUser": OppositeUser
            })
    elif PageCategory == "inactive": # inactive trades
        TradeListObj : list[UserTrade] = UserTrade.query.filter((UserTrade.recipient_userid == AuthenticatedUser.id) | (UserTrade.sender_userid == AuthenticatedUser.id)).filter( (UserTrade.status == TradeStatus.Declined) | (UserTrade.status == TradeStatus.Expired) | (UserTrade.status == TradeStatus.Cancelled)).order_by(UserTrade.updated_at.desc()).paginate( per_page=15, page=PageNumber, error_out=False )
        for TradeObj in TradeListObj:
            if TradeObj.recipient_userid == AuthenticatedUser.id:
                OppositeUser : User = User.query.filter_by(id=TradeObj.sender_userid).first()
            else:
                OppositeUser : User = User.query.filter_by(id=TradeObj.recipient_userid).first()
            if OppositeUser is None:
                continue
            TradeInfo.append({
                "TradeID": TradeObj.id,
                "TradeStatus": TradeObj.status,
                "Created": datetime.strftime(TradeObj.created_at, "%d/%m/%Y %H:%M:%S UTC"),
                "Expiration": datetime.strftime(TradeObj.expires_at, "%d/%m/%Y %H:%M:%S UTC"),
                "OppositeUser": OppositeUser
            })
    else:
        return abort(404)

    return render_template("trades/index.html", TradeInfo=TradeInfo, PageCategory=PageCategory, TradeListObj=TradeListObj)

@TradesPageRoute.route("/trade/<int:userid>/create", methods=['GET'])
@auth.authenticated_required
def createTrade(userid : int):
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id == userid:
        return abort(400)
    UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser)
    if UserCurrentMembership == MembershipType.NonBuildersClub:
        return redirect("/membership")
    TargetUser : User = User.query.filter_by(id=userid).first()
    if TargetUser is None:
        return abort(404)
    if TargetUser.accountstatus == 4 or TargetUser.accountstatus == 3:
        return abort(404)
    return render_template("trades/create.html", TargetUser=TargetUser, AuthenticatedUser=AuthenticatedUser)

@TradesPageRoute.route("/trade/<int:userid>/create", methods=['POST'])
@auth.authenticated_required
@limiter.limit("5/second")
@user_limiter.limit("5/second")
def createTradePost(userid : int):
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id == userid:
        return jsonify({"success": False, "message": "You cannot trade with yourself."}),400

    if not websiteFeatures.GetWebsiteFeature("ItemTrading"):
        return jsonify({"success": False, "message": "Item trading is temporarily disabled."}),403

    TargetUser : User = User.query.filter_by(id=userid).first()
    if TargetUser is None:
        return jsonify({"success": False, "message": "User not found."}),404
    if TargetUser.accountstatus == 4 or TargetUser.accountstatus == 3:
        return jsonify({"success": False, "message": "User not found."}),404
    TradeRequestData : dict = request.json
    if TradeRequestData is None:
        return jsonify({"success": False, "message": "Invalid request data."}),400
    UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser)
    if UserCurrentMembership == MembershipType.NonBuildersClub:
        return jsonify({"success": False, "message": "You must be a Builders Club member to send trades."}),403
    OppositeUserCurrentMembership : MembershipType = GetUserMembership(TargetUser)
    if OppositeUserCurrentMembership == MembershipType.NonBuildersClub:
        return jsonify({"success": False, "message": "The opposite user must be a Builders Club member to accept trades."}),403
    """
        Expected JSON:
        "RequesterOfferRobux": RequesterOfferRobux, # int must be >= 0 <= 100000
        "TargetOfferRobux": TargetOfferRobux, # int must be >= 0 and <= 100000
        "RequesterOfferUAIDs": RequesterOfferUAIDs, # list of int
        "TargetOfferUAIDs": TargetOfferUAIDs, # list of int
        "TOTPCode": isTOTPEnabled ? TOTPInputElement.value : null # int or null
    """
    
    # RequesterOfferRobux : int = TradeRequestData.get("RequesterOfferRobux", 0)
    # TargetOfferRobux : int = TradeRequestData.get("TargetOfferRobux", 0)
    # RequesterOfferUAIDs : list = TradeRequestData.get("RequesterOfferUAIDs", [])
    # TargetOfferUAIDs : list = TradeRequestData.get("TargetOfferUAIDs", [])
    # TOTPCode : int | None = TradeRequestData.get("TOTPCode", None, type=int)

    # if not all(key in TradeRequestData for key in ("RequesterOfferRobux", "TargetOfferRobux", "RequesterOfferUAIDs", "TargetOfferUAIDs", "TOTPCode")):
    #     return jsonify({"success": False, "message": "Invalid request data."}),400
    # if not isinstance(TradeRequestData["RequesterOfferRobux"], int) or not isinstance(TradeRequestData["TargetOfferRobux"], int):
    #     return jsonify({"success": False, "message": "Invalid request data, Robux Offer must be an integer."}),400
    # if not isinstance(TradeRequestData["RequesterOfferUAIDs"], list) or not isinstance(TradeRequestData["TargetOfferUAIDs"], list):
    #     return jsonify({"success": False, "message": "Invalid request data, Offered UAIDs must be a list."}),400
    # if not isinstance(TradeRequestData["TOTPCode"], int) and TradeRequestData["TOTPCode"] is not None:
    #     return jsonify({"success": False, "message": "Invalid request data, TOTP code must be an integer."}),400
    
    try:
        assert "RequesterOfferRobux" in TradeRequestData, "Missing parameter RequesterOfferRobux"
        assert "TargetOfferRobux" in TradeRequestData, "Missing parameter TargetOfferRobux"
        assert "RequesterOfferUAIDs" in TradeRequestData, "Missing parameter RequesterOfferUAIDs"
        assert "TargetOfferUAIDs" in TradeRequestData, "Missing parameter TargetOfferUAIDs"
        assert "TOTPCode" in TradeRequestData, "Missing parameter TOTPCode"
        assert isinstance(TradeRequestData["RequesterOfferRobux"], int), "Invalid request data, Robux Offer must be an integer."
        assert isinstance(TradeRequestData["TargetOfferRobux"], int), "Invalid request data, Target Robux Offer must be an integer."
        assert isinstance(TradeRequestData["RequesterOfferUAIDs"], list), "Invalid request data, Offered UAIDs must be a list."
        assert isinstance(TradeRequestData["TargetOfferUAIDs"], list), "Invalid request data, Offered UAIDs must be a list."
        assert isinstance(TradeRequestData["TOTPCode"], int) or TradeRequestData["TOTPCode"] is None, "Invalid request data, TOTP code must be an integer or null."
    except Exception as e:
        return jsonify({"success": False, "message": f"Payload Validation failed, {str(e)}"}), 400
    
    TotalTradesActive : int = UserTrade.query.filter_by(sender_userid=AuthenticatedUser.id, status=TradeStatus.Pending).count()
    if TotalTradesActive >= 25:
        return jsonify({"success": False, "message": "You cannot have more than 25 active trades at once."}),400
    ActiveTradesWithTarget : int = UserTrade.query.filter_by(sender_userid=AuthenticatedUser.id, recipient_userid=TargetUser.id, status=TradeStatus.Pending).count()
    if ActiveTradesWithTarget >= 2:
        return jsonify({"success": False, "message": "You cannot have more than 2 active trades with the same user at once."}),400
    
    RequesterOfferRobux : int = TradeRequestData["RequesterOfferRobux"]
    TargetOfferRobux : int = TradeRequestData["TargetOfferRobux"]
    RequesterOfferUAIDs : list = TradeRequestData["RequesterOfferUAIDs"]
    TargetOfferUAIDs : list = TradeRequestData["TargetOfferUAIDs"]
    TOTPCode : int | None = TradeRequestData["TOTPCode"]

    if (RequesterOfferRobux < 0 or TargetOfferRobux < 0) or (RequesterOfferRobux > 100000 or TargetOfferRobux > 100000):
        return jsonify({"success": False, "message": "Invalid request data, Robux Offer must be between 0 - 100000"}),400
    
    if len(RequesterOfferUAIDs) > 4 or len(TargetOfferUAIDs) > 4:
        return jsonify({"success": False, "message": "Invalid request data, cannot trade more than 4 items at once."}),400
    
    if len(RequesterOfferUAIDs) <= 0 or len(TargetOfferUAIDs) <= 0:
        return jsonify({"success": False, "message": "Invalid request data, both request and offer must contain at least one item"}),400
    
    if AuthenticatedUser.TOTPEnabled:
        if TOTPCode is None:
            return jsonify({"success": False, "message": "Invalid request data, TOTP code is required."}),400
        if not auth.Validate2FACode(AuthenticatedUser.id, int(TOTPCode)):
            return jsonify({"success": False, "message": "Invalid request data, TOTP code is invalid."}),400
    
    for UAID in RequesterOfferUAIDs:
        UserAssetObj : UserAsset = UserAsset.query.filter_by(id=UAID).first()
        if UserAssetObj is None:
            return jsonify({"success": False, "message": "Invalid request data, one of the items is invalid."}),400
        if UserAssetObj.userid != AuthenticatedUser.id:
            return jsonify({"success": False, "message": f"Invalid request data, you do not own UAID {str(UAID)}"}),400
        AssetObj : Asset = Asset.query.filter_by(id=UserAssetObj.assetid).first()
        if not AssetObj.is_limited or AssetObj.is_for_sale:
            return jsonify({"success": False, "message": f"Invalid request data, you cannot trade UAID {str(UAID)}"}),400
    
    for UAID in TargetOfferUAIDs:
        UserAssetObj : UserAsset = UserAsset.query.filter_by(id=UAID).first()
        if UserAssetObj is None:
            return jsonify({"success": False, "message": "Invalid request data, one of the items is invalid."}),400
        if UserAssetObj.userid != TargetUser.id:
            return jsonify({"success": False, "message": f"Invalid request data, user does not own UAID {str(UAID)}"}),400
        AssetObj : Asset = Asset.query.filter_by(id=UserAssetObj.assetid).first()
        if not AssetObj.is_limited or AssetObj.is_for_sale:
            return jsonify({"success": False, "message": f"Invalid request data, you cannot trade UAID {str(UAID)}"}),400
        
    NewUserTrade : UserTrade = UserTrade(
        sender_userid = AuthenticatedUser.id,
        recipient_userid = TargetUser.id,
        sender_userid_robux = RequesterOfferRobux,
        recipient_userid_robux = TargetOfferRobux,
        status = TradeStatus.Pending,
        expires_at = datetime.utcnow() + timedelta(days=7)
    )
    try:
        db.session.add(NewUserTrade)
        db.session.commit()

        for UAID in RequesterOfferUAIDs:
            NewTradeAsset : UserTradeItem = UserTradeItem(
                tradeid = NewUserTrade.id,
                userid = AuthenticatedUser.id,
                user_asset_id = UAID
            )
            db.session.add(NewTradeAsset)
        
        for UAID in TargetOfferUAIDs:
            NewTradeAsset : UserTradeItem = UserTradeItem(
                tradeid = NewUserTrade.id,
                userid = TargetUser.id,
                user_asset_id = UAID
            )
            db.session.add(NewTradeAsset)
        
        db.session.commit()
    except:
        db.session.delete(NewUserTrade)
        return jsonify({"success": False, "message": "Internal server error"}),500
    return jsonify({"success": True, "message": "Trade request sent.", "tradeId": NewUserTrade.id}),200

@TradesPageRoute.route("/trade/view/<int:tradeid>", methods=['GET'])
@auth.authenticated_required_api
def viewTrade(tradeid : int):
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return abort(404)
    if TradeObj.sender_userid != AuthenticatedUser.id and TradeObj.recipient_userid != AuthenticatedUser.id:
        return abort(403)
    
    if TradeObj.expires_at < datetime.utcnow() and TradeObj.status == TradeStatus.Pending:
        TradeObj.status = TradeStatus.Expired
        TradeObj.updated_at = datetime.utcnow()
        db.session.commit()

    TradeItems : list[UserTradeItem] = UserTradeItem.query.filter_by(tradeid=TradeObj.id).all()
    SenderUser : User = User.query.filter_by(id=TradeObj.sender_userid).first()
    RecipientUser : User = User.query.filter_by(id=TradeObj.recipient_userid).first()

    SenderItems = []
    RecipientItems = []

    AssetRAPCache = {}
    def GetAssetRAP( AssetID : int ):
        if AssetID in AssetRAPCache:
            return AssetRAPCache[AssetID]
        AssetRAPObj : AssetRap | None = AssetRap.query.filter_by(assetid=AssetID).first()
        if AssetRAPObj is None:
            return 0
        AssetRAPCache[AssetID] = AssetRAPObj.rap
        return AssetRAPCache[AssetID]
    SenderOfferValue = 0
    RecipientOfferValue = 0

    for TradeItem in TradeItems:
        UserAssetObj : UserAsset = UserAsset.query.filter_by(id=TradeItem.user_asset_id).first()
        AssetObj : Asset = Asset.query.filter_by(id=UserAssetObj.assetid).first()
        if TradeItem.userid == SenderUser.id:
            SenderItems.append({
                "UAID": UserAssetObj.id,
                "Name": AssetObj.name,
                "AssetId": AssetObj.id,
                "RAP": GetAssetRAP(AssetObj.id),
                "serial": UserAssetObj.serial
            })
            SenderOfferValue += GetAssetRAP(AssetObj.id)
        else:
            RecipientItems.append({
                "UAID": UserAssetObj.id,
                "Name": AssetObj.name,
                "AssetId": AssetObj.id,
                "RAP": GetAssetRAP(AssetObj.id),
                "serial": UserAssetObj.serial
            })
            RecipientOfferValue += GetAssetRAP(AssetObj.id)
    
    SenderOfferValue += TradeObj.sender_userid_robux
    RecipientOfferValue += TradeObj.recipient_userid_robux
    OppositeUser = SenderUser if AuthenticatedUser.id == RecipientUser.id else RecipientUser

    return render_template("trades/view.html",
                           TradeObj = TradeObj,
                           SenderUser = SenderUser,
                           RecipientUser = RecipientUser,
                           AuthenticatedUser = AuthenticatedUser,
                           SenderItems = SenderItems,
                           RecipientItems = RecipientItems,
                           SenderOfferValue = SenderOfferValue,
                           RecipientOfferValue = RecipientOfferValue,
                           OppositeUser = OppositeUser)

@TradesPageRoute.route("/trade/<int:tradeid>/accept", methods=['POST'])
@auth.authenticated_required
def acceptTrade(tradeid : int):
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return abort(404)
    if TradeObj.recipient_userid != AuthenticatedUser.id:
        return abort(403)
    if TradeObj.status != TradeStatus.Pending:
        return abort(403)
    UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser.id)
    if UserCurrentMembership == MembershipType.NonBuildersClub:
        flash("You must be a Builders Club member to accept trades.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")
    OppositeUser : User = User.query.filter_by(id=TradeObj.sender_userid).first()
    if OppositeUser is None:
        flash("An error occured while trying to complete this trade. Please try again later.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")
    OppositeUserCurrentMembership : MembershipType = GetUserMembership(OppositeUser)
    if OppositeUserCurrentMembership == MembershipType.NonBuildersClub:
        flash("The opposite user must be a Builders Club member to accept trades.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")
    if AuthenticatedUser.TOTPEnabled:
        TOTPCode : str = request.form.get("totpcode", default=None, type=str)
        if TOTPCode is None:
            flash("Invalid TOTP code", "error")
            return redirect(f"/trade/view/{str(tradeid)}")
        if not auth.Validate2FACode(AuthenticatedUser.id, TOTPCode):
            flash("Invalid TOTP code", "error")
            return redirect(f"/trade/view/{str(tradeid)}")
        
    if TradeObj.expires_at < datetime.utcnow():
        flash("This trade has expired.", "error")
        TradeObj.status = TradeStatus.Expired
        db.session.commit()
        return redirect(f"/trade/view/{str(tradeid)}")

    TradeItems : list[UserTradeItem] = UserTradeItem.query.filter_by(tradeid=TradeObj.id).all()
    for TradeItem in TradeItems:
        UserAssetObj : UserAsset = UserAsset.query.filter_by(id=TradeItem.user_asset_id).first()
        if UserAssetObj is None:
            flash("One of the items no longer exists and this trade cannot be completed.", "error")
            return redirect(f"/trade/view/{str(tradeid)}")
        if UserAssetObj.userid != TradeItem.userid:
            flash("One of the items no longer belongs to its original owner and this trade cannot be completed.", "error")
            return redirect(f"/trade/view/{str(tradeid)}")
    
    SenderEconomyLock = redislock.acquire_lock(f"economy:{str(TradeObj.sender_userid)}", acquire_timeout=5, lock_timeout=3)
    RecipientEconomyLock = redislock.acquire_lock(f"economy:{str(TradeObj.recipient_userid)}", acquire_timeout=5, lock_timeout=3)
    if not SenderEconomyLock or not RecipientEconomyLock:
        if SenderEconomyLock:
            redislock.release_lock(f"economy:{str(TradeObj.sender_userid)}", SenderEconomyLock)
        flash("An error occured while trying to complete this trade. Please try again later.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")
    
    SenderEconomyObj : UserEconomy = UserEconomy.query.filter_by(userid=TradeObj.sender_userid).first()
    RecipientEconomyObj : UserEconomy = UserEconomy.query.filter_by(userid=TradeObj.recipient_userid).first()

    if SenderEconomyObj.robux < TradeObj.sender_userid_robux:
        flash("The sender does not have enough robux to complete this trade.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")
    if RecipientEconomyObj.robux < TradeObj.recipient_userid_robux:
        flash("The recipient does not have enough robux to complete this trade.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")

    ItemLocks = []
    for TradeItem in TradeItems:
        TradeItemLock = redislock.acquire_lock(f"item:{str(TradeItem.user_asset_id)}", acquire_timeout=20, lock_timeout=5)
        if not TradeItemLock:
            redislock.release_lock(f"economy:{str(TradeObj.sender_userid)}", SenderEconomyLock)
            redislock.release_lock(f"economy:{str(TradeObj.recipient_userid)}", RecipientEconomyLock)
            for ItemLock in ItemLocks:
                redislock.release_lock(f"item:{str(ItemLock[1])}", ItemLock[0])

            flash("An error occured while trying to complete this trade. Please try again later.", "error")
            return redirect(f"/trade/view/{str(tradeid)}")
        ItemLocks.append([TradeItemLock, TradeItem.user_asset_id])

    def ReleaseAllLocks():
        redislock.release_lock(f"economy:{str(TradeObj.sender_userid)}", SenderEconomyLock)
        redislock.release_lock(f"economy:{str(TradeObj.recipient_userid)}", RecipientEconomyLock)
        for ItemLock in ItemLocks:
            redislock.release_lock(f"item:{str(ItemLock[1])}", ItemLock[0])
    
    SenderEconomyObj.robux -= TradeObj.sender_userid_robux
    RecipientEconomyObj.robux -= TradeObj.recipient_userid_robux

    if TradeObj.sender_userid_robux > 0:
        FinalAdded = math.floor(TradeObj.sender_userid_robux * 0.7)
        RecipientEconomyObj.robux += FinalAdded
    if TradeObj.recipient_userid_robux > 0:
        FinalAdded = math.floor(TradeObj.recipient_userid_robux * 0.7)
        SenderEconomyObj.robux += FinalAdded

    def CreateItemTransferLog( original_owner_id : int, new_owner_id : int, asset_id : int, user_asset_id : int ):
        NewTransferLog = LimitedItemTransfer(
            original_owner_id = original_owner_id,
            new_owner_id = new_owner_id,
            asset_id = asset_id,
            user_asset_id = user_asset_id,
            transfer_method = LimitedItemTransferMethod.Trade,
            associated_trade_id = TradeObj.id
        )
        db.session.add(NewTransferLog)
    
    for TradeItem in TradeItems:
        UserAssetObj : UserAsset = UserAsset.query.filter_by(id=TradeItem.user_asset_id).first()
        if UserAssetObj is None:
            ReleaseAllLocks()
            flash("One of the items no longer exists and this trade cannot be completed.", "error")
            return redirect(f"/trade/view/{str(tradeid)}")
        if UserAssetObj.userid == TradeObj.sender_userid:
            CreateItemTransferLog( original_owner_id = TradeObj.sender_userid, new_owner_id = TradeObj.recipient_userid, asset_id = UserAssetObj.assetid, user_asset_id = UserAssetObj.id )
            UserAssetObj.userid = TradeObj.recipient_userid
        else:
            CreateItemTransferLog( original_owner_id = TradeObj.sender_userid, new_owner_id = TradeObj.recipient_userid, asset_id = UserAssetObj.assetid, user_asset_id = UserAssetObj.id )
            UserAssetObj.userid = TradeObj.sender_userid
        UserAssetObj.is_for_sale = False
        UserAssetObj.price = 0
        UserAssetObj.updated = datetime.utcnow()
    db.session.commit()
    ReleaseAllLocks()

    TradeObj.status = TradeStatus.Accepted
    TradeObj.updated_at = datetime.utcnow()
    db.session.commit()

    return redirect(f"/trade/view/{str(tradeid)}")

@TradesPageRoute.route("/trade/<int:tradeid>/cancel", methods=['POST'])
@auth.authenticated_required
def cancelTrade(tradeid : int):
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return abort(404)
    if TradeObj.sender_userid != AuthenticatedUser.id:
        return abort(403)
    if TradeObj.status != TradeStatus.Pending:
        return abort(403)
    
    if TradeObj.expires_at < datetime.utcnow():
        TradeObj.status = TradeStatus.Expired
        TradeObj.updated_at = datetime.utcnow()
        db.session.commit()
        flash("This trade has expired.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")

    TradeObj.status = TradeStatus.Cancelled
    TradeObj.updated_at = datetime.utcnow()
    db.session.commit()

    return redirect(f"/trade/view/{str(tradeid)}")

@TradesPageRoute.route("/trade/<int:tradeid>/decline", methods=['POST'])
@auth.authenticated_required
@csrf.exempt
def declineTrade(tradeid : int):
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return abort(404)
    if TradeObj.recipient_userid != AuthenticatedUser.id:
        return abort(403)
    if TradeObj.status != TradeStatus.Pending:
        return abort(403)
    
    if TradeObj.expires_at < datetime.utcnow():
        TradeObj.status = TradeStatus.Expired
        TradeObj.updated_at = datetime.utcnow()
        db.session.commit()
        flash("This trade has expired.", "error")
        return redirect(f"/trade/view/{str(tradeid)}")
    
    TradeObj.status = TradeStatus.Declined
    TradeObj.updated_at = datetime.utcnow()
    db.session.commit()

    return redirect(f"/trade/view/{str(tradeid)}")

@TradesPageRoute.route("/trade/<int:userid>/inventory", methods=['GET'])
@auth.authenticated_required_api
def getInventory(userid : int):
    pageNumber = request.args.get("page", default=1, type=int)

    TargetUser : User = User.query.filter_by(id=userid).first()
    if TargetUser is None:
        return abort(404)
    if TargetUser.accountstatus == 4 or TargetUser.accountstatus == 3:
        return abort(404)
    
    UserAssets : list[UserAsset] = UserAsset.query.join(Asset, UserAsset.assetid == Asset.id).filter(UserAsset.userid == TargetUser.id, Asset.is_limited == True, Asset.is_for_sale == False).paginate(page=pageNumber, error_out=False, max_per_page=12).items
    ReturnInfoData = []

    AssetRAPCache = {}
    def GetAssetRAP( AssetID : int ):
        if AssetID in AssetRAPCache:
            return AssetRAPCache[AssetID]
        AssetRAPObj : AssetRap | None = AssetRap.query.filter_by(assetid=AssetID).first()
        if AssetRAPObj is None:
            return 0
        AssetRAPCache[AssetID] = AssetRAPObj.rap
        return AssetRAPCache[AssetID]

    for UserAssetObj in UserAssets:
        AssetObj : Asset = Asset.query.filter_by(id=UserAssetObj.assetid).first()
        if AssetObj is None:
            continue
        ReturnInfoData.append({
            "id": AssetObj.id,
            "name": AssetObj.name,
            "serialNumber": UserAssetObj.serial,
            "uaid": UserAssetObj.id,
            "rap": GetAssetRAP(AssetObj.id),
        })
    isThereNextPage = len(UserAssets) == 12
    return jsonify({
        "data": ReturnInfoData,
        "nextPage": isThereNextPage
    })

