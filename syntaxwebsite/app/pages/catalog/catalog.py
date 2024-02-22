from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort
from app.util import auth, turnstile, websiteFeatures
from app.routes.thumbnailer import TakeUserThumbnail
from app.util.redislock import acquire_lock, release_lock
from app.extensions import db, csrf, limiter, redis_controller, user_limiter
from app.models.asset import Asset
from app.models.usereconomy import UserEconomy
from app.models.userassets import UserAsset
from app.models.user_avatar_asset import UserAvatarAsset
from app.models.user import User
from app.models.package_asset import PackageAsset
from app.models.gamepass_link import GamepassLink
from app.models.asset_rap import AssetRap
from app.models.groups import Group
from app.models.place_badge import PlaceBadge, UserBadge
from app.models.universe import Universe
from app.models.limited_item_transfers import LimitedItemTransfer
from app.routes.badgesapi import CalculateBadgeRarity, GetBadgeAwardedPastDay
from app.pages.catalog.catalogtypes import CatalogTypes
from app.pages.messages.messages import CreateSystemMessage
from slugify import slugify
from datetime import datetime
from sqlalchemy import text, and_, or_
import math
from app.enums.AssetType import AssetType
from app.util.transactions import CreateTransactionForSale
import logging
import calendar
import time
import redis_lock
from app.util.membership import GetUserMembership
from app.enums.MembershipType import MembershipType
from app.enums.LimitedItemTransferMethod import LimitedItemTransferMethod
from app.services.economy import IncrementTargetBalance, AdjustAssetRap, GetAssetRap, TaxCurrencyAmount, GetUserBalance, GetGroupBalance, DecrementTargetBalance,EconomyLockAcquireException, InsufficientFundsException
from app.services.groups import GetUserFromId, GetGroupFromId

CatalogRoute = Blueprint('catalog', __name__, template_folder="pages", url_prefix="/catalog")
LibraryRoute = Blueprint('library', __name__, template_folder="pages", url_prefix="/library")
BadgesPageRoute = Blueprint('badges_page', __name__, template_folder="pages", url_prefix="/badges")

def IncrementAssetCreator( AssetObject : Asset, AmountGiven : int, CurrencyType : int):
    """ Increments the robux of the asset creator"""
    CurrencyToGive = math.floor(AmountGiven * 0.7)
    if CurrencyToGive <= 0:
        return True
    
    if AssetObject.creator_type == 0:
        # User
        IncrementTargetBalance(GetUserFromId(AssetObject.creator_id), CurrencyToGive, CurrencyType)
        return True
    
    elif AssetObject.creator_type == 1:
        # Group
        IncrementTargetBalance(GetGroupFromId(AssetObject.creator_id), CurrencyToGive, CurrencyType)
        return True

def ConvertQueryToAsset( queryResult ):
    """Converts a query result to a dict with the same keys as the Asset model"""
    return {
        "id": queryResult[0],
        "roblox_asset_id": queryResult[1],
        "name": queryResult[2],
        "description": queryResult[3],
        "created_at": queryResult[4],
        "updated_at": queryResult[5],
        "asset_type": queryResult[6],
        "asset_genre": queryResult[7],
        "creator_type": queryResult[8],
        "creator_id": queryResult[9],
        "moderation_status": queryResult[10],
        "is_for_sale": queryResult[11],
        "price_robux": queryResult[12],
        "price_tix": queryResult[13],
        "is_limited": queryResult[14],
        "is_limited_unique": queryResult[15],
        "serial_count": queryResult[16],
        "sale_count": queryResult[17],
        "offsale_at": queryResult[18]
    }

OrderTypes = {
    0: "created_at DESC", # Default
    1: "price_robux ASC", # Lowest to Highest
    2: "price_robux DESC", # Highest to Lowest
    3: "updated_at DESC", # Recently Updated
    4: "sale_count DESC" # Best Selling
}

import urllib.parse

@CatalogRoute.route("/", methods=["POST"])
@auth.authenticated_required
@csrf.exempt
def catalog_search():
    CategoryType = int(request.args.get(key="category", default=0, type=int))
    OrderBy = request.form.get(key="order-by", default=0, type=int)
    if OrderBy not in OrderTypes:
        OrderBy = 0
    SearchQuery = request.form.get(key="search-input", default="", type=str)
    if len(SearchQuery) < 3:
        SearchQuery = ""
    if SearchQuery == "":
        return redirect(f"/catalog/?sort={OrderBy}&category={str(CategoryType)}")
    # Make sure the query is url safe
    SearchQuery = urllib.parse.quote(SearchQuery)

    return redirect(f"/catalog/?q={SearchQuery}&sort={OrderBy}&category={str(CategoryType)}")

@CatalogRoute.route("/", methods=["GET"])
@auth.authenticated_required
def catalog_page():
    CatalogType = int(request.args.get("category", 0))
    if CatalogType not in CatalogTypes:
        return redirect("/catalog/")
    if request.args.get("page") is None:
        Page = 1
    else:
        try:
            Page = int(request.args.get("page"))
        except:
            Page = 1
    SearchInput = request.args.get("q", "", type=str)
    """
        Types of sorting:
        0 - Relevance (Default) [ Just sort by created_at ]
        1 - Price (Lowest to Highest)
        2 - Price (Highest to Lowest)
        3 - Recently Updated
        4 - Best Selling
    """
    if request.args.get("sort") is None:
        SortType = 0
    else:
        try:
            SortType = int(request.args.get("sort"))
        except:
            SortType = 0
    if SortType > 4 or SortType < 0:
        SortType = 0
    SearchQuery = Asset.query
    CatalogTypesDict = {
        0: lambda queryObj: queryObj.filter(Asset.asset_type.in_((
            AssetType.Hat,
            AssetType.TShirt,
            AssetType.Shirt,
            AssetType.Pants,
            AssetType.Gear,
            AssetType.Face,
            AssetType.Head,
            AssetType.HairAccessory,
            AssetType.FaceAccessory,
            AssetType.NeckAccessory,
            AssetType.ShoulderAccessory,
            AssetType.FrontAccessory,
            AssetType.BackAccessory,
            AssetType.WaistAccessory,
            AssetType.Package
        ))).filter(and_(Asset.creator_id == 1, Asset.creator_type == 0)).filter(or_(
            Asset.is_for_sale == True, Asset.is_limited == True
        )),
        1: lambda queryObj: queryObj.filter(Asset.asset_type.in_((
            AssetType.Hat,
            AssetType.HairAccessory,
            AssetType.FaceAccessory,
            AssetType.NeckAccessory,
            AssetType.ShoulderAccessory,
            AssetType.FrontAccessory,
            AssetType.BackAccessory,
            AssetType.WaistAccessory,
        ))).filter(and_(Asset.creator_id == 1, Asset.creator_type == 0)).filter(or_(
            Asset.is_for_sale == True, Asset.is_limited == True
        )),
        2: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Gear).filter(and_(Asset.creator_id == 1, Asset.creator_type == 0, Asset.is_for_sale == True)),
        3: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Face).filter(and_(Asset.creator_id == 1, Asset.creator_type == 0, Asset.is_for_sale == True)),
        4: lambda queryObj: queryObj.filter_by(is_limited = True),
        5: lambda queryObj: queryObj.filter(Asset.asset_type.in_((
            AssetType.Hat,
            AssetType.HairAccessory,
            AssetType.FaceAccessory,
            AssetType.NeckAccessory,
            AssetType.ShoulderAccessory,
            AssetType.FrontAccessory,
            AssetType.BackAccessory,
            AssetType.WaistAccessory,
        ))).filter_by(is_limited = True),
        6: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Gear).filter_by(is_limited = True),
        7: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Face).filter_by(is_limited = True),
        8: lambda queryObj: queryObj.filter(Asset.asset_type.in_((
            AssetType.Hat,
            AssetType.TShirt,
            AssetType.Shirt,
            AssetType.Pants,
            AssetType.Package,
        ))).filter_by(is_for_sale = True),
        9: lambda queryObj: queryObj.filter(Asset.asset_type.in_((
            AssetType.Hat,
            AssetType.HairAccessory,
            AssetType.FaceAccessory,
            AssetType.NeckAccessory,
            AssetType.ShoulderAccessory,
            AssetType.FrontAccessory,
            AssetType.BackAccessory,
            AssetType.WaistAccessory,
        ))).filter_by(is_for_sale = True),
        10: lambda queryObj: queryObj.filter_by(asset_type = AssetType.Shirt).filter_by(is_for_sale = True),
        11: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.TShirt).filter_by(is_for_sale = True),
        12: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Pants).filter_by(is_for_sale = True),
        13: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Package).filter_by(is_for_sale = True),
        14: lambda queryObj: queryObj.filter(Asset.asset_type.in_((
            AssetType.Head,
            AssetType.Face,
            AssetType.Package
        ))).filter_by(is_for_sale = True),
        15: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Head).filter_by(is_for_sale = True),
        16: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.Face).filter_by(is_for_sale = True),
        41: lambda queryObj: queryObj.filter(Asset.asset_type == AssetType.HairAccessory).filter_by(is_for_sale = True),
    }
    if CatalogType > 41 or CatalogType < 0:
        CatalogType = 0
    SearchQuery = CatalogTypesDict[CatalogType](SearchQuery)
    if SearchInput != "" and len(SearchInput) > 3:        
        SearchQuery = SearchQuery.filter( Asset.name.ilike(f"%{SearchInput}%") )
    else:
        SearchInput = ""
    if SortType == 0:
        SearchQuery = SearchQuery.order_by(Asset.created_at.desc())
    elif SortType == 1:
        SearchQuery = SearchQuery.order_by(Asset.price_robux.asc())
    elif SortType == 2:
        SearchQuery = SearchQuery.order_by(Asset.price_robux.desc())
    elif SortType == 3:
        SearchQuery = SearchQuery.order_by(Asset.updated_at.desc())
    elif SortType == 4:
        SearchQuery = SearchQuery.order_by(Asset.sale_count.desc())
    else:
        SearchQuery = SearchQuery.order_by(Asset.created_at.desc())
    SearchQuery = SearchQuery.paginate(
        page=Page,
        per_page=24,
        error_out=False
    )
    for AssetObj in SearchQuery.items:
        if AssetObj.is_limited and not AssetObj.is_for_sale:
            BestPriceResult : UserAsset = UserAsset.query.filter_by(assetid=AssetObj.id, is_for_sale=True).order_by(UserAsset.price.asc()).first()
            if BestPriceResult is not None:
                AssetObj.best_price = str(BestPriceResult.price)
            else:
                AssetObj.best_price = "--"
    if Page == 1:
        PreviousPage = -1
    else:
        PreviousPage = Page -1
    if SearchQuery.has_next:
        NextPage = Page + 1
    else:
        NextPage = -1
    
    return render_template("catalog/index.html", 
                           categoryname=CatalogTypes[CatalogType]["name"], 
                           queryResults = SearchQuery.items, 
                           categoryid=CatalogType,
                            PreviousPage=PreviousPage,
                            NextPage=NextPage,
                            PageNumber=Page,
                            CatalogType=CatalogType,
                            SortType=SortType,
                            query=SearchInput,
                            totalPages = SearchQuery.pages,
                            totalResults = SearchQuery.total)

@CatalogRoute.route("/<int:assetid>/", methods=["GET"])
@CatalogRoute.route("/<int:assetid>/<assetname>", methods=["GET"])
@auth.authenticated_required
def asset_page(assetid, assetname=None):
    AssetObject : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObject is None:
        return redirect("/catalog")
    SlugName = slugify(AssetObject.name, lowercase=False)
    if SlugName is None or SlugName == "":
        SlugName = "unnamed"
    if assetname is None:
        if request.args.get("page") is None:
            return redirect(f"/catalog/{assetid}/{SlugName}")
        else:
            return redirect(f"/catalog/{assetid}/{SlugName}?page={request.args.get('page')}")
    if assetname != SlugName:
        if request.args.get("page") is None:
            return redirect(f"/catalog/{assetid}/{SlugName}")
        else:
            return redirect(f"/catalog/{assetid}/{SlugName}?page={request.args.get('page')}")
    if AssetObject.asset_type.value not in [2,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
        if AssetObject.asset_type.value == 9:
            return redirect(f"/games/{assetid}/")
        if AssetObject.asset_type.value in [1,3,4,5,10,13,24,34,38,40]:
            return redirect(f"/library/{assetid}/")
        return redirect("/catalog/")
    
    CreatorObj : User | Group = User.query.filter_by(id=AssetObject.creator_id).first() if AssetObject.creator_type == 0 else Group.query.filter_by(id=AssetObject.creator_id).first()
    Created = AssetObject.created_at.strftime("%d/%m/%Y")
    Updated = AssetObject.updated_at.strftime("%d/%m/%Y")
    AuthenticatedUser : User = auth.GetCurrentUser()
    doesUserOwnAsset = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid).first() is not None
    BestPriceResult : UserAsset = UserAsset.query.filter_by(assetid=assetid, is_for_sale=True).order_by(UserAsset.price.asc()).first()
    BestPrice = "None"
    if BestPriceResult is not None:
        BestPrice = str(BestPriceResult.price)
    UserOwns = 0
    PrivateSaleList = []
    NextPage = 0
    PreviousPage = 0
    PageNumber = 0
    AssetRap = 0
    if AssetObject.is_limited and not AssetObject.is_for_sale:
        AssetRap = GetAssetRap(assetid)
        UserOwns = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid).count()
        Page = 1
        if request.args.get("page"):
            try:
                Page = int(request.args.get("page"))
            except:
                pass
        PrivateSales = UserAsset.query.filter_by(assetid=assetid, is_for_sale=True).order_by(UserAsset.price.asc()).paginate(page=Page, per_page=5)
        for sale in PrivateSales.items:
            SellerUser : User = User.query.filter_by(id=sale.userid).first()
            PrivateSaleList.append({
                "price": sale.price,
                "seller": SellerUser.username,
                "sellerid": SellerUser.id,
                "serial": sale.serial,
                "uaid": sale.id
            })
        if PrivateSales.has_next:
            NextPage = Page + 1
        else:
            NextPage = -1
        if Page > 1:
            PreviousPage = Page - 1
        else:
            PreviousPage = -1
        PageNumber = Page
    OffsaleAt = None
    if AssetObject.offsale_at is not None:
        if datetime.utcnow() > AssetObject.offsale_at:
            AssetObject.is_for_sale = False
            AssetObject.offsale_at = None
            db.session.commit()
        else:
            OffsaleAt = int(calendar.timegm(AssetObject.offsale_at.timetuple()))
    return render_template("catalog/asset.html", asset=AssetObject, creator=CreatorObj, createddate=Created, 
                           updateddate=Updated, doesUserOwnAsset=doesUserOwnAsset, BestPrice=BestPrice, 
                           BestPriceResult=BestPriceResult, userOwnAmountCount=UserOwns, PrivateSales=PrivateSaleList,
                           NextPage=NextPage, PreviousPage=PreviousPage, PageNumber=PageNumber, AssetRap=AssetRap,
                           OffsaleAt=OffsaleAt)

@CatalogRoute.route("/resell/<int:assetid>", methods=["GET"])
@auth.authenticated_required
def resell_page(assetid):
    AssetObject : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObject is None:
        return redirect("/catalog")
    if not AssetObject.is_limited:
        return redirect(f"/catalog/{str(AssetObject.id)}/")
    if AssetObject.is_for_sale:
        return redirect(f"/catalog/{str(AssetObject.id)}/") # Users cant resell items when it is still for sale
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserOwns = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid).count()
    if UserOwns == 0:
        return redirect(f"/catalog/{str(AssetObject.id)}/")
    AllUserAssets = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid).all()
    UserAssetCurrentlyForSale = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid, is_for_sale=True).count()
    UserAssetNotForSale = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid, is_for_sale=False).count()
    return render_template("catalog/resell.html", asset=AssetObject, userassets=AllUserAssets, userassetforsalecount=UserAssetCurrentlyForSale, userassetnotforsalecount=UserAssetNotForSale, isOTPRequired = AuthenticatedUser.TOTPEnabled)

@CatalogRoute.route("/resell/<int:assetid>", methods=["POST"])
@auth.authenticated_required
@user_limiter.limit("1/second")
def resell_page_post(assetid):
    AssetObject : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObject is None:
        return redirect("/catalog")
    if not AssetObject.is_limited:
        return redirect(f"/catalog/{str(AssetObject.id)}/")
    if AssetObject.is_for_sale:
        return redirect(f"/catalog/{str(AssetObject.id)}/")
    AuthenticatedUser : User = auth.GetCurrentUser()
    if "uaid" not in request.form or "itemprice" not in request.form:
        flash("Invalid request", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    try:
        ItemPrice = int(request.form["itemprice"])
        UAID = int(request.form["uaid"])
    except:
        flash("Invalid request", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    UserAssetObj : UserAsset = UserAsset.query.filter_by(id=UAID).first()
    if UserAssetObj is None:
        flash("Invalid request", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    if UserAssetObj.userid != AuthenticatedUser.id:
        flash("Invalid request", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    if UserAssetObj.assetid != AssetObject.id:
        flash("Invalid request", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")

    if not websiteFeatures.GetWebsiteFeature("ItemReselling"):
        flash("Item reselling is currently disabled", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")

    if AuthenticatedUser.TOTPEnabled:
        if "2fa-code" not in request.form:
            flash("Invalid request", "error")
            return redirect(f"/catalog/resell/{str(AssetObject.id)}")
        TOTPCode = request.form["2fa-code"]
        if len(TOTPCode) != 6:
            flash("Invalid 2FA code", "error")
            return redirect(f"/catalog/resell/{str(AssetObject.id)}")
        if not auth.Validate2FACode(AuthenticatedUser.id, TOTPCode):
            flash("Invalid 2FA code", "error")
            return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    if ItemPrice < 1 or ItemPrice > 999999999:
        flash("Invalid price ( 1 - 999999999 )", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    if UserAssetObj.is_for_sale:
        flash("This asset is already for sale", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser)
    if UserCurrentMembership == MembershipType.NonBuildersClub:
        flash("You must be a Builders Club member to sell items", "error")
        return redirect(f"/catalog/resell/{str(AssetObject.id)}")
    UserAssetObj.is_for_sale = True
    UserAssetObj.price = ItemPrice
    db.session.commit()
    return redirect(f"/catalog/resell/{str(AssetObject.id)}")

@CatalogRoute.route("/resell/<int:uaid>/takeoff", methods=["POST"])
@auth.authenticated_required
@csrf.exempt
def resell_takeoff(uaid):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserAssetObject : UserAsset = UserAsset.query.filter_by(id=uaid).first()
    if UserAssetObject is None:
        flash("Invalid asset", "error")
        return redirect("/catalog")
    if UserAssetObject.userid != AuthenticatedUser.id:
        flash("Invalid asset", "error")
        return redirect("/catalog")
    if not UserAssetObject.is_for_sale:
        flash("This asset is not for sale", "error")
        return redirect(f"/catalog/resell/{str(UserAssetObject.assetid)}")
    UserAssetObject.is_for_sale = False
    UserAssetObject.price = 0
    db.session.commit()
    return redirect(f"/catalog/resell/{str(UserAssetObject.assetid)}")

@CatalogRoute.route("/api/purchase", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("1/second")
@user_limiter.limit("1/second")
def api_purchase():
    JSONData = request.json
    if "assetId" not in JSONData or "expectedPrice" not in JSONData or "currencyType" not in JSONData:
        return jsonify({"success": False, "message": "Invalid request"}),400

    if not websiteFeatures.GetWebsiteFeature("EconomyPurchase"):
        return jsonify({"success": False, "message": "Purchasing is temporarily disabled"}),400

    try:
        JSONData["assetId"] = int(JSONData["assetId"])
        JSONData["expectedPrice"] = int(JSONData["expectedPrice"])
        JSONData["currencyType"] = int(JSONData["currencyType"])
    except:
        return jsonify({"success": False, "message": "Invalid request"}),400

    AssetObject : Asset = Asset.query.filter_by(id=JSONData["assetId"]).first()
    if AssetObject is None:
        return jsonify({"success": False, "message": "Invalid asset"}),400

    AuthenticatedUser : User = auth.GetCurrentUser()
    
    try:
        with redis_lock.Lock(redis_client = redis_controller, name=f"asset:{str(AssetObject.id)}", expire=15, auto_renewal=True, strict=True) as lock:
            if AssetObject.offsale_at is not None:
                if datetime.utcnow() > AssetObject.offsale_at:
                    AssetObject.is_for_sale = False
                    AssetObject.offsale_at = None
                    db.session.commit()
            if AssetObject.is_for_sale == False:
                return jsonify({"success": False, "message": "Asset is not for sale"}),400
            if JSONData["currencyType"] == 0:
                if JSONData["expectedPrice"] != AssetObject.price_robux:
                    return jsonify({"success": False, "message": "Expected Price is different from current price"}),400
            elif JSONData["currencyType"] == 1:
                if JSONData["expectedPrice"] != AssetObject.price_tix:
                    return jsonify({"success": False, "message": "Expected Price is different from current price"}),400
            else:
                return jsonify({"success": False, "message": "Invalid currency type"}),400

            if AssetObject.price_robux == 0 and AssetObject.price_tix != 0 and JSONData["currencyType"] == 0:
                return jsonify({"success": False, "message": "Asset is not being sold in this currency"}),400
            if AssetObject.price_tix == 0 and AssetObject.price_robux != 0 and JSONData["currencyType"] == 1:
                return jsonify({"success": False, "message": "Asset is not being sold in this currency"}),400
            
            UserAssetObj : UserAsset = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=AssetObject.id).first()
            if UserAssetObj is not None:
                return jsonify({"success": False, "message": "User already owns asset"}),400
            PurchaserRobuxBal, PurchaserTicketsBal = GetUserBalance(AuthenticatedUser)
            if JSONData["currencyType"] == 0:
                if PurchaserRobuxBal < AssetObject.price_robux:
                    return jsonify({"success": False, "message": "Insufficient funds"}),400
                try:
                    DecrementTargetBalance(
                        Target = AuthenticatedUser,
                        Amount = AssetObject.price_robux,
                        CurrencyType = 0
                    )
                except InsufficientFundsException:
                    return jsonify({"success": False, "message": "Insufficient funds"}),400
                except EconomyLockAcquireException:
                    return jsonify({"success": False, "message": "Failed to acquire lock"}),400
                except Exception as e:
                    logging.error(f"/api/purchase : Failed to decrement balance for user {str(AuthenticatedUser.id)}, message: {str(e)}")
                    return jsonify({"success": False, "message": "Failed to decrement balance"}),400
                
                IncrementAssetCreator(
                    AssetObject = AssetObject,
                    AmountGiven = AssetObject.price_robux,
                    CurrencyType = 0
                )
            elif JSONData["currencyType"] == 1:
                if PurchaserTicketsBal < AssetObject.price_tix:
                    return jsonify({"success": False, "message": "Insufficient funds"}),400
                
                try:
                    DecrementTargetBalance(
                        Target = AuthenticatedUser,
                        Amount = AssetObject.price_tix,
                        CurrencyType = 1
                    )
                except InsufficientFundsException:
                    return jsonify({"success": False, "message": "Insufficient funds"}),400
                except EconomyLockAcquireException:
                    return jsonify({"success": False, "message": "Failed to acquire lock"}),400
                except Exception as e:
                    logging.error(f"/api/purchase : Failed to decrement balance for user {str(AuthenticatedUser.id)}, message: {str(e)}")
                    return jsonify({"success": False, "message": "Failed to decrement balance"}),400
                
                IncrementAssetCreator(
                    AssetObject = AssetObject,
                    AmountGiven = AssetObject.price_tix,
                    CurrencyType = 1
                )
            else:
                return jsonify({"success": False, "message": "Invalid currency type"}),400
            
            if AssetObject.is_limited_unique:
                ItemSerial = AssetObject.sale_count + 1
                if AssetObject.sale_count + 1 >= AssetObject.serial_count:
                    AssetObject.is_for_sale = False
            if AssetObject.is_limited_unique:
                UserAssetObj = UserAsset(userid=AuthenticatedUser.id, assetid=AssetObject.id, serial=ItemSerial)
            else:
                UserAssetObj = UserAsset(userid=AuthenticatedUser.id, assetid=AssetObject.id)

            if AssetObject.asset_type == AssetType.Package:
                PackageAssets = PackageAsset.query.filter_by(package_asset_id=AssetObject.id).all()
                for PackageAssetObj in PackageAssets:
                    NewPackageAssetObj = UserAsset(userid=AuthenticatedUser.id, assetid=PackageAssetObj.asset_id)
                    db.session.add(NewPackageAssetObj)

            AssetObject.sale_count += 1
            db.session.add(UserAssetObj)
            db.session.commit()

            try:
                if AssetObject.creator_type == 0:
                    SellerUserObj : User = User.query.filter_by(id=AssetObject.creator_id).first()
                    CreateTransactionForSale(
                        AssetObj = AssetObject,
                        PurchasePrice = JSONData["expectedPrice"],
                        PurchaseCurrencyType = JSONData["currencyType"],
                        Seller = SellerUserObj,
                        Buyer = AuthenticatedUser,
                        ApplyTaxAutomatically = True
                    )
                else:
                    GroupObj : Group = Group.query.filter_by(id=AssetObject.creator_id).first()
                    CreateTransactionForSale(
                        AssetObj = AssetObject,
                        PurchasePrice = JSONData["expectedPrice"],
                        PurchaseCurrencyType = JSONData["currencyType"],
                        Seller = GroupObj,
                        Buyer = AuthenticatedUser,
                        ApplyTaxAutomatically = True
                    )
            except Exception as e:
                logging.warn(f"Failed to create transaction log for sale of asset {str(AssetObject.id)}, message: {str(e)}")
                pass

            return jsonify({"success": True, "message": "Asset purchased successfully"}),200
    except AssertionError as e:
        return jsonify({"success": False, "message": "Failed to acquire lock"}),400

@CatalogRoute.route("/api/purchase-limited", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("1/second")
@user_limiter.limit("1/second")
def api_purchase_limited():
    JSONData = request.json
    if "assetId" not in JSONData or "expectedPrice" not in JSONData or "expectedOwner" not in JSONData or "itemOwnershipId" not in JSONData:
        return jsonify({"success": False, "message": "Invalid request"}),400
    # Expected Types: assetId (int), expectedPrice (int), expectedOwner (int), itemOwnershipId (int)
    if type(JSONData["assetId"]) != int or type(JSONData["expectedPrice"]) != int or type(JSONData["expectedOwner"]) != int or type(JSONData["itemOwnershipId"]) != int:
        return jsonify({"success": False, "message": "Invalid request"}),400
    AuthenticatedUser : User = auth.GetAuthenticatedUser(request.cookies.get(".ROBLOSECURITY"))
    EconomyLock = acquire_lock(f"economy:{str(AuthenticatedUser.id)}", acquire_timeout=5, lock_timeout=1)
    if EconomyLock is False:
        return jsonify({"success": False, "message": "Failed to acquire lock"}),400
    AssetObject : Asset = Asset.query.filter_by(id=JSONData["assetId"]).first()
    if AssetObject is None:
        release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
        return jsonify({"success": False, "message": "Invalid asset"}),400
    if AssetObject.is_limited == False:
        release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
        return jsonify({"success": False, "message": "Asset is not limited"}),400
    LimitedAsset : UserAsset = UserAsset.query.filter_by(assetid=AssetObject.id, id=JSONData["itemOwnershipId"]).first()
    if LimitedAsset is None:
        release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
        return jsonify({"success": False, "message": "Invalid asset info"}),400
    ItemLock = acquire_lock(f"item:{str(LimitedAsset.id)}", acquire_timeout=5, lock_timeout=1)
    if ItemLock is False:
        return jsonify({"success": False, "message": "Failed to acquire lock ( This is usually caused by too many people purchasing this item at the same time. )"}),400
    if LimitedAsset.is_for_sale == False:
        release_lock(f"item:{str(LimitedAsset.id)}", ItemLock)
        release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
        return jsonify({"success": False, "message": "Item is not for sale"}),400
    if JSONData["expectedOwner"] != LimitedAsset.userid:
        release_lock(f"item:{str(LimitedAsset.id)}", ItemLock)
        release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
        return jsonify({"success": False, "message": f"Expected Owner ({str(JSONData['expectedOwner'])}) does not match current item owner({str(LimitedAsset.userid)})"}),400
    if JSONData["expectedPrice"] != LimitedAsset.price:
        release_lock(f"item:{str(LimitedAsset.id)}", ItemLock)
        release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
        return jsonify({"success": False, "message": f"Expected Price ({str(JSONData['expectedPrice'])}) does not match current item price ({str(LimitedAsset.price)})"}),400
    if AuthenticatedUser.id == LimitedAsset.userid:
        release_lock(f"item:{str(LimitedAsset.id)}", ItemLock)
        release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
        return jsonify({"success": False, "message": "You cannot purchase your own item"}),400
    
    UserEconomyObj : UserEconomy = UserEconomy.query.filter_by(userid=AuthenticatedUser.id).first()
    if UserEconomyObj.robux < LimitedAsset.price:
        redis_controller.delete(f"economy:{str(AuthenticatedUser.id)}")
        return jsonify({"success": False, "message": "Insufficient funds"}),400
    
    UserEconomyObj.robux -= LimitedAsset.price
    OriginalPrice : int = LimitedAsset.price
    db.session.commit()
    IncrementTargetBalance(GetUserFromId(LimitedAsset.userid), TaxCurrencyAmount(LimitedAsset.price), 0)
    AdjustAssetRap(LimitedAsset.assetid, LimitedAsset.price)
    LimitedAsset.userid = AuthenticatedUser.id
    LimitedAsset.is_for_sale = False
    LimitedAsset.price = 0
    LimitedAsset.updated = datetime.utcnow()
    db.session.commit()
    # We release the locks first as taking a thumbnail can take a while
    release_lock(f"economy:{str(AuthenticatedUser.id)}", EconomyLock)
    release_lock(f"item:{str(LimitedAsset.id)}", ItemLock)
    PreviousOwnerId : int = JSONData["expectedOwner"]
    # Check how many items the previous owner had of the same asset
    PreviousOwnerItems = UserAsset.query.filter_by(userid=PreviousOwnerId, assetid=AssetObject.id).count()
    if PreviousOwnerItems == 0:
        # Remove the asset from the previous owner avatar if there is any
        AvatarAsset = UserAvatarAsset.query.filter_by(user_id=PreviousOwnerId, asset_id=AssetObject.id).first()
        if AvatarAsset is not None:
            db.session.delete(AvatarAsset)
            db.session.commit()
            TakeUserThumbnail(PreviousOwnerId, True, False)
    CreateSystemMessage(
        f"Your {AssetObject.name} has been sold!",
        f"Your item {AssetObject.name} ( UAID: {str(LimitedAsset.id)} / Serial: {str(LimitedAsset.serial)} ) has been sold for R$ {str(OriginalPrice)} to {AuthenticatedUser.username} ( {str(AuthenticatedUser.id)} ).",
        PreviousOwnerId
    )
    SellerUserObj : User = User.query.filter_by(id=PreviousOwnerId).first()
    
    try:
        CreateTransactionForSale(
            AssetObj = AssetObject,
            PurchasePrice = OriginalPrice,
            PurchaseCurrencyType = 0,
            Seller = SellerUserObj,
            Buyer = AuthenticatedUser,
            ApplyTaxAutomatically = True
        )
    except Exception as e:
        logging.warn(f"Failed to create transaction log for sale of asset {str(AssetObject.id)}, message: {str(e)}")
        pass

    try:
        newLimitedTransfer = LimitedItemTransfer(
            original_owner_id = SellerUserObj.id,
            new_owner_id = AuthenticatedUser.id,
            asset_id = AssetObject.id,
            user_asset_id = LimitedAsset.id,
            transfer_method = LimitedItemTransferMethod.Purchase,
            purchased_price = OriginalPrice
        )
        db.session.add(newLimitedTransfer)
        db.session.commit()
    except Exception as e:
        logging.warn(f"Failed to create limited item transfer log for asset {str(AssetObject.id)}, message: {str(e)}")
        pass

    return jsonify({"success": True, "message": "Item purchased successfully"}),200


@LibraryRoute.route("/<int:assetid>/", methods=["GET"])
@LibraryRoute.route("/<int:assetid>/<assetname>", methods=["GET"])
@auth.authenticated_required
def asset_page(assetid, assetname=None):
    AssetObject : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObject is None:
        return redirect("/library")
    SlugName = slugify(AssetObject.name, lowercase=False)
    if SlugName is None or SlugName == "":
        SlugName = "unnamed"
    if assetname is None:
        if request.args.get("page") is None:
            return redirect(f"/library/{assetid}/{SlugName}")
        else:
            return redirect(f"/library/{assetid}/{SlugName}?page={request.args.get('page')}")
    if assetname != SlugName:
        if request.args.get("page") is None:
            return redirect(f"/library/{assetid}/{SlugName}")
        else:
            return redirect(f"/library/{assetid}/{SlugName}?page={request.args.get('page')}")
    if AssetObject.asset_type.value in [2,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
        return redirect(f"/catalog/{str(AssetObject.id)}/")
    if AssetObject.asset_type.value == 9:
         return redirect(f"/games/{assetid}/")
    CreatorObj : User | Group = User.query.filter_by(id=AssetObject.creator_id).first() if AssetObject.creator_type == 0 else Group.query.filter_by(id=AssetObject.creator_id).first()
    Created = AssetObject.created_at.strftime("%d/%m/%Y")
    Updated = AssetObject.updated_at.strftime("%d/%m/%Y")
    AuthenticatedUser : User = auth.GetCurrentUser()
    doesUserOwnAsset = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid).first() is not None
    BestPriceResult : UserAsset = UserAsset.query.filter_by(assetid=assetid, is_for_sale=True).order_by(UserAsset.price.asc()).first()
    BestPrice = "None"
    if BestPriceResult is not None:
        BestPrice = str(BestPriceResult.price)
    UserOwns = 0
    PrivateSaleList = []
    NextPage = 0
    PreviousPage = 0
    PageNumber = 0
    AssetRap = 0
    if AssetObject.is_limited and not AssetObject.is_for_sale:
        AssetRap = GetAssetRap(assetid)
        UserOwns = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=assetid).count()
        Page = 1
        if request.args.get("page"):
            try:
                Page = int(request.args.get("page"))
            except:
                pass
        PrivateSales = UserAsset.query.filter_by(assetid=assetid, is_for_sale=True).order_by(UserAsset.price.asc()).paginate(page=Page, per_page=5).items
        for sale in PrivateSales:
            SellerUser : User = User.query.filter_by(id=sale.userid).first()
            PrivateSaleList.append({
                "price": sale.price,
                "seller": SellerUser.username,
                "sellerid": SellerUser.id,
                "serial": sale.serial,
                "uaid": sale.id
            })
        if len(UserAsset.query.filter_by(assetid=assetid, is_for_sale=True).order_by(UserAsset.price.asc()).paginate(page=Page+1, per_page=5, error_out=False).items) > 0:
            NextPage = Page + 1
        else:
            NextPage = -1
        if Page > 1:
            PreviousPage = Page - 1
        else:
            PreviousPage = -1
        PageNumber = Page
    
    GamepassLinkObj = None
    GamepassRootPlaceAsset = None
    if AssetObject.asset_type == AssetType.GamePass:
        GamepassLinkObj : GamepassLink = GamepassLink.query.filter_by(gamepass_id=AssetObject.id).first()
        GamepassUniverse : Universe = Universe.query.filter_by(id=GamepassLinkObj.universe_id).first()
        GamepassRootPlaceAsset : Asset = Asset.query.filter_by( id = GamepassUniverse.root_place_id ).first()
    return render_template("catalog/library.html", asset=AssetObject, creator=CreatorObj, createddate=Created, 
                           updateddate=Updated, doesUserOwnAsset=doesUserOwnAsset, BestPrice=BestPrice, 
                           BestPriceResult=BestPriceResult, userOwnAmountCount=UserOwns, PrivateSales=PrivateSaleList,
                           NextPage=NextPage, PreviousPage=PreviousPage, PageNumber=PageNumber, AssetRap=AssetRap,
                           GamepassLinkObj=GamepassLinkObj, GamepassRootPlaceAsset=GamepassRootPlaceAsset)

@BadgesPageRoute.route("/<int:badgeid>/", methods=["GET"])
@BadgesPageRoute.route("/<int:badgeid>/<badgename>", methods=["GET"])
@auth.authenticated_required
def badge_page( badgeid : int, badgename : str = None ):
    BadgeObject : PlaceBadge = PlaceBadge.query.filter_by(id=badgeid).first()
    if BadgeObject is None:
        return abort(404)
    
    if badgename is None:
        return redirect(f"/badges/{badgeid}/{slugify(BadgeObject.name, lowercase=False)}")
    elif badgename != slugify(BadgeObject.name, lowercase=False):
        return redirect(f"/badges/{badgeid}/{slugify(BadgeObject.name, lowercase=False)}")
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserBadgeObj : UserBadge = UserBadge.query.filter_by(user_id=AuthenticatedUser.id, badge_id=badgeid).first()
    AssociatedPlaceAssetObj : Asset = Asset.query.filter_by(id=BadgeObject.associated_place_id).first()
    CreatorObj : User | Group = User.query.filter_by(id=AssociatedPlaceAssetObj.creator_id).first() if AssociatedPlaceAssetObj.creator_type == 0 else Group.query.filter_by(id=AssociatedPlaceAssetObj.creator_id).first()
    Created = BadgeObject.created_at.strftime("%d/%m/%Y")
    Updated = BadgeObject.updated_at.strftime("%d/%m/%Y")

    return render_template(
        "catalog/badges.html", 
        badge = BadgeObject, 
        userbadge = UserBadgeObj, 
        AssociatedPlaceAssetObj = AssociatedPlaceAssetObj, 
        creator = CreatorObj,
        createddate = Created,
        updateddate = Updated
    )
