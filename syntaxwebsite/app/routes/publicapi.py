import time
import math
import calendar
from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, abort, flash
from sqlalchemy import func
from app.extensions import limiter, csrf, db, user_limiter
from app.models.user import User
from app.models.asset import Asset
from app.models.userassets import UserAsset
from app.models.user_trades import UserTrade
from app.models.user_trade_items import UserTradeItem
from app.models.groups import Group
from app.models.linked_discord import LinkedDiscord
from app.models.placeserver_players import PlaceServerPlayer
from app.models.limited_item_transfers import LimitedItemTransfer
from app.util import auth, redislock
from app.enums.AssetType import AssetType
from app.enums.MembershipType import MembershipType
from app.enums.TradeStatus import TradeStatus
from app.enums.LimitedItemTransferMethod import LimitedItemTransferMethod
from app.util.membership import GetUserMembership
from app.services.economy import GetAssetRap, GetUserBalance, DecrementTargetBalance, IncrementTargetBalance, CalculateUserRAP
from app.services.groups import GetGroupFromId
from app.pages.trades.trades import createTradePost
from datetime import datetime, timedelta
from sqlalchemy import or_, and_
from app.models.user_ban import UserBan

PublicAPIRoute = Blueprint("publicapi", __name__, url_prefix="/public-api")

def ReturnError( message : str, code : int = 403 ):
    return jsonify({
        "success": False,
        "message": message,
        "data": None
    }), code

def GetUserFromId( UserObj : User | int ) -> User | None:
    """
    Returns a User object from a User ID.
    """
    if isinstance(UserObj, User):
        return UserObj
    else:
        TargetUser : User | None = User.query.filter_by(id=UserObj).first()
        if TargetUser is None:
            raise Exception("User does not exist.")
        return TargetUser

def ReturnUserObject( UserObj : User ) -> dict:
    return {
        "id": UserObj.id,
        "username": UserObj.username,
        "last_online": int(calendar.timegm(UserObj.lastonline.timetuple())),
        "created_at": int(calendar.timegm(UserObj.created.timetuple())),
        "description": UserObj.description,
        "membership": GetUserMembership(UserObj, changeToString=True),
        "is_banned": UserObj.accountstatus != 1,
        "inventory_rap": CalculateUserRAP(UserObj)
    }

def ReturnGroupObject( GroupObj : Group ) -> dict:
    return {
        "id": GroupObj.id,
        "name": GroupObj.name,
        "created_at": int(calendar.timegm(GroupObj.created_at.timetuple())),
        "user_owner_id": GroupObj.owner_id
    }

def ReturnItemObject( AssetObj : Asset, ListCreator : bool = True, includeLimitedInfo : bool = True) -> dict:
    Item = {
        "id": AssetObj.id,
        "name": AssetObj.name,
        "description": AssetObj.description,
        "asset_type": AssetObj.asset_type.name,
        "asset_type_value": AssetObj.asset_type.value,
        "creator_id": AssetObj.creator_id,
        "creator_type": AssetObj.creator_type,
        "created_at": int(calendar.timegm(AssetObj.created_at.timetuple())),
        "updated_at": int(calendar.timegm(AssetObj.updated_at.timetuple())),
        "is_for_sale": AssetObj.is_for_sale,
        "price_robux": AssetObj.price_robux,
        "price_tickets": AssetObj.price_tix,
        "sales": AssetObj.sale_count
    }
    if includeLimitedInfo:
        Item["is_limited"] = AssetObj.is_limited
        Item["is_limited_unique"] = AssetObj.is_limited_unique
        Item["asset_rap"] = GetAssetRap(AssetObj.id) if AssetObj.is_limited and not AssetObj.is_for_sale else None
    if ListCreator:
        Item["creator"] = ReturnUserObject(GetUserFromId(AssetObj.creator_id)) if AssetObj.creator_type == 0 else ReturnGroupObject(GetGroupFromId(AssetObj.creator_id))
    return Item

@PublicAPIRoute.errorhandler(429)
def ratelimit_handler(e):
    return ReturnError("You are being ratelimited, please try again later.", 429)

@PublicAPIRoute.errorhandler(500)
def internalerror_handler(e):
    return ReturnError("An internal error occured, please try again later.", 500)

@PublicAPIRoute.route("/", methods=["GET"])
def PublicAPIDocs():
    return render_template("swaggerdocs.html")

@PublicAPIRoute.route("/v1/users/<int:userid>", methods=["GET"])
@limiter.limit("20/minute")
def LookupUserId(userid : int):
    UserObj : User = User.query.filter_by(id=userid).first()
    if UserObj is None:
        return ReturnError("User not found", 404)
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnUserObject(UserObj)
    }), 200

@PublicAPIRoute.route("/v1/users/username/<string:username>", methods=["GET"])
@limiter.limit("20/minute")
def LookupUsername(username : str):
    UserObj : User = User.query.filter(func.lower(User.username) == func.lower(username)).first()
    if UserObj is None:
        return ReturnError("User not found", 404)
    if UserObj.accountstatus == 4: # GDPR
        return ReturnError("User not found", 404)
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnUserObject(UserObj)
    }), 200

@PublicAPIRoute.route("/sitestats", methods=["GET"])
@limiter.limit("30/minute")
def SiteStatsHTTP():
    UsersOnline = User.query.filter(User.lastonline > (datetime.utcnow() - timedelta(minutes=1))).count()
    UsersIngame = PlaceServerPlayer.query.count()
    BannedByAnticheat = UserBan.query.filter_by(reason="Exploiting in games is not tolerated on SYNTAX").count() # meme
    UsersSignedUpToday = User.query.filter(User.created > (datetime.utcnow() - timedelta(days=1))).count()
    UsersSignedUpYesterday = User.query.filter(and_( User.created > ( datetime.utcnow() - timedelta(days=2) ), User.created < ( datetime.utcnow() - timedelta(days=1) ) )).count() # i actually forgot why this is needed, but its probably needed to do some cool shit idk
    TotalUsers = User.query.count()
    return jsonify({
        "success": True,
        "message": "",
        "data": {
            "users_online": UsersOnline,
            "users_ingame": UsersIngame,
            "signed_up_today": UsersSignedUpToday,
            "signed_up_yesterday": UsersSignedUpYesterday,
            "total_users": TotalUsers,
            "banned_by_ac": BannedByAnticheat
        }
    }), 200

@PublicAPIRoute.route("/v1/users/discord_id/<int:discordid>", methods=["GET"])
@limiter.limit("20/minute")
def LookupUserByDiscordId(discordid : int):
    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by( discord_id = discordid ).first()
    if LinkedDiscordObj is None:
        return ReturnError("No SYNTAX account is associated with this Discord ID", 404)
    UserObj : User = User.query.filter_by( id = LinkedDiscordObj.user_id ).first()
    if UserObj.accountstatus == 4:
        return ReturnError("No SYNTAX account is associated with this Discord ID", 404)
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnUserObject(UserObj)
    }), 200

@PublicAPIRoute.route("/v1/asset/<int:assetid>", methods=["GET"])
@limiter.limit("20/minute")
def LookupItemId(assetid : int):
    ItemObj : Asset = Asset.query.filter_by(id=assetid).first()
    if ItemObj is None:
        return ReturnError("Asset not found", 404)
    if ItemObj.creator_type == 0 and ItemObj.creator_id == 1 and ( datetime.utcnow() < ( ItemObj.created_at + timedelta(minutes=10) ) ):
        return ReturnError("Asset created recently, please wait...", 403)
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnItemObject(ItemObj, includeLimitedInfo=False)
    }), 200

@PublicAPIRoute.route("/v1/inventory/collectibles/<int:userid>", methods=["GET"])
@limiter.limit("20/minute")
def LookupUserInventoryCollectibles(userid : int):
    UserObj : User = User.query.filter_by(id=userid).first()
    if UserObj is None:
        return ReturnError("User not found", 404)
    PageNumber = request.args.get("page", default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1
    UserAssets : list[UserAsset] = UserAsset.query.filter_by(userid=userid).join(Asset).filter_by(is_limited=True).paginate( page = PageNumber, per_page = 12, error_out = False )
    FormattedUserAsset = []

    for UserAssetObj in UserAssets.items:
        FormattedUserAsset.append({
            "uaid": UserAssetObj.id,
            "serial": UserAssetObj.serial,
            "price": UserAssetObj.price,
            "asset": ReturnItemObject(UserAssetObj.asset, ListCreator=False)
        })
    
    return jsonify({
        "success": True,
        "message": "",
        "data": FormattedUserAsset,
        "page": PageNumber,
        "total_pages": UserAssets.pages,
        "next_page": UserAssets.next_num if UserAssets.has_next else None
    })

@PublicAPIRoute.route("/v1/inventory/assets/<int:userid>/<int:assettypeid>", methods=["GET"])
@limiter.limit("20/minute")
def LookupUserInventory( userid : int, assettypeid : int ):
    UserObj : User = User.query.filter_by(id=userid).first()
    if UserObj is None:
        return ReturnError("User not found", 404)
    
    PageNumber = request.args.get("page", default=1, type=int)
    try:
        AssetTypeObj : AssetType = AssetType(assettypeid)
    except ValueError:
        ReturnError("Invalid asset type, please refer to documentation https://create.roblox.com/docs/reference/engine/enums/AssetType", 400)
    if PageNumber < 1:
        PageNumber = 1
    UserAssets : list[UserAsset] = UserAsset.query.filter_by(userid=userid).join(Asset).filter_by(asset_type=AssetTypeObj).order_by(UserAsset.id.desc()).paginate( page = PageNumber, per_page = 12, error_out = False )
    FormattedUserAsset = []
    for UserAssetObj in UserAssets.items:
        FormattedUserAsset.append({
            "uaid": UserAssetObj.id,
            "serial": UserAssetObj.serial,
            "price": UserAssetObj.price,
            "asset": ReturnItemObject(UserAssetObj.asset, ListCreator=False)
        })

    return jsonify({
        "success": True,
        "message": "",
        "data": FormattedUserAsset,
        "page": PageNumber,
        "total_pages": UserAssets.pages,
        "next_page": UserAssets.next_num if UserAssets.has_next else None
    })

@PublicAPIRoute.route("/v1/economy/my-balance", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def GetMyBalance():
    AuthenticatedUser : User = auth.GetCurrentUser()
    RobuxBal, TicketsBal = GetUserBalance(AuthenticatedUser)
    return jsonify({
        "success": True,
        "message": "",
        "data": {
            "robux": RobuxBal,
            "tickets": TicketsBal
        }
    })

@PublicAPIRoute.route("/v1/users/my-profile", methods=["GET"])
@auth.authenticated_required_api
def GetMyProfile():
    AuthenticatedUser : User = auth.GetCurrentUser()
    return jsonify({
        "success": True,
        "message": "",
        "data": ReturnUserObject(AuthenticatedUser)
    })

@PublicAPIRoute.route("/v1/trade/list", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def GetMyTrades():
    AuthenticatedUser : User = auth.GetCurrentUser()
    PageNumber = request.args.get("page", default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1
    UserTradesList : list[UserTrade] = UserTrade.query.filter(or_(UserTrade.sender_userid == AuthenticatedUser.id, UserTrade.recipient_userid == AuthenticatedUser.id)).order_by(UserTrade.id.desc()).paginate( page = PageNumber, per_page = 12, error_out = False )
    FormattedUserTrades = []
    for tradeObj in UserTradesList:
        tradeObj : UserTrade = tradeObj # type hinting
        FormattedUserTrades.append({
            "id": tradeObj.id,
            "sender_userid": tradeObj.sender_userid,
            "recipient_userid": tradeObj.recipient_userid,
            "created_at": int(calendar.timegm(tradeObj.created_at.timetuple())),
            "expires_at": int(calendar.timegm(tradeObj.expires_at.timetuple())),
            "status": tradeObj.status.name
        })

    return jsonify({
        "success": True,
        "message": "",
        "data": FormattedUserTrades,
        "page": PageNumber,
        "total_pages": UserTradesList.pages,
        "next_page": UserTradesList.next_num if UserTradesList.has_next else None
    })

@PublicAPIRoute.route("/v1/trade/<int:tradeid>", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def GetTradeInfo(tradeid : int):
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return ReturnError("Trade not found", 404)
    if TradeObj.sender_userid != AuthenticatedUser.id and TradeObj.recipient_userid != AuthenticatedUser.id:
        return ReturnError("You are not the sender or recipient of this trade")
    
    TradeItems : list[UserTradeItem] = UserTradeItem.query.filter_by(tradeid=TradeObj.id).all()
    SenderItems = []
    RecipientItems = []

    for TradeItem in TradeItems:
        TradeItem : UserTradeItem = TradeItem
        if TradeItem.userid == TradeObj.sender_userid:
            SenderItems.append({
                "uaid": TradeItem.userasset.id,
                "serial": TradeItem.userasset.serial,
                "price": TradeItem.userasset.price,
                "asset": ReturnItemObject(TradeItem.userasset.asset, ListCreator=False)
            })
        else:
            RecipientItems.append({
                "uaid": TradeItem.userasset.id,
                "serial": TradeItem.userasset.serial,
                "price": TradeItem.userasset.price,
                "asset": ReturnItemObject(TradeItem.userasset.asset, ListCreator=False)
            })

    return jsonify({
        "success": True,
        "message": "",
        "data": {
            "id": TradeObj.id,
            "sender_userid": TradeObj.sender_userid,
            "recipient_userid": TradeObj.recipient_userid,
            "created_at": int(calendar.timegm(TradeObj.created_at.timetuple())),
            "expires_at": int(calendar.timegm(TradeObj.expires_at.timetuple())),
            "status": TradeObj.status.name,
            "sender_items": SenderItems,
            "recipient_items": RecipientItems,
            "sender_robux": TradeObj.sender_userid_robux,
            "recipient_robux": TradeObj.recipient_userid_robux
        }
    })

@PublicAPIRoute.route("/v1/trade/create/<int:recipient_userid>", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("5/minute")
@user_limiter.limit("5/minute")
@csrf.exempt
def createTradeProxy( recipient_userid : int ):
    return createTradePost(recipient_userid)

@PublicAPIRoute.route("/v1/trade/accept/<int:tradeid>", methods=["POST"])
@auth.authenticated_required_api
@csrf.exempt
def acceptTrade( tradeid : int ):

    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return ReturnError("Trade not found", 404)
    if TradeObj.recipient_userid != AuthenticatedUser.id:
        return ReturnError("You are not the recipient of this trade")
    if TradeObj.status != TradeStatus.Pending:
        return ReturnError("Trade is not pending")
    if TradeObj.expires_at < datetime.utcnow():
        TradeObj.status = TradeStatus.Expired
        TradeObj.updated_at = datetime.utcnow()
        db.session.commit()
        return ReturnError("Trade has expired")
    
    if AuthenticatedUser.TOTPEnabled:
        JSONPayload = request.json
        if JSONPayload is None:
            return ReturnError("Expected JSON payload", 400)
        if "TOTPCode" not in JSONPayload:
            return ReturnError("Missing parameter 'TOTPCode' in JSON payload", 400)
        if not auth.Validate2FACode(AuthenticatedUser.id, JSONPayload["TOTPCode"]):
            return ReturnError("Invalid 2FA code")
    
    UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser.id)
    if UserCurrentMembership == MembershipType.NonBuildersClub:
        return ReturnError("You must be a Builders Club member to accept trades")
    
    OppositeUser : User = User.query.filter_by(id=TradeObj.sender_userid).first()
    if OppositeUser is None:
        return ReturnError("An error occured while trying to complete this trade. Please try again later.")
    OppositeUserCurrentMembership : MembershipType = GetUserMembership(OppositeUser.id)
    if OppositeUserCurrentMembership == MembershipType.NonBuildersClub:
        return ReturnError("The other user must be a Builders Club member to accept trades")
    
    TradeItems : list[UserTradeItem] = UserTradeItem.query.filter_by(tradeid=TradeObj.id).all()
    for TradeItem in TradeItems:
        UserAssetObj : UserAsset = UserAsset.query.filter_by(id=TradeItem.user_asset_id).first()
        if UserAssetObj is None:
            return ReturnError("One of the items no longer exists and this trade cannot be completed.", 400)
        if UserAssetObj.userid != TradeItem.userid:
            return ReturnError("One of the items no longer belongs to its original owner and this trade cannot be completed.", 400)
    
    SenderRobuxBal, _ = GetUserBalance(GetUserFromId(TradeObj.sender_userid))
    RecipientRobuxBal, _ = GetUserBalance(GetUserFromId(TradeObj.recipient_userid))

    if SenderRobuxBal < TradeObj.sender_userid_robux:
        return ReturnError("You do not have enough Robux to complete this trade.")
    
    if RecipientRobuxBal < TradeObj.recipient_userid_robux:
        return ReturnError("The other user does not have enough Robux to complete this trade.")
    
    ItemLocks = []
    for TradeItem in TradeItems:
        TradeItemLock = redislock.acquire_lock(f"item:{str(TradeItem.user_asset_id)}", acquire_timeout=20, lock_timeout=5)
        if not TradeItemLock:
            for ItemLock in ItemLocks:
                redislock.release_lock(f"item:{str(ItemLock[1])}", ItemLock[0])
            return ReturnError("An error occured while trying to complete this trade. Please try again later.")
        ItemLocks.append([TradeItemLock, TradeItem.user_asset_id])

    def ReleaseAllLocks():
        for ItemLock in ItemLocks:
            redislock.release_lock(f"item:{str(ItemLock[1])}", ItemLock[0])

    if TradeObj.sender_userid_robux > 0:
        DecrementTargetBalance(GetUserFromId(TradeObj.sender_userid), TradeObj.sender_userid_robux, 0)
        FinalAdded = math.floor(TradeObj.sender_userid_robux * 0.7)
        IncrementTargetBalance(GetUserFromId(TradeObj.recipient_userid), FinalAdded, 0)
    if TradeObj.recipient_userid_robux > 0:
        DecrementTargetBalance(GetUserFromId(TradeObj.recipient_userid), TradeObj.recipient_userid_robux, 0)
        FinalAdded = math.floor(TradeObj.recipient_userid_robux * 0.7)
        IncrementTargetBalance(GetUserFromId(TradeObj.sender_userid), FinalAdded, 0)

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
        if UserAssetObj.userid == TradeObj.sender_userid:
            CreateItemTransferLog( original_owner_id = TradeObj.sender_userid, new_owner_id = TradeObj.recipient_userid, asset_id = UserAssetObj.assetid, user_asset_id = UserAssetObj.id )
            UserAssetObj.userid = TradeObj.recipient_userid
        else:
            CreateItemTransferLog( original_owner_id = TradeObj.sender_userid, new_owner_id = TradeObj.recipient_userid, asset_id = UserAssetObj.assetid, user_asset_id = UserAssetObj.id )
            UserAssetObj.userid = TradeObj.sender_userid

        UserAssetObj.price = 0
        UserAssetObj.is_for_sale = False
        UserAssetObj.updated = datetime.utcnow()
        db.session.commit()

    TradeObj.status = TradeStatus.Accepted
    TradeObj.updated_at = datetime.utcnow()
    db.session.commit()
    ReleaseAllLocks()

    return jsonify({
        "success": True,
        "message": "Trade Completed",
        "data": None
    })

@PublicAPIRoute.route("/v1/trade/decline/<int:tradeid>", methods=["POST"])
@auth.authenticated_required_api
@csrf.exempt
def declineTrade( tradeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return ReturnError("Trade not found", 404)
    if TradeObj.recipient_userid != AuthenticatedUser.id:
        return ReturnError("You are not the recipient of this trade")
    if TradeObj.status != TradeStatus.Pending:
        return ReturnError("Trade is not pending")
    if TradeObj.expires_at < datetime.utcnow():
        TradeObj.status = TradeStatus.Expired
        TradeObj.updated_at = datetime.utcnow()
        db.session.commit()
        return ReturnError("Trade has expired")
    
    TradeObj.status = TradeStatus.Declined
    TradeObj.updated_at = datetime.utcnow()
    db.session.commit()

    return jsonify({
        "success": True,
        "message": "Trade Declined",
        "data": None
    })

@PublicAPIRoute.route("/v1/trade/cancel/<int:tradeid>", methods=["POST"])
@auth.authenticated_required_api
@csrf.exempt
def cancelTrade( tradeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    TradeObj : UserTrade = UserTrade.query.filter_by(id=tradeid).first()
    if TradeObj is None:
        return ReturnError("Trade not found", 404)
    if TradeObj.sender_userid != AuthenticatedUser.id:
        return ReturnError("You are not the sender of this trade")
    if TradeObj.status != TradeStatus.Pending:
        return ReturnError("Trade is not pending")
    if TradeObj.expires_at < datetime.utcnow():
        TradeObj.status = TradeStatus.Expired
        TradeObj.updated_at = datetime.utcnow()
        db.session.commit()
        return ReturnError("Trade has expired")
    
    TradeObj.status = TradeStatus.Cancelled
    TradeObj.updated_at = datetime.utcnow()
    db.session.commit()

    return jsonify({
        "success": True,
        "message": "Trade Cancelled",
        "data": None
    })