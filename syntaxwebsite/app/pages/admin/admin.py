from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort
from functools import wraps
from app.extensions import db, redis_controller, csrf, limiter
import uuid
import json
import base64
import re
from datetime import datetime, timedelta, timezone
from app.enums.AssetType import AssetType
import hashlib
import os
import requests
import logging
import random
import time
import threading
import random
import string
from sqlalchemy import or_, and_, func
from config import Config
config = Config()

from app.routes.asset import migrateAsset
from app.util import auth, assetversion, discord, redislock
from app.services import economy, gameserver_comm
from app.models.admin_permissions import AdminPermissions
from app.models.user import User
from app.models.gameservers import GameServer
from app.models.placeservers import PlaceServer
from app.models.placeserver_players import PlaceServerPlayer
from app.models.fflag_group import FflagGroup
from app.models.fflag_value import FflagValue
from app.models.asset import Asset
from app.models.asset_version import AssetVersion
from app.models.asset_moderation_link import AssetModerationLink
from app.models.asset_thumbnail import AssetThumbnail
from app.models.place_icon import PlaceIcon
from app.models.past_usernames import PastUsername
from app.models.usereconomy import UserEconomy
from app.models.login_records import LoginRecord
from app.models.place import Place
from app.models.linked_discord import LinkedDiscord
from app.models.user_ban import UserBan
from app.models.giftcard_key import GiftcardKey
from app.models.invite_key import InviteKey
from app.models.groups import Group, GroupIcon
from app.models.userassets import UserAsset
from app.models.user_avatar_asset import UserAvatarAsset
from app.models.user_hwid_log import UserHWIDLog
from app.models.game_session_log import GameSessionLog
from app.models.user_transactions import UserTransaction
from app.models.moderator_note import ModeratorNote
from app.models.universe import Universe
from app.models.limited_item_transfers import LimitedItemTransfer
from app.enums.GiftcardType import GiftcardType
from app.enums.BanType import BanType
from app.enums.TransactionType import TransactionType
from app.enums.LimitedItemTransferMethod import LimitedItemTransferMethod
from app.routes.jobreporthandler import EvictPlayer
from app.routes.thumbnailer import TakeThumbnail, TakeUserThumbnail
from app.pages.admin.permissionsdefinition import PermissionsDefinition
from app.pages.messages.messages import CreateSystemMessage

def GetCreatorOfAsset( AssetObj : Asset ) -> User | Group | None:
    if AssetObj.creator_type == 0:
        return User.query.filter_by(id=AssetObj.creator_id).first()
    elif AssetObj.creator_type == 1:
        return Group.query.filter_by(id=AssetObj.creator_id).first()
    return None

def AdminPermissionRequired(permission):
    UserObj : User = auth.GetCurrentUser()
    UserAdminPermission = AdminPermissions.query.filter_by(userid=UserObj.id, permission=permission).first()
    if UserAdminPermission is None:
        abort(403)        

def HasAdminPermission(permission) -> bool:
    UserObj : User = auth.GetCurrentUser()
    UserAdminPermission = AdminPermissions.query.filter_by(userid=UserObj.id, permission=permission).first()
    if UserAdminPermission is None:
        return False
    return True

def IsUserAnAdministrator( UserObj : User, AvoidCache : bool = False) -> bool:
    if not AvoidCache:
        CachedResult = redis_controller.get(f"IsUserAnAdministrator:Lookup:{UserObj.id}")
        if CachedResult is not None:
            try:
                return CachedResult == "1"
            except:
                pass
    isUserAdministrator = AdminPermissions.query.filter_by(userid=UserObj.id).first() is not None
    redis_controller.set(f"IsUserAnAdministrator:Lookup:{UserObj.id}", int(isUserAdministrator), ex = 60)

    return isUserAdministrator

def GetAmountOfPendingAssets( AvoidCache : bool = False ) -> int:
    if not AvoidCache:
        CachedResult = redis_controller.get("GetAmountOfPendingAssets:Lookup")
        if CachedResult is not None:
            try:
                return int(CachedResult)
            except:
                pass
    PendingAssetsCount = Asset.query.filter_by(moderation_status=1).count() + PlaceIcon.query.filter_by(moderation_status=1).count() + AssetThumbnail.query.filter_by(moderation_status=1).count() + GroupIcon.query.filter_by(moderation_status=1).count()
    redis_controller.set("GetAmountOfPendingAssets:Lookup", str(PendingAssetsCount), ex = 10)

    return PendingAssetsCount

def MustBeAdmin(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not auth.isAuthenticated():
            return redirect("/login")
        UserObj : User = auth.GetCurrentUser()
        UserAdminPermission = AdminPermissions.query.filter_by(userid=UserObj.id).first()
        if UserAdminPermission is None:
            return redirect("/home")
        return f(*args, **kwargs)
    return decorated_function

def GetAdminPermissions():
    # Get admin permissions for the current user
    # and returns them in a array
    UserObj : User = auth.GetCurrentUser()
    UserAdminPermissions = AdminPermissions.query.filter_by(userid=UserObj.id).all()
    if UserAdminPermissions is None:
        return []
    UserAdminPermissionsArray = []
    for UserAdminPermission in UserAdminPermissions:
        UserAdminPermissionsArray.append(UserAdminPermission.permission)
    return UserAdminPermissionsArray

AdminRoute = Blueprint('admin', __name__, url_prefix='/admin')

@AdminRoute.before_request
def before_request():
    if not auth.isAuthenticated():
        return redirect("/login")
    AuthTokenInfo = auth.GetCurrentUser()
    UserAdminPermission = AdminPermissions.query.filter_by(userid=int(AuthTokenInfo[0])).first()
    if UserAdminPermission is None:
        return redirect("/home")

@AdminRoute.route('/', methods=['GET'])
def admin():
    userPermissions = []
    for permission in GetAdminPermissions():
        if permission in PermissionsDefinition:
            userPermissions.append(PermissionsDefinition[permission])
    AuthenticatedUser : User = auth.GetCurrentUser()
    stats = {}
    stats['UsersPlaying'] = PlaceServerPlayer.query.count()
    stats['PlaceServersCount'] = PlaceServer.query.count()
    stats['UsersOnline'] = User.query.filter(User.lastonline > (datetime.utcnow() - timedelta(minutes=1))).count()
    stats['UsersSignedUpToday'] = User.query.filter(User.created > (datetime.utcnow() - timedelta(days=1))).count()
    stats['PendingAssets'] = Asset.query.filter_by(moderation_status=1).count() + PlaceIcon.query.filter_by(moderation_status=1).count() + AssetThumbnail.query.filter_by(moderation_status=1).count() + GroupIcon.query.filter_by(moderation_status=1).count()
    stats['SystemTime'] = datetime.utcnow()
    return render_template('admin/index.html', permissions = userPermissions, stats = stats, user = AuthenticatedUser)

@AdminRoute.route('/gameservers', methods=['GET'])
def gameservers():
    AdminPermissionRequired('GameServerManager')

    gameServers = GameServer.query.all()

    return render_template('admin/gameservers/index.html', gameservers = gameServers)

@AdminRoute.route('/gameservers/<serverid>', methods=['GET'])
def gameservers_view(serverid):
    AdminPermissionRequired('GameServerManager')

    gameServer : GameServer = GameServer.query.filter_by(serverId=serverid).first()
    if gameServer is None:
        return redirect("/admin/gameservers")

    return render_template('admin/gameservers/view.html', gameserver = gameServer)

@AdminRoute.route('/gameservers/<serverid>/delete', methods=['GET'])
def gameservers_delete(serverid):
    AdminPermissionRequired('GameServerManager')

    gameServer : GameServer = GameServer.query.filter_by(serverId=serverid).first()
    if gameServer is None:
        return redirect("/admin/gameservers")
    return render_template("/admin/gameservers/delete.html", gameserver = gameServer)

@AdminRoute.route('/gameservers/<serverid>/delete', methods=['POST'])
def gameservers_delete_post(serverid):
    AdminPermissionRequired('GameServerManager')

    gameServer : GameServer = GameServer.query.filter_by(serverId=serverid).first()
    if gameServer is None:
        return redirect("/admin/gameservers")

    db.session.delete(gameServer)
    db.session.commit()

    return redirect("/admin/gameservers")

@AdminRoute.route('/gameservers/<serverid>/edit', methods=['POST'])
def gameservers_edit(serverid):
    AdminPermissionRequired('GameServerManager')
    gameServer : GameServer = GameServer.query.filter_by(serverId=serverid).first()
    if gameServer is None:
        return redirect("/admin/gameservers")
    if request.form['name'] == "" or request.form['serverip'] == "" or request.form['serverport'] == "" or request.form['accesskey'] == "":
        flash("Please fill in all fields", "danger")
        return redirect("/admin/gameservers/" + serverid)
    
    gameServer.serverName = request.form['name']
    gameServer.serverIP = request.form['serverip']
    gameServer.serverPort = request.form['serverport']
    gameServer.accessKey = request.form['accesskey']
    gameServer.allowThumbnailGen = True if 'isThumbnailer' in request.form else False
    gameServer.allowGameServerHost = True if 'isGameHoster' in request.form else False
    db.session.commit()

    flash("Game server updated", "success")
    return redirect("/admin/gameservers/" + serverid)

@AdminRoute.route("/gameservers/<serverid>/refresh-accesskey", methods=['GET', 'POST'])
def gameservers_refresh_accesskey(serverid):
    AdminPermissionRequired('GameServerManager')
    GameServerObj : GameServer = GameServer.query.filter_by(serverId=serverid).first()
    if GameServerObj is None:
        return abort(404)
    
    if request.method == "GET":
        return render_template("admin/gameservers/refresh_accesskey.html", gameserver = GameServerObj)
    else:
        NewAccessKey = ''.join(random.choices(string.ascii_letters + string.digits, k=random.randint(60, 90)))
        req_response = gameserver_comm.perform_post(
            TargetGameserver = GameServerObj,
            Endpoint = "ResetAccessKeyAndRestart",
            JSONData = {
                "NewAccessKey": NewAccessKey
            },
            RequestTimeout = 30
        )

        if req_response.status_code != 200:
            flash("Failed to send request to game server", "danger")
            return redirect(f"/admin/gameservers/{serverid}")

        GameServerObj.accessKey = NewAccessKey
        db.session.commit()

        flash("Access key reset and game server restarted", "success")
        return redirect(f"/admin/gameservers/{serverid}")

@AdminRoute.route('/gameservers/create', methods=['GET'])
def gameservers_create():
    AdminPermissionRequired('GameServerManager')

    return render_template('admin/gameservers/create.html')

@AdminRoute.route('/gameservers/create', methods=['POST'])
def gameservers_create_post():
    AdminPermissionRequired('GameServerManager')
    if request.form['name'] == "" or request.form['serverip'] == "" or request.form['serverport'] == "" or request.form['accesskey'] == "":
        flash("Please fill in all fields", "danger")
        return redirect("/admin/gameservers/create")
    newServerID = str(uuid.uuid4())
    gameServer = GameServer(
        serverId = newServerID,
        serverName= request.form['name'],
        serverIP = request.form['serverip'],
        serverPort = request.form['serverport'],
        accessKey = request.form['accesskey'],
        allowThumbnailGen = True if 'isThumbnailer' in request.form else False,
        allowGameServerHost = True if 'isGameHoster' in request.form else False
    )
    db.session.add(gameServer)
    db.session.commit()

    return redirect("/admin/gameservers/" + newServerID)

@AdminRoute.route('/websitemessage', methods=['GET'])
def websitemessage():
    AdminPermissionRequired('UpdateWebsiteMessage')

    return render_template('admin/websitewidemsg.html', message = redis_controller.get("website_wide_message") or "")

@AdminRoute.route('/websitemessage', methods=['POST'])
def websitemessage_post():
    AdminPermissionRequired('UpdateWebsiteMessage')

    redis_controller.set("website_wide_message", request.form['message'])
    return redirect("/admin/websitemessage")

@AdminRoute.route('/fflags', methods=['GET'])
def fflags():
    AdminPermissionRequired('ManageFFlags')

    return render_template('admin/fflagsettings/index.html', groups = FflagGroup.query.all())

@AdminRoute.route('/fflags/<int:groupid>', methods=['GET'])
def fflags_view(groupid : int):
    AdminPermissionRequired('ManageFFlags')

    FFlagGroupObj : FflagGroup = FflagGroup.query.filter_by(group_id=groupid).first()
    if FFlagGroupObj is None:
        return redirect("/admin/fflags")
    PageNumber = max( request.args.get('page', default=1, type=int), 1 )
    SearchQuery = request.args.get('search', default=None, type=str)
    GroupFlagsPagination = FflagValue.query.filter_by(group_id=groupid)

    if SearchQuery is not None:
        GroupFlagsPagination = GroupFlagsPagination.filter(FflagValue.name.ilike(f"%{SearchQuery}%"))

    GroupFlagsPagination = GroupFlagsPagination.paginate(
        page = PageNumber,
        per_page = 50,
        error_out = False
    )
    return render_template('admin/fflagsettings/view.html', group = FFlagGroupObj, FFlagsLookupResults = GroupFlagsPagination, flagcount = GroupFlagsPagination.total, search = SearchQuery)

@AdminRoute.route('/fflags/<int:groupid>/import', methods=['POST'])
def fflags_import(groupid : int):
    from app.routes.fflagssettings import ClearCache
    AdminPermissionRequired('ManageFFlags')

    group : FflagGroup = FflagGroup.query.filter_by(group_id=groupid).first()
    if group is None:
        return redirect("/admin/fflags")

    
    if 'file' not in request.files:
        flash("No file uploaded", "danger")
        return redirect("/admin/fflags/" + groupid)
    file = request.files['file']
    
    if file.filename == '':
        flash("Filename empty", "danger")
        return redirect("/admin/fflags/" + groupid)
    
    try:
        json.loads(file.read())
    except:
        flash("Invalid JSON file", "danger")
        return redirect("/admin/fflags/" + groupid)

    FflagValue.query.filter_by(group_id=groupid).delete()
    db.session.commit()

    file.seek(0)
    data = json.loads(file.read())
    for flag in data:
        FlagName = flag
        FlagValue = data[flag]
        
        FlagType = 1
        try:
            if FlagValue.lower() == "true":
                FlagValue = True
            elif FlagValue.lower() == "false":
                FlagValue = False
            else:
                raise Exception()
        except:
            try:
                FlagValue = int(FlagValue)
                FlagType = 2
            except:
                FlagType = 3
        newFlag = FflagValue(
            group_id = groupid,
            name = FlagName,
            flag_type= FlagType,
            flag_value = base64.b64encode(str(FlagValue).encode('utf-8')).decode('utf-8')
        )
        db.session.add(newFlag)
    group.updated_at = datetime.utcnow()
    db.session.commit()
    ClearCache( groupid )
    flash("Flags imported", "success")
    return redirect("/admin/fflags/" + groupid)

@AdminRoute.route("/asset-copier", methods=['GET'])
def asset_copier():
    AdminPermissionRequired('CopyAssets')
    return render_template('admin/assetcopier.html')

@AdminRoute.route("/asset-copier", methods=['POST'])
def asset_copier_post():
    AdminPermissionRequired('CopyAssets')
    AssetURL = request.form.get('asseturl')
    if AssetURL is None:
        flash("No URL provided", "danger")
        return redirect("/admin/asset-copier")
    if AssetURL == "":
        flash("URL is empty", "danger")
        return redirect("/admin/asset-copier")
    AssetRegex = re.compile(r".com\/catalog\/(\d+)\/")
    AssetMatch = AssetRegex.search(request.form.get("asseturl"))
    if AssetMatch is None:
        flash("Invalid asset URL", "error")
        return redirect("/admin/asset-copier")
    AssetID = AssetMatch.group(1)
    # Check if asset exists
    AssetObj = Asset.query.filter_by(roblox_asset_id=int(AssetID)).first()
    if AssetObj is not None:
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    
    AuthenticatedUser = auth.GetAuthenticatedUser(request.cookies.get(".ROBLOSECURITY"))
    AssetMigrationCooldown = redis_controller.get(f"asset_migration_cooldown_{str(AuthenticatedUser.id)}")
    if AssetMigrationCooldown is not None and AuthenticatedUser.id != 1:
        flash(f"You are copying assets too fast!", "danger")
        return redirect("/admin/asset-copier")
    redis_controller.set(f"asset_migration_cooldown_{str(AuthenticatedUser.id)}", "1", 20)

    # Migrate asset
    NewAsset : Asset = migrateAsset(int(AssetID), forceMigration=False, allowedTypes=[2, 8, 11, 12, 17, 18, 19, 41, 42, 43, 44, 45, 46, 47], creatorId=1, keepRobloxId=False, migrateInfo=True)
    if NewAsset is None:
        flash("Failed to migrate asset", "danger")
        return redirect("/admin/asset-copier")
    TakeThumbnail(NewAsset.id)
    return redirect(f"/admin/manage-assets/{str(NewAsset.id)}")

def IsItemInReleasePool( AssetId : int ) -> bool:
    return redis_controller.lrange("ItemReleasePool:Items", 0, -1).count(str(AssetId)) > 0
def GetNextItemDropDateTime() -> datetime:
    LastItemDropTimestamp : str | None = redis_controller.get("ItemReleasePool:LastDropTimestamp")
    if LastItemDropTimestamp is None:
        LastItemDropTimestamp = round(time.time())
    else:
        try:
            LastItemDropTimestamp = int(LastItemDropTimestamp)
        except Exception as e:
            logging.warn(f"Admin > GetNextItemDropDateTime: Exception raised while trying to convert to integer, {str(e)}")
            LastItemDropTimestamp = round(time.time())
    RandomSeed = f"{LastItemDropTimestamp}-{config.FLASK_SESSION_KEY}"
    random.seed( RandomSeed )
    NextDropDatetime = datetime.utcfromtimestamp( LastItemDropTimestamp + random.randint( 60 * 60 * 6, 60 * 60 * 20 ) )
    return NextDropDatetime

def InsertItemIntoItemReleasePool( AssetObj : Asset, Name : str, Description : str, RobuxPrice : int = 0, TicketsPrice : int = 0, IsLimited : bool = False, IsLimitedUnique : bool = False, SerialCount : int | None = None, OffsaleAfter : timedelta | None = None ):
    if IsItemInReleasePool( AssetObj.id ):
        raise Exception("InsertItemIntoItemReleasePool: Attempted to insert item which is already inside item release pool")
    if RobuxPrice < 0 or TicketsPrice < 0:
        raise Exception("InsertItemIntoItemReleasePool: RobuxPrice and TicketsPrice cannot be a negative integer")
    if IsLimitedUnique:
        IsLimited = True
    
    ItemReleaseMetaData = json.dumps({
        "Name" : Name,
        "Description" : Description,
        "RobuxPrice" : RobuxPrice,
        "TicketsPrice" : TicketsPrice,
        "IsLimited" : IsLimited,
        "IsLimitedUnique" : IsLimitedUnique,
        "SerialCount": SerialCount,
        "OffsaleAfter" : None if OffsaleAfter is None else OffsaleAfter.total_seconds()
    })

    redis_controller.set(f"ItemReleasePool:Item_Metadata:{AssetObj.id}", ItemReleaseMetaData)
    redis_controller.rpush("ItemReleasePool:Items", str(AssetObj.id))
    logging.info(f"Inserted Item {AssetObj.id} into Item Release Pool")

    AssetObj.name = "Asset"
    AssetObj.description = ""
    AssetObj.price_robux = 0
    AssetObj.price_tix = 0
    AssetObj.is_limited = False
    AssetObj.is_limited_unique = False
    AssetObj.moderation_status = 2 # Hides the asset from people scraping every asset

    db.session.commit()

@AdminRoute.route("/manage-assets/<int:assetid>", methods=['GET'])
@AdminRoute.route("/manage-assets", methods=['GET'])
def manage_assets(assetid = None):
    AdminPermissionRequired('ManageAsset')
    if assetid is not None:
        AssetObj : Asset = Asset.query.filter_by(id=int(assetid)).first()
        if AssetObj is None:
            flash("Asset does not exist", "danger")
            return redirect("/admin/manage-assets")
        if (AssetObj.creator_id != 1 and AssetObj.creator_id != 2) and AssetObj.creator_type != 0: # Only allows assets under ROBLOX and UGC accounts
            flash("Asset is not a offical asset", "danger")
            return redirect("/admin/manage-assets")
        if AssetObj.asset_type not in [AssetType(1), AssetType(2), AssetType(3), AssetType(4), AssetType(8), AssetType(11), AssetType(12), AssetType(17), AssetType(18), AssetType(19), AssetType(27), AssetType(28), AssetType(29), AssetType(30), AssetType(31), AssetType(32), AssetType(41), AssetType(42), AssetType(43), AssetType(44), AssetType(45), AssetType(46), AssetType(47), AssetType(57), AssetType(58)]:#[1,2,3,4,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
            flash("Asset type is not supported", "danger")
            return redirect("/admin/manage-assets")
        CanManageItemReleasePool = HasAdminPermission("ManageItemReleases")
        IsItemEligibleForItemReleasePool = AssetObj.is_for_sale is False and AssetObj.is_limited is False and AssetObj.sale_count == 0 
        return render_template('admin/manageassets.html', asset = AssetObj, CanManageItemReleasePool = CanManageItemReleasePool, IsItemEligibleForItemReleasePool = IsItemEligibleForItemReleasePool)
    return render_template('admin/manageassets.html')

@AdminRoute.route("/manage-assets/<int:assetid>/insert-item-pool", methods=['GET'])
def insert_item_into_pool( assetid : int ):
    AdminPermissionRequired('ManageAsset')
    AdminPermissionRequired('ManageItemReleases')

    AssetObj : Asset = Asset.query.filter_by(id=int(assetid)).first()
    if AssetObj is None:
        flash("Asset does not exist", "danger")
        return redirect("/admin/manage-assets")
    if (AssetObj.creator_id != 1 and AssetObj.creator_id != 2) and AssetObj.creator_type != 0: # Only allows assets under ROBLOX and UGC accounts
        flash("Asset is not a offical asset", "danger")
        return redirect("/admin/manage-assets")
    if AssetObj.asset_type not in [AssetType(1), AssetType(2), AssetType(3), AssetType(4), AssetType(8), AssetType(11), AssetType(12), AssetType(17), AssetType(18), AssetType(19), AssetType(27), AssetType(28), AssetType(29), AssetType(30), AssetType(31), AssetType(32), AssetType(41), AssetType(42), AssetType(43), AssetType(44), AssetType(45), AssetType(46), AssetType(47), AssetType(57), AssetType(58)]:#[1,2,3,4,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
        flash("Asset type is not supported", "danger")
        return redirect("/admin/manage-assets")
    
    if IsItemInReleasePool(AssetObj.id):
        flash("Item is already inside the item release pool", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    IsItemEligibleForItemReleasePool = AssetObj.is_for_sale is False and AssetObj.is_limited is False and AssetObj.sale_count == 0 
    if not IsItemEligibleForItemReleasePool:
        flash("Item is not eligible for item release pool", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    
    return render_template('admin/insertitemrelasepool.html', asset = AssetObj)

@AdminRoute.route("/manage-assets/<int:assetid>/insert-item-pool", methods=['POST'])
def insert_item_into_pool_post( assetid : int ):
    AdminPermissionRequired('ManageAsset')
    AdminPermissionRequired('ManageItemReleases')

    AssetObj : Asset = Asset.query.filter_by(id=int(assetid)).first()
    if AssetObj is None:
        flash("Asset does not exist", "danger")
        return redirect("/admin/manage-assets")
    if (AssetObj.creator_id != 1 and AssetObj.creator_id != 2) and AssetObj.creator_type != 0: # Only allows assets under ROBLOX and UGC accounts
        flash("Asset is not a offical asset", "danger")
        return redirect("/admin/manage-assets")
    if AssetObj.asset_type not in [AssetType(1), AssetType(2), AssetType(3), AssetType(4), AssetType(8), AssetType(11), AssetType(12), AssetType(17), AssetType(18), AssetType(19), AssetType(27), AssetType(28), AssetType(29), AssetType(30), AssetType(31), AssetType(32), AssetType(41), AssetType(42), AssetType(43), AssetType(44), AssetType(45), AssetType(46), AssetType(47), AssetType(57), AssetType(58)]:#[1,2,3,4,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
        flash("Asset type is not supported", "danger")
        return redirect("/admin/manage-assets")
    
    if IsItemInReleasePool(AssetObj.id):
        flash("Item is already inside the item release pool", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    IsItemEligibleForItemReleasePool = AssetObj.is_for_sale is False and AssetObj.is_limited is False and AssetObj.sale_count == 0 
    if not IsItemEligibleForItemReleasePool:
        flash("Item is not eligible for item release pool", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")

    AssetName = request.form.get('assetname', default=AssetObj.name, type=str)
    AssetDescription = request.form.get('assetdescription', default=AssetObj.description, type=str)
    AssetPriceRobux = request.form.get('assetpricerobux', default = None, type=int)
    AssetPriceTickets = request.form.get('assetpricetix', default = None, type=int)
    AssetSerialAmount = request.form.get('assetserialamount', default = None, type=int)
    isLimited = request.form.get('isLimited') == "on"
    isLimitedUnique = request.form.get('isLimitedUnique') == "on"

    if AssetName is None or AssetName == "":
        flash("Asset name is empty", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")
    if AssetDescription is None:
        flash("Asset description is empty", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")

    if isLimitedUnique:
        isLimited = True
    if not HasAdminPermission("ModifyLimitedAssets") and isLimited:
        flash("You do not have permission to create Limiteds", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")
    if AssetSerialAmount < 0:
        flash("Asset serial amount cannot be negative", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")
    if AssetPriceRobux < 0 or AssetPriceRobux > 1000000:
        flash("Asset Robux price must be in range ( 0 - 1000000)", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")
    if AssetPriceTickets < 0 or AssetPriceTickets > 10000000:
        flash("Asset Tix price must be in range ( 0 - 10000000)", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")
    if AssetSerialAmount > 0 and not isLimitedUnique:
        flash("Asset serial cannot be greater than 0 if not a limited unique", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")

    AssetOffsaleHours = request.form.get('offsale-at-hours', default=None, type=int)
    AssetOffsaleMinutes = request.form.get('offsale-at-minutes', default=None, type=int)
    AssetOffsaleSeconds = request.form.get('offsale-at-seconds', default=None, type=int)
    if AssetOffsaleHours is not None or AssetOffsaleMinutes is not None or AssetOffsaleSeconds is not None:
        AssetOffsaleHours = AssetOffsaleHours or 0
        AssetOffsaleMinutes = AssetOffsaleMinutes or 0
        AssetOffsaleSeconds = AssetOffsaleSeconds or 0

        OffsaleDelta = timedelta(
            hours = AssetOffsaleHours,
            minutes = AssetOffsaleMinutes,
            seconds = AssetOffsaleSeconds
        )
        if timedelta(minutes = 5) > OffsaleDelta:
            flash("Offsale Time cannot be lesser than 5 minutes", "danger")
            return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")
    else:
        OffsaleDelta = None

    if OffsaleDelta and isLimited:
        flash("Limited unique assets cannot have a offsale date", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}/insert-item-pool")

    InsertItemIntoItemReleasePool(
        AssetObj = AssetObj,
        Name = AssetName,
        Description = AssetDescription,
        RobuxPrice = AssetPriceRobux,
        TicketsPrice = AssetPriceTickets,
        IsLimited = isLimited,
        IsLimitedUnique = isLimitedUnique,
        SerialCount = AssetSerialAmount
    )

    flash("Successfully inserted item into item release pool", "success")
    return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")

@AdminRoute.route("/item-release-pool", methods=["GET"])
def item_release_pool_view():
    AdminPermissionRequired('ManageItemReleases')
    PlannedItems = []
    AllAssetIds = redis_controller.lrange("ItemReleasePool:Items", 0, -1)
    for AssetId in AllAssetIds:
        AssetMetadata = redis_controller.get(f"ItemReleasePool:Item_Metadata:{AssetId}")
        if AssetMetadata is None:
            logging.warn(f"item_release_pool_view failed to get asset metadata for {AssetId}, removing it from list")
            redis_controller.lrem("ItemReleasePool:Items", 0, AssetId)
            return
        try:
            AssetMetadata = json.loads(AssetMetadata)
        except Exception as e:
            logging.warn(f"item_release_pool_view failed to parse json from item metadata {AssetId}, {str(e)}")
            redis_controller.lrem("ItemReleasePool:Items", 0, AssetId)
            return
        
        PlannedItems.append({
            "id": int(AssetId),
            "name": AssetMetadata["Name"],
            "description": AssetMetadata["Description"],
            "robux_price": AssetMetadata["RobuxPrice"],
            "tickets_price": AssetMetadata["TicketsPrice"],
            "is_limited": AssetMetadata["IsLimited"],
            "is_limited_unique": AssetMetadata["IsLimitedUnique"],
            "serial_count": AssetMetadata["SerialCount"],
            "offsale_after": AssetMetadata["OffsaleAfter"]
        })
    
    if HasAdminPermission("ViewItemReleasePoolDrop"):
        NextItemDropDatetime = f"{GetNextItemDropDateTime()} UTC"
    else:
        NextItemDropDatetime = "You do not have permission to view the next Drop Time"

    return render_template("admin/itemreleasepool.html", PlannedItems=PlannedItems, NextItemDropDatetime=NextItemDropDatetime)


@AdminRoute.route("/manage-assets", methods=['POST'])
def manage_assets_post():
    AdminPermissionRequired('ManageAsset')
    AssetID = request.form.get('assetid')
    if AssetID is None:
        flash("No asset ID provided", "danger")
        return redirect("/admin/manage-assets")
    if AssetID == "":
        flash("Asset ID is empty", "danger")
        return redirect("/admin/manage-assets")
    AssetObj : Asset = Asset.query.filter_by(id=int(AssetID)).first()
    if AssetObj is None:
        flash("Asset does not exist", "danger")
        return redirect("/admin/manage-assets")
    if (AssetObj.creator_id != 1 and AssetObj.creator_id != 2) and AssetObj.creator_type != 0: # Only allows assets under ROBLOX and UGC accounts
        flash("Asset is not a offical asset", "danger")
        return redirect("/admin/manage-assets")
    if AssetObj.asset_type not in [AssetType(1), AssetType(2), AssetType(3), AssetType(4), AssetType(8), AssetType(11), AssetType(12), AssetType(17), AssetType(18), AssetType(19), AssetType(27), AssetType(28), AssetType(29), AssetType(30), AssetType(31), AssetType(32), AssetType(41), AssetType(42), AssetType(43), AssetType(44), AssetType(45), AssetType(46), AssetType(47), AssetType(57), AssetType(58)]:
        flash("Asset type is not supported", "danger")
        return redirect("/admin/manage-assets")
    return redirect(f"/admin/manage-assets/{str(AssetID)}")

from app.extensions import scheduler
def SetAssetOffsaleJob( assetId : int ):
    with scheduler.app.app_context():
        AssetObj : Asset = Asset.query.filter_by(id=assetId).first()
        if AssetObj is None:
            return
        if AssetObj.offsale_at is None:
            return
        if AssetObj.offsale_at > datetime.utcnow() + timedelta(minutes=5):
            logging.warning(f"Asset {str(AssetObj.id)} has a offsale date in the future more than 5 minutes diff, skipping")
            return
        AssetObj.is_for_sale = False
        AssetObj.offsale_at = None
        db.session.commit()
        logging.info(f"Asset {str(AssetObj.id)} has been set offsale at {str(datetime.utcnow())}")
        redis_controller.delete(f"APSchedulerTaskJobUUID:{str(AssetObj.id)}")

@AdminRoute.route("/manage-assets/<int:assetid>", methods=['POST'])
def manage_assets_post_update(assetid):
    AdminPermissionRequired('ManageAsset')
    AssetObj : Asset = Asset.query.filter_by(id=int(assetid)).first()
    if AssetObj is None:
        flash("Asset does not exist", "danger")
        return redirect("/admin/manage-assets")
    if (AssetObj.creator_id != 1 and AssetObj.creator_id != 2) and AssetObj.creator_type != 0: # Only allows assets under ROBLOX and UGC accounts
        flash("Asset is not a offical asset", "danger")
        return redirect("/admin/manage-assets")
    if AssetObj.asset_type not in [AssetType(1), AssetType(2), AssetType(3), AssetType(4), AssetType(8), AssetType(11), AssetType(12), AssetType(17), AssetType(18), AssetType(19), AssetType(27), AssetType(28), AssetType(29), AssetType(30), AssetType(31), AssetType(32), AssetType(41), AssetType(42), AssetType(43), AssetType(44), AssetType(45), AssetType(46), AssetType(47), AssetType(57), AssetType(58)]:
        flash("Asset type is not supported", "danger")
        return redirect("/admin/manage-assets")
    if AssetObj.is_limited or AssetObj.is_limited_unique:
        if not HasAdminPermission("ModifyLimitedAssets"):
            flash("You do not have permission to modify limited assets", "danger")
            return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if IsItemInReleasePool(AssetObj.id):
        flash("You cannot edit an item which is in the item release pool", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    # Validate form
    AssetName = request.form.get('assetname')
    AssetDescription = request.form.get('assetdescription')
    AssetPriceRobux = request.form.get('assetpricerobux')
    AssetPriceTickets = request.form.get('assetpricetix')
    AssetSerialAmount = request.form.get('assetserialamount')

    AssetOffsaleAt = request.form.get('offsale-at', None) # Year-Month-DayTHour:Minute
    OffsaleTimezone = request.form.get('offsale-timezone', 0, int) # 0, 1, 2, ... or -1, -2, ...
    if AssetOffsaleAt is not None and AssetOffsaleAt != "":
        try:
            AssetOffsaleAt = datetime.strptime(AssetOffsaleAt, "%Y-%m-%dT%H:%M")
            # We need to convert the time to UTC
            AssetOffsaleAt = AssetOffsaleAt.replace(tzinfo=timezone(timedelta(hours=OffsaleTimezone)))
            AssetOffsaleAt = AssetOffsaleAt.astimezone(timezone.utc)
            AssetOffsaleAt = datetime(
                AssetOffsaleAt.year,
                AssetOffsaleAt.month,
                AssetOffsaleAt.day,
                AssetOffsaleAt.hour,
                AssetOffsaleAt.minute,
                AssetOffsaleAt.second,
                AssetOffsaleAt.microsecond
            )
        except:
            flash("Invalid offsale date", "danger")
            return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
        if datetime.utcnow() > AssetOffsaleAt:
            flash("Offsale date cannot be in the past", "danger")
            return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    else:
        AssetOffsaleAt = None

    isForSale = request.form.get('isForsale') == "on"
    isLimited = request.form.get('isLimited') == "on"
    isLimitedUnique = request.form.get('isLimitedUnique') == "on"

    if AssetName is None or AssetName == "":
        flash("Asset name is empty", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetDescription is None:
        flash("Asset description is empty", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetPriceRobux is None or AssetPriceRobux == "":
        flash("Asset price is empty", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    else:
        try:
            AssetPriceRobux = int(AssetPriceRobux)
        except:
            flash("Asset price is not a number", "danger")
            return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetPriceTickets is None or AssetPriceTickets == "":
        flash("Asset price is empty", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    else:
        try:
            AssetPriceTickets = int(AssetPriceTickets)
        except:
            flash("Asset price is not a number", "danger")
            return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetSerialAmount is None or AssetSerialAmount == "":
        flash("Asset serial amount is empty", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    else:
        try:
            AssetSerialAmount = int(AssetSerialAmount)
        except:
            flash("Asset serial amount is not a number", "danger")
            return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetSerialAmount < 0:
        flash("Asset serial amount cannot be negative", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetPriceRobux < 0 or AssetPriceRobux > 1000000:
        flash("Asset Robux price must be in range ( 0 - 1000000)", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetPriceTickets < 0 or AssetPriceTickets > 10000000:
        flash("Asset Tix price must be in range ( 0 - 10000000)", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetSerialAmount > 0 and not isLimitedUnique:
        flash("Asset serial cannot be greater than 0 if not a limited unique", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")

    AuthenticatedUser : User = auth.GetCurrentUser()
    # Check for cooldown
    AdministratorCooldown = redis_controller.get(f"Asset_AdministratorCooldown:{str(AuthenticatedUser.id)}")
    if AdministratorCooldown is not None and AuthenticatedUser.id != 1:
        flash("You are updating assets too quickly!", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    redis_controller.set(f"Asset_AdministratorCooldown:{str(AuthenticatedUser.id)}", "1", ex=20)

    if isLimitedUnique:
        isLimited = True

    if isLimited:
        if not HasAdminPermission("ModifyLimitedAssets"):
            flash("You do not have permission to modify limited assets", "danger")
            return redirect("/admin/manage-assets")

    if isLimitedUnique and AssetOffsaleAt is not None:
        flash("Limited unique assets cannot have a offsale date", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if not isForSale and AssetOffsaleAt is not None:
        flash("Asset cannot have a offsale date if not for sale", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    if AssetOffsaleAt is not None and AssetOffsaleAt < datetime.utcnow() + timedelta( minutes = 5 ):
        flash("Offsale time cannot be shorter than 5 minutes", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")

    # Update asset
    AssetObj.name = AssetName
    AssetObj.description = AssetDescription
    AssetObj.price_robux = AssetPriceRobux
    AssetObj.price_tix = AssetPriceTickets
    AssetObj.serial_count = AssetSerialAmount
    AssetObj.is_for_sale = isForSale
    AssetObj.is_limited = isLimited
    AssetObj.is_limited_unique = isLimitedUnique
    AssetObj.updated_at = datetime.utcnow()
    
    if AssetOffsaleAt is not None and AssetObj.offsale_at != AssetOffsaleAt:
        AssetObj.offsale_at = AssetOffsaleAt
        if redis_controller.exists(f"APSchedulerTaskJobUUID:{str(AssetObj.id)}"):
            try:
                scheduler.remove_job(redis_controller.get(f"APSchedulerTaskJobUUID:{str(AssetObj.id)}"))
            except:
                logging.warning(f"Failed to remove job {redis_controller.get(f'APSchedulerTaskJobUUID:{str(AssetObj.id)}')}")

        APSchedulerTaskJobUUID = str(uuid.uuid4())
        scheduler.add_job(id=APSchedulerTaskJobUUID, func=SetAssetOffsaleJob, trigger='date', run_date=AssetOffsaleAt, args=[AssetObj.id])
        redis_controller.set(f"APSchedulerTaskJobUUID:{str(AssetObj.id)}", APSchedulerTaskJobUUID)
        logging.info(f"Asset {str(AssetObj.id)} has been set to go offsale at {str(AssetOffsaleAt)}, job UUID: {APSchedulerTaskJobUUID}")
    if not isForSale:
        AssetObj.offsale_at = None

    db.session.commit()
    flash("Asset updated!", "success")
    return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")

@AdminRoute.route("/manage-assets/<int:assetid>/rerender", methods=['POST'])
def ReRenderAsset(assetid):
    AdminPermissionRequired('ManageAsset')
    AssetObj : Asset = Asset.query.filter_by(id=int(assetid)).first()
    if AssetObj is None:
        flash("Asset does not exist", "danger")
        return redirect("/admin/manage-assets")
    if (AssetObj.creator_id != 1 and AssetObj.creator_id != 2) and AssetObj.creator_type != 0:
        flash("Asset is not a offical asset", "danger")
        return redirect("/admin/manage-assets")
    # Check for cooldown
    AuthenticatedUser : User = auth.GetAuthenticatedUser(request.cookies.get(".ROBLOSECURITY"))
    AdministratorCooldown = redis_controller.get(f"AssetRerender_AdministratorCooldown:{str(AuthenticatedUser.id)}")
    if AdministratorCooldown is not None and AuthenticatedUser.id != 1:
        flash("You are rerendering assets too quickly!", "danger")
        return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")
    redis_controller.set(f"AssetRerender_AdministratorCooldown:{str(AuthenticatedUser.id)}", "1", ex=5)

    TakeThumbnail(AssetObj.id, bypassCooldown=True, bypassCache=True)
    flash("Asset queued for rerendering", "success")
    return redirect(f"/admin/manage-assets/{str(AssetObj.id)}")

@AdminRoute.route("/pending-assets", methods=['GET'])
def PendingAssets():
    AdminPermissionRequired('AssetModeration')
    
    PendingAssets = []
    # Only get assets that have their moderation_status set to 1
    AssetsPendingList : list[Asset] = Asset.query.filter_by(moderation_status=1).order_by(Asset.created_at.desc()).all()
    for AssetObj in AssetsPendingList:
        if AssetObj.asset_type not in [AssetType.Image, AssetType.Audio]: # Only get images and audio
            continue
        LatestAssetVersion : AssetVersion = assetversion.GetLatestAssetVersion(AssetObj)
        if LatestAssetVersion is None:
            continue
        ParentAsset : Asset = None
        if AssetObj.asset_type == AssetType.Image:
            # Try to get the parent asset
            ParentAssetLink : AssetModerationLink = AssetModerationLink.query.filter_by(ChildAssetId=AssetObj.id).first()
            if ParentAssetLink is not None:
                ParentAsset = Asset.query.filter_by(id=ParentAssetLink.ParentAssetId).first()
        PendingAssets.append({
            "Asset": AssetObj,
            "AssetVersion": LatestAssetVersion,
            "ParentAsset": ParentAsset
        })
        if len(PendingAssets) >= 15:
            break
    PlaceIconPendingList : list[PlaceIcon] = PlaceIcon.query.filter_by(moderation_status=1).order_by(PlaceIcon.updated_at.desc()).all()
    for PlaceIconObj in PlaceIconPendingList:
        AssetObj : Asset = Asset.query.filter_by(id=PlaceIconObj.placeid).first()
        if AssetObj is None:
            continue
        PendingAssets.append({
            "Asset": AssetObj,
            "AssetVersion": PlaceIconObj,
            "ParentAsset": None,
            "PlaceIcon": True,
            "AssetThumbnail": False
        })
        if len(PendingAssets) >= 15:
            break
    
    AssetThumbnailPendingList : list[AssetThumbnail] = AssetThumbnail.query.filter_by(moderation_status=1).order_by(AssetThumbnail.updated_at.desc()).all()
    for AssetThumbnailObj in AssetThumbnailPendingList:
        AssetObj : Asset = Asset.query.filter_by(id=AssetThumbnailObj.asset_id).first()
        if AssetObj is None:
            continue
        PendingAssets.append({
            "Asset": AssetObj,
            "AssetVersion": AssetThumbnailObj,
            "ParentAsset": None,
            "PlaceIcon": False,
            "AssetThumbnail": True
        })
    
    GroupIconPendingList : list[GroupIcon] = GroupIcon.query.filter_by(moderation_status=1).order_by(GroupIcon.created_at.desc()).all()
    for GroupIconObj in GroupIconPendingList:
        GroupObj : Group = GroupIconObj.group
        if GroupObj is None:
            continue
        PendingAssets.append({
            "Group": GroupObj,
            "Creator": GroupIconObj.creator,
            "Icon": GroupIconObj,
            "ParentAsset": None,
            "PlaceIcon": False,
            "AssetThumbnail": False
        })

    return render_template("admin/assetmoderation.html", PendingAssets=PendingAssets)

def LogModerationAction(
    Actor : User,
    isApproved : bool = True,
    relatedAssets : list = []
):
    """
        relatedAssets = [
            {
                "mainId": 1,
                "relatedId": 2,
                "type": "Image",
                "view_name": "Awesome Shirt",
                "source": "https://cdn.syntax.eco/",
                "page": "https://www.syntax.eco/catalog/1/",
                "creator": User | Group
            }
        ]
    """
    fields = []
    for asset in relatedAssets:
        fields.append({
            "name": asset["view_name"],
            "value": f"Type: **{asset['type']}** - { 'AssetId' if asset['type'] != 'GroupIcon' else 'GroupId' }: **{asset['mainId']}** - Creator: [{ asset['creator'].username if isinstance(asset['creator'], User) else asset['creator'].name }](https://www.syntax.eco/{ 'users/'+str(asset['creator'].id)+'/profile' if isinstance(asset['creator'], User) else 'groups/'+str(asset['creator'].id)+'/' }){ ' - Related AssetId: **' + str(asset['relatedId']) +'**' if asset['relatedId'] else ''} - [View]({asset['page']}){ ' - [Source](' + asset['source'] +')' if asset['source'] else ''}",
            "inline": False
        })
    
    embed = {
        "type": "rich",
        "title": f"{'Approved' if isApproved else 'Denied'} {str(len(relatedAssets))} Asset{'s' if len(relatedAssets) > 1 else ''}",
        "description": "",
        "color": 0x26ff00 if isApproved else 0xef0000,
        "fields": fields,
        "author": {
            "name": Actor.username,
            "icon_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(Actor.id)}"
        },
        "footer": {
            "text": f"Syntax Asset Moderation Log"
        },
        "timestamp": datetime.utcnow().isoformat()
    }
    def thread_func():
        try:
            requests.post(
                url = config.DISCORD_ADMIN_LOGS_WEBHOOK,
                json = {
                    "username": "Syntax Asset Moderation Log",
                    "embeds": [embed],
                    "avatar_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(Actor.id)}"
                }
            )
        except Exception as e:
            logging.warn(f"Admin > LogModerationAction: Exception raised when sending webhook - {str(e)}")
    threading.Thread(target=thread_func).start()

@AdminRoute.route("/pending-assets/<content_hash>/approve-group-icon", methods=['POST'])
@csrf.exempt
def ApprovePendingGroupIcon( content_hash ):
    AdminPermissionRequired('AssetModeration')

    GroupIconObj : list[GroupIcon] = GroupIcon.query.filter_by(content_hash=content_hash).all()
    if len(GroupIconObj) == 0:
        return redirect("/admin/pending-assets")
    for iconObj in GroupIconObj:
        if iconObj.moderation_status != 1:
            continue
        LogModerationAction(auth.GetCurrentUser(), isApproved=True, relatedAssets=[{
            "mainId": iconObj.group.id,
            "relatedId": None,
            "type": "GroupIcon",
            "view_name": iconObj.group.name,
            "source": f"{config.CDN_URL}/{iconObj.content_hash}",
            "page": f"https://www.syntax.eco/groups/{str(iconObj.group.id)}/",
            "creator": iconObj.creator
        }])
        iconObj.moderation_status = 0
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/pending-assets/<content_hash>/deny-group-icon", methods=['POST'])
@csrf.exempt
def DenyPendingGroupIcon( content_hash ):
    AdminPermissionRequired('AssetModeration')

    GroupIconObj : list[GroupIcon] = GroupIcon.query.filter_by(content_hash=content_hash).all()
    if len(GroupIconObj) == 0:
        return redirect("/admin/pending-assets")
    for iconObj in GroupIconObj:
        if iconObj.moderation_status != 1:
            continue
        LogModerationAction(auth.GetCurrentUser(), isApproved=False, relatedAssets=[{
            "mainId": iconObj.group.id,
            "relatedId": None,
            "type": "GroupIcon",
            "view_name": iconObj.group.name,
            "source": f"{config.CDN_URL}/{iconObj.content_hash}",
            "page": f"https://www.syntax.eco/groups/{str(iconObj.group.id)}/",
            "creator": iconObj.creator
        }])
        iconObj.moderation_status = 2
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/pending-assets/<int:assetid>/approve", methods=['POST'])
@csrf.exempt
def ApprovePendingAsset(assetid):
    AdminPermissionRequired('AssetModeration')

    AssetObj : Asset = Asset.query.filter_by(id=int(assetid)).first()
    if AssetObj is None:
        flash("Asset does not exist", "danger")
        return redirect("/admin/pending-assets")
    if AssetObj.moderation_status != 1:
        flash("Asset is not pending", "danger")
        return redirect("/admin/pending-assets")
    if AssetObj.asset_type not in [AssetType.Image, AssetType.Audio, AssetType.Place]:
        flash("Asset type is not supported", "danger")
        return redirect("/admin/pending-assets")
    RelatedAssets = []
    AssetObj.moderation_status = 0
    RelatedAssets.append({
        "mainId": AssetObj.id,
        "relatedId": None,
        "type": "Asset",
        "view_name": AssetObj.name,
        "source": None,
        "page": f"https://www.syntax.eco/catalog/{str(AssetObj.id)}/",
        "creator": GetCreatorOfAsset(AssetObj)
    })
    # Get the AssetThumbnail
    AssetThumbnailObj : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=AssetObj.id).first()
    if AssetThumbnailObj is not None:
        if AssetThumbnailObj.moderation_status == 1:
            AssetThumbnailObj.moderation_status = 0
            RelatedAssets.append({
                "mainId": AssetObj.id,
                "relatedId": None,
                "type": "AssetThumbnail",
                "view_name": AssetObj.name,
                "source": f"{config.CDN_URL}/{AssetThumbnailObj.content_hash}",
                "page": f"https://www.syntax.eco/catalog/{str(AssetObj.id)}/",
                "creator": GetCreatorOfAsset(AssetObj)
            })

    # Get the parent asset
    ParentAssetLink : AssetModerationLink = AssetModerationLink.query.filter_by(ChildAssetId=AssetObj.id).first()
    if ParentAssetLink is not None:
        ParentAsset : Asset = Asset.query.filter_by(id=ParentAssetLink.ParentAssetId).first()
        if ParentAsset is not None:
            if ParentAsset.moderation_status == 1:
                ParentAsset.moderation_status = 0
                RelatedAssets.append({
                    "mainId": ParentAsset.id,
                    "relatedId": AssetObj.id,
                    "type": AssetObj.asset_type.name,
                    "view_name": ParentAsset.name,
                    "source": None,
                    "page": f"https://www.syntax.eco/catalog/{str(ParentAsset.id)}/",
                    "creator": GetCreatorOfAsset(AssetObj)
                })
            # Get the AssetThumbnail
            ParentAssetThumbnail : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=ParentAsset.id).first()
            if ParentAssetThumbnail is not None:
                if ParentAssetThumbnail.moderation_status == 1:
                    ParentAssetThumbnail.moderation_status = 0
                    RelatedAssets.append({
                        "mainId": ParentAsset.id,
                        "relatedId": AssetObj.id,
                        "type": "AssetThumbnail",
                        "view_name": ParentAsset.name,
                        "source": f"{config.CDN_URL}/{ParentAssetThumbnail.content_hash}",
                        "page": f"https://www.syntax.eco/catalog/{str(ParentAsset.id)}/",
                        "creator": GetCreatorOfAsset(AssetObj)
                    })
    LogModerationAction(auth.GetCurrentUser(), isApproved=True, relatedAssets=RelatedAssets)
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/pending-assets/<int:assetid>/decline", methods=['POST'])
@csrf.exempt
def DeclinePendingAsset(assetid):
    AdminPermissionRequired('AssetModeration')

    AssetObj : Asset = Asset.query.filter_by(id=int(assetid)).first()
    if AssetObj is None:
        flash("Asset does not exist", "danger")
        return redirect("/admin/pending-assets")
    if AssetObj.moderation_status != 1:
        flash("Asset is not pending", "danger")
        return redirect("/admin/pending-assets")
    if AssetObj.asset_type not in [AssetType.Image, AssetType.Audio, AssetType.Place]:
        flash("Asset type is not supported", "danger")
        return redirect("/admin/pending-assets")
    RelatedAssets = []
    AssetObj.moderation_status = 2
    RelatedAssets.append({
        "mainId": AssetObj.id,
        "relatedId": None,
        "type": "Asset",
        "view_name": AssetObj.name,
        "source": None,
        "page": f"https://www.syntax.eco/catalog/{str(AssetObj.id)}/",
        "creator": GetCreatorOfAsset(AssetObj)
    })
    # Get the AssetThumbnail
    AssetThumbnailObj : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=AssetObj.id).first()
    if AssetThumbnailObj is not None:
        if AssetThumbnailObj.moderation_status == 1:
            AssetThumbnailObj.moderation_status = 2
            RelatedAssets.append({
                "mainId": AssetObj.id,
                "relatedId": None,
                "type": "AssetThumbnail",
                "view_name": AssetObj.name,
                "source": f"{config.CDN_URL}/{AssetThumbnailObj.content_hash}",
                "page": f"https://www.syntax.eco/catalog/{str(AssetObj.id)}/",
                "creator": GetCreatorOfAsset(AssetObj)
            })

    # Get the parent asset
    ParentAssetLink : AssetModerationLink = AssetModerationLink.query.filter_by(ChildAssetId=AssetObj.id).first()
    if ParentAssetLink is not None:
        ParentAsset : Asset = Asset.query.filter_by(id=ParentAssetLink.ParentAssetId).first()
        if ParentAsset is not None:
            if ParentAsset.moderation_status == 1:
                ParentAsset.moderation_status = 2
                RelatedAssets.append({
                    "mainId": ParentAsset.id,
                    "relatedId": AssetObj.id,
                    "type": AssetObj.asset_type.name,
                    "view_name": ParentAsset.name,
                    "source": None,
                    "page": f"https://www.syntax.eco/catalog/{str(ParentAsset.id)}/",
                    "creator": GetCreatorOfAsset(AssetObj)
                })
            # Get the AssetThumbnail
            ParentAssetThumbnail : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=ParentAsset.id).first()
            if ParentAssetThumbnail is not None:
                ParentAssetThumbnail.moderation_status = 2
                RelatedAssets.append({
                    "mainId": ParentAsset.id,
                    "relatedId": AssetObj.id,
                    "type": "AssetThumbnail",
                    "view_name": ParentAsset.name,
                    "source": f"{config.CDN_URL}/{ParentAssetThumbnail.content_hash}",
                    "page": f"https://www.syntax.eco/catalog/{str(ParentAsset.id)}/",
                    "creator": GetCreatorOfAsset(AssetObj)
                })
    LogModerationAction(auth.GetCurrentUser(), isApproved=False, relatedAssets=RelatedAssets)
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/pending-assets/<int:assetid>/approve-icon", methods=['POST'])
@csrf.exempt
def ApprovePendingIcon(assetid):
    AdminPermissionRequired('AssetModeration')

    PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=int(assetid)).first()
    if PlaceIconObj is None:
        flash("Icon does not exist", "danger")
        return redirect("/admin/pending-assets")
    if PlaceIconObj.moderation_status != 1:
        flash("Icon is not pending", "danger")
        return redirect("/admin/pending-assets")
    PlaceAssetObj : Asset = Asset.query.filter_by(id=PlaceIconObj.placeid).first()
    if PlaceAssetObj is None:
        flash("Icon does not exist", "danger")
        return redirect("/admin/pending-assets")
    if PlaceAssetObj.moderation_status == 1:
        PlaceAssetObj.moderation_status = 0
    PlaceIconObj.moderation_status = 0
    LogModerationAction(auth.GetCurrentUser(), isApproved=True, relatedAssets=[{
        "mainId": PlaceAssetObj.id,
        "relatedId": None,
        "type": "PlaceIcon",
        "view_name": PlaceAssetObj.name,
        "source": f"{config.CDN_URL}/{PlaceIconObj.contenthash}",
        "page": f"https://www.syntax.eco/games/{str(PlaceAssetObj.id)}/",
        "creator": GetCreatorOfAsset(PlaceAssetObj)
    }])
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/pending-assets/<int:assetid>/decline-icon", methods=['POST'])
@csrf.exempt
def DeclinePendingIcon(assetid):
    AdminPermissionRequired('AssetModeration')

    PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=int(assetid)).first()
    if PlaceIconObj is None:
        flash("Icon does not exist", "danger")
        return redirect("/admin/pending-assets")
    if PlaceIconObj.moderation_status != 1:
        flash("Icon is not pending", "danger")
        return redirect("/admin/pending-assets")
    PlaceIconObj.moderation_status = 2
    LogModerationAction(auth.GetCurrentUser(), isApproved=False, relatedAssets=[{
        "mainId": PlaceIconObj.placeid,
        "relatedId": None,
        "type": "PlaceIcon",
        "view_name": PlaceIconObj.asset.name,
        "source": f"{config.CDN_URL}/{PlaceIconObj.contenthash}",
        "page": f"https://www.syntax.eco/games/{str(PlaceIconObj.placeid)}/",
        "creator": GetCreatorOfAsset(PlaceIconObj.asset)
    }])
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/pending-assets/<int:thumbnailid>/approve-thumbnail", methods=['POST'])
@csrf.exempt
def ApprovePendingThumbnail(thumbnailid : int):
    AdminPermissionRequired('AssetModeration')

    AssetThumbnailObj : AssetThumbnail = AssetThumbnail.query.filter_by(id=int(thumbnailid)).first()
    if AssetThumbnailObj is None:
        flash("Thumbnail does not exist", "danger")
        return redirect("/admin/pending-assets")
    if AssetThumbnailObj.moderation_status != 1:
        flash("Thumbnail is not pending", "danger")
        return redirect("/admin/pending-assets")
    AssetThumbnailObj.moderation_status = 0
    LogModerationAction(auth.GetCurrentUser(), isApproved=True, relatedAssets=[{
        "mainId": AssetThumbnailObj.asset_id,
        "relatedId": None,
        "type": "AssetThumbnail",
        "view_name": AssetThumbnailObj.asset.name,
        "source": f"{config.CDN_URL}/{AssetThumbnailObj.content_hash}",
        "page": f"https://www.syntax.eco/catalog/{str(AssetThumbnailObj.asset_id)}/",
        "creator": GetCreatorOfAsset(AssetThumbnailObj.asset)
    }])
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/pending-assets/<int:thumbnailid>/decline-thumbnail", methods=['POST'])
@csrf.exempt
def DeclinePendingThumbnail(thumbnailid : int):
    AdminPermissionRequired('AssetModeration')

    AssetThumbnailObj : AssetThumbnail = AssetThumbnail.query.filter_by(id=int(thumbnailid)).first()
    if AssetThumbnailObj is None:
        flash("Thumbnail does not exist", "danger")
        return redirect("/admin/pending-assets")
    if AssetThumbnailObj.moderation_status != 1:
        flash("Thumbnail is not pending", "danger")
        return redirect("/admin/pending-assets")
    AssetThumbnailObj.moderation_status = 2
    LogModerationAction(auth.GetCurrentUser(), isApproved=False, relatedAssets=[{
        "mainId": AssetThumbnailObj.asset_id,
        "relatedId": None,
        "type": "AssetThumbnail",
        "view_name": AssetThumbnailObj.asset.name,
        "source": f"{config.CDN_URL}/{AssetThumbnailObj.content_hash}",
        "page": f"https://www.syntax.eco/catalog/{str(AssetThumbnailObj.asset_id)}/",
        "creator": GetCreatorOfAsset(AssetThumbnailObj.asset)
    }])
    db.session.commit()
    return redirect("/admin/pending-assets")

@AdminRoute.route("/manage-users", methods=['GET'])
def ManageUsers():
    AdminPermissionRequired('ManageUsers')
    
    query = request.args.get(key = "query", default = None, type = str)
    page = request.args.get(key = "page", default = 1, type = int)
    searchType = request.args.get(key = "searchType", default = "userid", type = str) # userid, username
    orderBy = request.args.get(key = "orderBy", default = "userid", type = str) # userid, creation, lastonline, robux, tix
    orderType = request.args.get(key = "orderType", default = "asc", type = str) # asc, desc

    if searchType not in ["userid", "username", "discordid"]:
        searchType = "userid"
    if orderBy not in ["userid", "creation", "lastonline", "robux", "tix"]:
        orderBy = "userid"
    if orderType not in ["asc", "desc"]:
        orderType = "desc"
    
    if type(query) is not str:
        query = None


    def CreateUserInfo( userObj : User ):
        userEconomyObj : UserEconomy = UserEconomy.query.filter_by(userid=userObj.id).first()
        if userEconomyObj is None:
            userEconomyObj = UserEconomy(userid=userObj.id)
            db.session.add(userEconomyObj)
            db.session.commit()
        return {
            "id": userObj.id,
            "username": userObj.username,
            "creation": userObj.created,
            "lastonline": userObj.lastonline,
            "robux": userEconomyObj.robux,
            "tix": userEconomyObj.tix,
            "accountstatus": userObj.accountstatus
        }

    returnList = []

    if query is not None:
        if searchType == "userid":
            userObject : list[User] = [User.query.filter_by(id=int(query)).first()]
        elif searchType == "username":
            userObject : list[User] = User.query.filter(User.username.ilike(f"%{query}%")).offset((page-1)*15).limit(15).all()
        elif searchType == "discordid":
            LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(discord_id=int(query)).first()
            if LinkedDiscordObj is not None:
                userObject = [User.query.filter_by(id=LinkedDiscordObj.user_id).first()]
            else:
                userObject = []
        
        for userObj in userObject:
            if userObj is None:
                continue
            if len(returnList) >= 15:
                break
            returnList.append(CreateUserInfo(userObj))
    else:
        UserQuery = None
        if orderBy == "userid":
            UserQuery = User.id
        elif orderBy == "creation":
            UserQuery = User.created
        elif orderBy == "lastonline":
            UserQuery = User.lastonline
        elif orderBy == "robux":
            UserQuery = UserEconomy.robux
        elif orderBy == "tix":
            UserQuery = UserEconomy.tix
        
        if orderType == "asc":
            UserQuery = UserQuery.asc()
        elif orderType == "desc":
            UserQuery = UserQuery.desc()
        
        # If we are ordering by robux or tix, we need to join the UserEconomy table and only select the userEconomy column for that user by selecting its id
        if orderBy in ["robux", "tix"]:
            UserQuery = User.query.join(UserEconomy, User.id == UserEconomy.userid).order_by(UserQuery)
        else:
            UserQuery = User.query.order_by(UserQuery)
        
        UserQuery = UserQuery.paginate(page=page, per_page=15, error_out=False)
        for userObj in UserQuery.items:
            returnList.append(CreateUserInfo(userObj))
    
    isThereNextPage = False
    if len(returnList) == 15:
        isThereNextPage = True

    return render_template("admin/usermanage/search.html", 
                            query=query, 
                            searchType=searchType, 
                            orderBy=orderBy, 
                            orderType=orderType, 
                            returnList=returnList,
                            isThereNextPage=isThereNextPage,
                            page=page
                           )

@AdminRoute.route("/manage-users", methods=['POST'])
def ManageUserQuery():
    AdminPermissionRequired('ManageUsers')

    query = request.form.get(key = "user-search-input", default=None, type=str)
    searchType = request.form.get(key = "user-search-type", default = "userid", type = str) # userid, username
    orderBy = request.form.get(key = "user-order-by", default = "userid", type = str) # userid, creation, lastonline, robux, tix
    orderType = request.form.get(key = "user-order-direction", default = "asc", type = str) # asc, desc

    if searchType not in ["userid", "username", "discordid"]:
        searchType = "userid"
    if orderBy not in ["userid", "creation", "lastonline", "robux", "tix"]:
        orderBy = "userid"
    if orderType not in ["asc", "desc"]:
        orderType = "desc"
    
    if searchType == "userid" and query != "":
        try:
            query = int(query)
        except:
            searchType = "username"
    if query == "":
        query = None
    
    if query is None:
        return redirect(f"/admin/manage-users?searchType={searchType}&orderBy={orderBy}&orderType={orderType}")
    else:
        return redirect(f"/admin/manage-users?query={query}&searchType={searchType}&orderBy={orderBy}&orderType={orderType}")

@AdminRoute.route("/manage-users/<int:userid>", methods=['GET'])
def ManageUser(userid : int):
    AdminPermissionRequired('ManageUsers')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    isAdministrator = AdminPermissions.query.filter_by(userid=userid).first() is not None
    TotalVisits = 0
    UniverseList : list[Universe] = Universe.query.filter_by( creator_id = userObj.id, creator_type = 0 ).all()
    for UniverseObj in UniverseList:
        TotalVisits += UniverseObj.visit_count
    UserEconomyObj : UserEconomy = UserEconomy.query.filter_by(userid=userObj.id).first()
    if UserEconomyObj is None:
        UserEconomyObj = UserEconomy(userid=userObj.id)
        db.session.add(UserEconomyObj)
        db.session.commit()
    DescriptionLines = userObj.description.split("\n")
    if HasAdminPermission('ViewLoginHistoryDetailed'):
        LastLogin : LoginRecord = LoginRecord.query.filter_by(userid=userObj.id).order_by(LoginRecord.timestamp.desc()).first()
    else:
        LastLogin = None
    
    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(user_id=userObj.id).first()
    if LinkedDiscordObj is not None:
        DiscordUserInfo : discord.DiscordUserInfo = discord.DiscordUserInfo(
            UserId = LinkedDiscordObj.discord_id,
            Username = LinkedDiscordObj.discord_username,
            Discriminator = LinkedDiscordObj.discord_discriminator,
            AvatarHash = LinkedDiscordObj.discord_avatar,
        )
    else:
        DiscordUserInfo = None

    InviteKeyUsed : InviteKey = InviteKey.query.filter_by(used_by=userObj.id).first()
    LastestUserBanObj : UserBan = UserBan.query.filter_by(userid=userObj.id, acknowledged = False).order_by(UserBan.id.desc()).first()
    
    return render_template(
        "admin/usermanage/view.html", 
        userObj=userObj, 
        isAdministrator=isAdministrator,
        TotalVisits=TotalVisits,
        UserEconomyObj=UserEconomyObj,
        DescriptionLines=DescriptionLines,
        LastLogin=LastLogin,
        LinkedDiscordObj=LinkedDiscordObj,
        DiscordUserInfo=DiscordUserInfo,
        LastestUserBanObj=LastestUserBanObj,
        InviteKeyUsed=InviteKeyUsed,
        HasAdminPermission=HasAdminPermission
    )

@AdminRoute.route("/manage-users/<int:userid>/manage-admin-permissions", methods=["GET"])
def ManageUserAdminPermissions( userid : int ):
    AdminPermissionRequired('ManageAdminPermissions')
    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)

    return render_template(
        "admin/usermanage/manage-admin-perms.html",
        userObj = userObj
    )

@AdminRoute.route("/manage-users/<int:userid>/manage-admin-permissions/api/fetch-permissions", methods=["GET"])
def ManageUserAdminPermissionsFetchPermissions( userid : int ):
    AdminPermissionRequired('ManageAdminPermissions')
    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)

    PermissionsData : list[dict] = []

    for permission in PermissionsDefinition:
        permissionData = PermissionsDefinition[permission]
        PermissionsData.append({
            "internal_name": permission,
            "friendly_name": permissionData["Name"],
            "description": permissionData["Description"],
            "is_hidden": permissionData["Hidden"] if "Hidden" in permissionData else False,
            "hasPermission": AdminPermissions.query.filter_by(userid=userObj.id, permission=permission).first() is not None,
            "bi_icon": permissionData["icon"] if "icon" in permissionData else None
        })
    
    data_response = make_response(json.dumps(PermissionsData))
    data_response.headers['Content-Type'] = 'application/json'
    data_response.headers['Cache-Control'] = 'no-cache'
    return data_response

@AdminRoute.route("/manage-users/<int:userid>/manage-admin-permissions/api/set-permissions", methods=["POST"])
@limiter.limit("30/minute")
def ManageUserAdminPermissionsSetPermission( userid : int ):
    AdminPermissionRequired('ManageAdminPermissions')
    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    
    UpdatedPermissionData = request.json
    if "permissions" not in UpdatedPermissionData:
        return jsonify({
            "success": False,
            "reason": f"Bad Data"
        }), 200
    if "2fa_code" not in UpdatedPermissionData:
        return jsonify({
            "success": False,
            "reason": f"Bad Data"
        }), 200
    
    if not auth.Validate2FACode( AuthenticatedUser.id, str( UpdatedPermissionData["2fa_code"] ) ):
        return jsonify({
            "success": False,
            "reason": f"Invalid 2FA Code"
        }), 200

    for permission in UpdatedPermissionData["permissions"]:
        if permission not in PermissionsDefinition:
            return jsonify({
                "success": False,
                "reason": f"Unknown permission {permission}"
            }), 200
    
    AdminPermissions.query.filter_by(userid=userObj.id).delete()
    db.session.commit()

    for permission in UpdatedPermissionData["permissions"]:
        db.session.add(AdminPermissions(userid=userObj.id, permission=permission))
    db.session.commit()

    return jsonify({
        "success": True,
        "reason": ""
    }), 200

@AdminRoute.route("/manage-users/<int:userid>/ban-history", methods=['GET'])
def ManageUserBanHistory( userid : int ):
    AdminPermissionRequired('ManageUsers')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    UserBanHistory : list[UserBan] = UserBan.query.filter_by(userid=userObj.id).order_by(UserBan.id.desc()).paginate(page=1, per_page=10, error_out=False)
    def GetBanAuthorName( banObj : UserBan ):
        Author : User = User.query.filter_by(id=banObj.author_userid).first()
        if Author is None:
            return "Unknown"
        return Author.username
    return render_template(
        "admin/usermanage/banhistory.html",
        userObj = userObj,
        BanHistory = UserBanHistory,
        GetBanAuthorName = GetBanAuthorName
    )

@AdminRoute.route("/manage-users/<int:userid>/invite-keys", methods=['GET'])
def ManageUserInviteKeysview(userid : int):
    AdminPermissionRequired('ManageUsers')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    PageNumber = request.args.get( key = "page", default = 1, type = int )
    if PageNumber < 1:
        PageNumber = 1

    UserInviteKeys = InviteKey.query.filter_by(created_by = userObj.id).order_by(InviteKey.created_at.desc()).paginate( page = PageNumber, per_page = 15, error_out = False )
    return render_template(
        "admin/usermanage/invitekeys.html",
        userObj = userObj,
        InviteKeys = UserInviteKeys
    )

def LogUserBanAction( BannedUser : User, Actor : User, BanObject : UserBan ):
    BanEmbed = {
        "type": "rich",
        "title": f"{BannedUser.username} ({BannedUser.id}) Banned",
        "description": "",
        "color": 0xef0000,
        "fields": [
            {
                "name": "Ban Author",
                "value": f"[{Actor.username}]({config.BaseURL}/admin/manage-users/{Actor.id}) ({Actor.id})",
                "inline": False
            },
            {
                "name": "Banned User",
                "value": f"[{BannedUser.username}]({config.BaseURL}/admin/manage-users/{BannedUser.id}) ({BannedUser.id})",
                "inline": False
            },
            {
                "name": "Ban Type",
                "value": f"{BanObject.ban_type.name}",
                "inline": False
            },
            {
                "name": "Ban Reason",
                "value": f"{BanObject.reason}",
                "inline": False
            },
            {
                "name": "Internal Reason",
                "value": f"{BanObject.moderator_note}",
                "inline": False
            },
            {
                "name": "Expiration",
                "value": f"{BanObject.expires_at}",
                "inline": False
            }
        ],
        "author": {
            "name": BannedUser.username,
            "icon_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(BannedUser.id)}"
        },
        "footer": {
            "text": "Syntax Asset Moderation Log"
        },
        "timestamp": datetime.utcnow().isoformat()
    }
    def thread_func():
        try:
            requests.post(
                url = config.DISCORD_ADMIN_LOGS_WEBHOOK,
                json = {
                    "username": "Syntax Moderation Log",
                    "embeds": [BanEmbed],
                    "avatar_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(BannedUser.id)}"
                }
            )
        except Exception as e:
            logging.warn(f"Admin > LogUserBanAction: Exception raised when sending webhook - {str(e)}")
    
    threading.Thread(target=thread_func).start()

def LogUserUnbanAction( TargetUser : User, Actor : User, BanObj : UserBan ):
    Author : User = User.query.filter_by( id = BanObj.author_userid ).first()
    BanEmbed = {
        "type": "rich",
        "title": f"{TargetUser.username} ({TargetUser.id}) Unbanned",
        "description": "",
        "color": 0xfcdb03,
        "fields": [
            {
                "name": "Ban Author",
                "value": f"[{Author.username}]({config.BaseURL}/admin/manage-users/{Author.id}) ({Author.id})",
                "inline": False
            },
            {
                "name": "Unbanned By",
                "value": f"[{Actor.username}]({config.BaseURL}/admin/manage-users/{Actor.id}) ({Actor.id})",
                "inline": False
            },
            {
                "name": "Banned User",
                "value": f"[{TargetUser.username}]({config.BaseURL}/admin/manage-users/{TargetUser.id}) ({TargetUser.id})",
                "inline": False
            },
            {
                "name": "Ban Type",
                "value": f"{BanObj.ban_type.name}",
                "inline": False
            },
            {
                "name": "Ban Reason",
                "value": f"{BanObj.reason}",
                "inline": False
            },
            {
                "name": "Internal Reason",
                "value": f"{BanObj.moderator_note}",
                "inline": False
            },
            {
                "name": "Expiration",
                "value": f"{BanObj.expires_at}",
                "inline": False
            }
        ],
        "author": {
            "name": TargetUser.username,
            "icon_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(TargetUser.id)}"
        },
        "footer": {
            "text": "Syntax Asset Moderation Log"
        },
        "timestamp": datetime.utcnow().isoformat()
    }

    def thread_func():
        try:
            requests.post(
                url = config.DISCORD_ADMIN_LOGS_WEBHOOK,
                json = {
                    "username": "Syntax Moderation Log",
                    "embeds": [BanEmbed],
                    "avatar_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(TargetUser.id)}"
                }
            )
        except Exception as e:
            logging.warn(f"Admin > LogUserUnbanAction: Exception raised when sending webhook - {str(e)}")
    
    threading.Thread(target=thread_func).start()

@AdminRoute.route("/manage-users/<int:userid>/ban-user", methods=['GET'])
def BanUser(userid : int):
    AdminPermissionRequired('ManageUsers')
    AdminPermissionRequired('BanUser')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    isAdministrator = AdminPermissions.query.filter_by(userid=userid).first() is not None # Check if they have at least one admin permission
    if isAdministrator:
        flash("You cannot ban an administrator", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}")
    
    LastestUserBanObj : UserBan = UserBan.query.filter_by(userid=userObj.id, acknowledged = False).order_by(UserBan.id.desc()).first()

    return render_template("admin/usermanage/ban.html", userObj=userObj, LastestUserBanObj=LastestUserBanObj)

@AdminRoute.route("/manage-users/<int:userid>/ban-user", methods=['POST'])
def BanUserPost(userid : int):
    AdminPermissionRequired('ManageUsers')
    AdminPermissionRequired('BanUser')
    AuthenticatedUser : User = auth.GetCurrentUser()
    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    isAdministrator = AdminPermissions.query.filter_by(userid=userid).first() is not None # Check if they have at least one admin permission
    if isAdministrator:
        flash("You cannot ban an administrator", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    
    LastestUserBanObj : UserBan = UserBan.query.filter_by(userid=userObj.id, acknowledged = False).order_by(UserBan.id.desc()).first()
    if LastestUserBanObj is not None:
        flash("User is already banned", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    BanTypeInput : int = request.form.get( key='ban_type', default=None, type=int )
    BanReason = request.form.get( key='ban_reason', default=None, type=str )
    ModeratorNote : str = request.form.get( key='ban_notes', default=None, type=str )
    TOTPCode : str = request.form.get( key='totp_code', default=None, type=str )

    if BanTypeInput is None or BanTypeInput not in [0,1,2,3,4,5,6] or BanReason is None or ModeratorNote is None or TOTPCode is None:
        flash("Invalid request", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    isValidTOTPCode = auth.Validate2FACode(AuthenticatedUser.id, TOTPCode)
    if not isValidTOTPCode:
        flash("Invalid 2FA code", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    BanTypeInput : BanType = BanType(BanTypeInput)
    if len(BanReason) > 512:
        flash("Ban reason is too long", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    if len(ModeratorNote) > 512:
        flash("Moderator note is too long", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    if len(BanReason) < 10:
        flash("Ban reason is too short", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    if len(ModeratorNote) < 10:
        flash("Moderator note is too short", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")

    if redis_controller.exists(f"admin_ban_cooldown:{AuthenticatedUser.id}"):
        flash("You are banning users too fast!", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")

    BanTypeToTimeLength = {
        BanType.Warning : timedelta(days=0),
        BanType.Day1Ban : timedelta(days=1),
        BanType.Day3Ban : timedelta(days=3),
        BanType.Day7Ban : timedelta(days=7),
        BanType.Day14Ban : timedelta(days=14),
        BanType.Day30Ban : timedelta(days=30)
    }
    ExpirationDate = None
    if BanTypeInput in BanTypeToTimeLength:
        ExpirationDate = datetime.utcnow() + BanTypeToTimeLength[BanTypeInput]

    BanObj : UserBan = UserBan(
        userid = userObj.id,
        author_userid = AuthenticatedUser.id,
        ban_type = BanTypeInput,
        reason = BanReason,
        moderator_note = ModeratorNote,
        expires_at = ExpirationDate
    )
    db.session.add(BanObj)
    if BanTypeInput == BanType.Deleted:
        userObj.accountstatus = 3
    else:
        userObj.accountstatus = 2
    db.session.commit()
    LogUserBanAction( userObj, AuthenticatedUser, BanObj )
    redis_controller.set(f"admin_ban_cooldown:{AuthenticatedUser.id}", "1", ex = 15)
    flash("User banned", "success")

    PlaceserverPlayerObj : PlaceServerPlayer = PlaceServerPlayer.query.filter_by( userid = userObj.id ).first()
    if PlaceserverPlayerObj is not None:
        CurrentPlaceServerObj : PlaceServer = PlaceServer.query.filter_by( serveruuid = PlaceserverPlayerObj.serveruuid).first()
        EvictPlayer(CurrentPlaceServerObj, userObj.id)

    return redirect(f"/admin/manage-users/{str(userid)}")

@AdminRoute.route("/manage-users/<int:userid>/ban-user/revoke-ban", methods=["POST"])
def UnbanUserPost( userid : int):
    AdminPermissionRequired('ManageUsers')
    AdminPermissionRequired('BanUser')
    AuthenticatedUser : User = auth.GetCurrentUser()
    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    
    banid = request.args.get( key = "banid", default = None, type = int )
    if banid is None:
        flash("Invalid BanID", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")

    if userObj.accountstatus == 1:
        flash("User does not have an active ban", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    if userObj.accountstatus == 4:
        flash("User is forgotten, cannot revoke any bans", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")

    TargetBanObj : UserBan = UserBan.query.filter_by( id = banid, userid = userid ).first()
    if TargetBanObj is None:
        flash("Invalid BanID", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")
    
    if TargetBanObj.acknowledged:
        flash("Ban has already been acknowledged by user", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")

    if redis_controller.exists(f"admin_unban_user_cooldown:{AuthenticatedUser.id}"):
        flash("You are unbanning users too quickly!", "danger")
        return redirect(f"/admin/manage-users/{str(userid)}/ban-user")

    LogUserUnbanAction( userObj, AuthenticatedUser, TargetBanObj )

    db.session.delete(TargetBanObj)
    userObj.accountstatus = 1
    db.session.commit()
    redis_controller.set(f"admin_unban_user_cooldown:{AuthenticatedUser.id}", "1", ex=30)

    return redirect(f"/admin/manage-users/{str(userid)}/ban-user")

@AdminRoute.route("/manage-users/<int:userid>/login-history", methods=['GET'])
def ViewUserLoginHistory( userid : int ):
    AdminPermissionRequired('ManageUsers')
    AdminPermissionRequired('ViewUserLoginHistory')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    PageNumber = request.args.get(key = "page", default = 1, type = int)
    if PageNumber < 1:
        PageNumber = 1
    LoginHistory : list[LoginRecord] = LoginRecord.query.filter_by(userid=userObj.id).order_by(LoginRecord.timestamp.desc()).paginate(page=PageNumber, per_page=15, error_out=False)
    
    AllUniqueLoginRecords : list[LoginRecord] = LoginRecord.query.filter_by( userid = userObj.id ).order_by(LoginRecord.ip, LoginRecord.session_token).distinct(LoginRecord.ip, LoginRecord.session_token).all()
    AlreadySearchedIPs : list[str] = []
    AlreadySearchedSessionTokens : list[str] = []
    AlternateAccounts : list[User] = []

    for LoginRecordObj in AllUniqueLoginRecords:
        if LoginRecordObj.ip in AlreadySearchedIPs and LoginRecordObj.session_token in AlreadySearchedSessionTokens:
            continue
        
        AlreadySearchedIPs.append(LoginRecordObj.ip)
        AlreadySearchedSessionTokens.append(LoginRecordObj.session_token)

        MatchingLoginRecords : list[LoginRecord] = LoginRecord.query.filter(
            and_(
                or_(
                    LoginRecord.ip == LoginRecordObj.ip,
                    LoginRecord.session_token == LoginRecordObj.session_token
                ),
                LoginRecord.userid != userObj.id
            )
        ).distinct(LoginRecord.userid).all()

        for MatchingLoginRecord in MatchingLoginRecords:
            MatchingUserObj : User = User.query.filter_by(id=MatchingLoginRecord.userid).first()
            if MatchingUserObj is not None and MatchingUserObj not in AlternateAccounts and MatchingLoginRecord.session_token is not None:
                MatchingUserObj.flags = {
                    "ipmatch" : MatchingLoginRecord.ip == LoginRecordObj.ip,
                    "sessiontokenmatch" : MatchingLoginRecord.session_token == LoginRecordObj.session_token,
                    "useragentmatch" : MatchingLoginRecord.useragent == LoginRecordObj.useragent,
                    "hwidmatch" : False
                }
                AlternateAccounts.append(MatchingUserObj)
            elif MatchingUserObj is not None and MatchingUserObj in AlternateAccounts and MatchingLoginRecord.session_token is not None:
                MatchingUserIndex = AlternateAccounts.index(MatchingUserObj)
                AlternateAccounts[MatchingUserIndex].flags = {
                    "ipmatch" : MatchingLoginRecord.ip == LoginRecordObj.ip or AlternateAccounts[MatchingUserIndex].flags["ipmatch"],
                    "sessiontokenmatch" : MatchingLoginRecord.session_token == LoginRecordObj.session_token or AlternateAccounts[MatchingUserIndex].flags["sessiontokenmatch"],
                    "useragentmatch" : MatchingLoginRecord.useragent == LoginRecordObj.useragent or AlternateAccounts[MatchingUserIndex].flags["useragentmatch"],
                    "hwidmatch" : False
                }
    
    AllUniqueHWIDLogs : list[UserHWIDLog] = UserHWIDLog.query.filter_by( user_id = userObj.id ).order_by(UserHWIDLog.hwid).distinct(UserHWIDLog.hwid).all()
    for HWIDLog in AllUniqueHWIDLogs:
        MatchingHWIDLogs : list[UserHWIDLog] = UserHWIDLog.query.filter(
            and_(
                UserHWIDLog.hwid == HWIDLog.hwid,
                UserHWIDLog.user_id != userObj.id
            )
        ).distinct(UserHWIDLog.user_id).all()
        for MatchingHWIDLog in MatchingHWIDLogs:
            MatchingUserObj : User = User.query.filter_by(id=MatchingHWIDLog.user_id).first()
            if MatchingUserObj is not None and MatchingUserObj not in AlternateAccounts:
                MatchingUserObj.flags = {
                    "ipmatch" : False,
                    "sessiontokenmatch" : False,
                    "useragentmatch" : False,
                    "hwidmatch" : True
                }
                AlternateAccounts.append(MatchingUserObj)
            elif MatchingUserObj is not None and MatchingUserObj in AlternateAccounts:
                MatchingUserIndex = AlternateAccounts.index(MatchingUserObj)
                AlternateAccounts[MatchingUserIndex].flags["hwidmatch"] = True

    canViewSensitiveInfo = HasAdminPermission('ViewLoginHistoryDetailed')

    return render_template("admin/usermanage/loginhistory.html", userObj=userObj, LoginHistory=LoginHistory, AlternateAccounts=AlternateAccounts, canViewSensitiveInfo=canViewSensitiveInfo)

@AdminRoute.route("/manage-users/<int:userid>/game-sessions", methods=['GET'])
def ViewUserGameSessions( userid : int ):
    AdminPermissionRequired('ManageUsers')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    PageNumber = request.args.get(key = "page", default = 1, type = int)
    if PageNumber < 1:
        PageNumber = 1
    SessionsLogs : list[GameSessionLog] = GameSessionLog.query.filter_by( user_id = userObj.id ).order_by(GameSessionLog.joined_at.desc()).paginate(page=PageNumber, per_page=15, error_out=False)

    def get_place_name( place_id : int ):
        PlaceAssetObj : Asset = Asset.query.filter_by( id = place_id ).first()
        if PlaceAssetObj is None:
            return "Unknown Place"
        return PlaceAssetObj.name

    return render_template("admin/usermanage/gamesessions.html", userObj=userObj, GameSessions=SessionsLogs, get_place_name=get_place_name)

CategoryToEnum = {
    "purchase": TransactionType.Purchase,
    "sale": TransactionType.Sale,
    "group-payout": TransactionType.GroupPayout,
    "stipends": TransactionType.BuildersClubStipend,
}

@AdminRoute.route("/manage-users/<int:userid>/transactions", methods=['GET'])
def ViewUserTransactions( userid : int ):
    AdminPermissionRequired('ManageUsers')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    
    CategoryArg = request.args.get('category', default="purchase", type=str)
    if CategoryArg not in CategoryToEnum:
        Category : TransactionType = TransactionType.Purchase
    else:
        Category : TransactionType = CategoryToEnum[CategoryArg]

    PageNumber = request.args.get('page', default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1

    TransactionQuery = UserTransaction.query.filter_by( transaction_type = Category)
    CategoryQueryDict = {
        TransactionType.Purchase: lambda queryObj: queryObj.filter_by(
            sender_id = userObj.id,
            sender_type = 0
        ),
        TransactionType.Sale: lambda queryObj: queryObj.filter_by(
            reciever_id = userObj.id,
            reciever_type = 0
        ),
        TransactionType.GroupPayout: lambda queryObj: queryObj.filter_by(
            reciever_id = userObj.id,
            reciever_type = 0
        ),
        TransactionType.BuildersClubStipend: lambda queryObj: queryObj.filter_by(
            reciever_id = userObj.id,
            reciever_type = 0
        ),
    }
    TransactionQuery = CategoryQueryDict[Category](TransactionQuery)
    TransactionQuery = TransactionQuery.order_by(UserTransaction.created_at.desc())
    TransactionQuery = TransactionQuery.paginate( page=PageNumber, per_page=15, error_out=False )

    FormattedTransactions = []
    for Transaction in TransactionQuery.items:
        Transaction : UserTransaction = Transaction
        TransactionInfo = {}
        #TransactionInfo["source"] = {
        #    "id": Transaction.sender_id if Transaction.sender_id != userObj.id else Transaction.reciever_id,
        #    "type": Transaction.sender_type if Transaction.sender_id != userObj.id else Transaction.reciever_type, # VV I know this is bad but im too lazy to think of another way to do it
        #    "name": ( User.query.filter_by(id = Transaction.sender_id).first().username if Transaction.sender_type != 1 else Group.query.filter_by( id = Transaction.sender_id ) ) if Transaction.sender_id != userObj.id else ( User.query.filter_by(id = Transaction.reciever_id).first().username if Transaction.reciever_type != 1 else Group.query.filter_by( id = Transaction.reciever_id ) ),
        #}
        TransactionInfo["source"] = {
            "id": Transaction.sender_id if Transaction.sender_id != userObj.id or Transaction.sender_type != 0 else Transaction.reciever_id,
            "type": Transaction.sender_type if Transaction.sender_id != userObj.id or Transaction.sender_type != 0 else Transaction.reciever_type, # VV I know this is bad but im too lazy to think of another way to do it
            "name": ( User.query.filter_by(id = Transaction.sender_id).first().username if Transaction.sender_type != 1 else Group.query.filter_by( id = Transaction.sender_id ).first().name ) if Transaction.sender_id != userObj.id or Transaction.sender_type != 0 else ( User.query.filter_by(id = Transaction.reciever_id).first().username if Transaction.reciever_type != 1 else Group.query.filter_by( id = Transaction.reciever_id ).first().name ),
        }
        TransactionInfo["currency_amount"] = Transaction.currency_amount
        TransactionInfo["currency_type"] = Transaction.currency_type
        TransactionInfo["created_at"] = Transaction.created_at.strftime("%d/%m/%Y %H:%M:%S UTC")
        TransactionInfo["custom_text"] = Transaction.custom_text
        if Transaction.assetId:
            TransactionInfo["asset"] = {
                "id": Transaction.assetId,
                "name": Asset.query.filter_by(id = Transaction.assetId).first().name,
            }
        else:
            TransactionInfo["asset"] = None
        FormattedTransactions.append(TransactionInfo)

    return render_template(
        "admin/usermanage/transactions.html",
        userObj = userObj,
        PageCategory = CategoryArg,
        TransactionInfo = FormattedTransactions,
        Pagination = TransactionQuery
    )

@AdminRoute.route("/manage-users/<int:userid>/moderator-notes", methods=['GET'])
def ViewUserModeratorNotes( userid : int ):
    AdminPermissionRequired('ManageUsers')

    userObj : User = User.query.filter_by(id=userid).first()
    if userObj is None:
        return abort(404)
    
    PageNumber = request.args.get('page', default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1
    UserModeratorNotes : list[ModeratorNote] = ModeratorNote.query.filter_by( user_id = userObj.id ).order_by(ModeratorNote.created_at.desc()).paginate(page=PageNumber, per_page=15, error_out=False)

    def GetUserName( TargetUserId : int ) -> str:
        return User.query.filter_by( id = TargetUserId ).first().username

    return render_template(
        "admin/usermanage/moderatornotes.html",
        userObj = userObj,
        UserModeratorNotes = UserModeratorNotes,
        GetUserName = GetUserName
    )

from app.pages.admin.websitefeaturesdefinition import WebsiteFeaturesDefinition
from app.util.websiteFeatures import GetWebsiteFeature, SetWebsiteFeature

@AdminRoute.route("/manage-website-features", methods=['GET'])
def ManageWebsiteFeatures():
    AdminPermissionRequired('ManageWebsiteFeatures')

    SitesFeaturesStatus = []
    for feature in WebsiteFeaturesDefinition:
        SitesFeaturesStatus.append( {
            "name" : feature["name"],
            "enabled" : GetWebsiteFeature(feature["name"]),
        })

    return render_template("admin/websitefeatures.html", SitesFeaturesStatus=SitesFeaturesStatus)

@AdminRoute.route("/manage-website-features/<featurename>/disable", methods=['POST'])
def ManageWebsiteFeaturesDisable(featurename : str):
    AdminPermissionRequired('ManageWebsiteFeatures')
    SetWebsiteFeature(featurename, False)
    return redirect("/admin/manage-website-features")

@AdminRoute.route("/manage-website-features/<featurename>/enable", methods=['POST'])
def ManageWebsiteFeaturesEnable(featurename : str):
    AdminPermissionRequired('ManageWebsiteFeatures')
    SetWebsiteFeature(featurename, True)
    return redirect("/admin/manage-website-features")

@AdminRoute.route("/create-user", methods=['GET'])
def CreateUser():
    AdminPermissionRequired('CreateUser')
    return render_template("admin/createuser.html")

@AdminRoute.route("/create-user", methods=['POST'])
@limiter.limit("5/minute")
def CreateUserPost():
    AdminPermissionRequired('CreateUser')

    Username = request.form.get( key='username', default=None, type=str )
    Password = request.form.get( key='password', default=None, type=str )

    if Username is None or Password is None:
        flash("Invalid request", "error")
        return redirect("/admin/create-user")
    
    from app.pages.signup.signup import isUsernameAllowed
    from app.util.textfilter import FilterText, TextNotAllowedException
    from app.models.user_avatar import UserAvatar
    import hashlib
    from sqlalchemy import func

    isAllowed, Reason = isUsernameAllowed(Username)
    if not isAllowed:
        flash(Reason, "error")
        return redirect("/admin/create-user")
    
    if len(Password) < 8:
        flash("Password must be at least 8 characters long")
        return redirect("/signup")

    try:
        FilterText( Text = Username, ThrowException = True)
    except TextNotAllowedException:
        flash("Username is not friendly for Syntax")
        return redirect("/signup")
    
    UserSignupLock = redislock.acquire_lock("UserSignupLock", acquire_timeout = 20, lock_timeout=1)
    if not UserSignupLock:
        flash("Failed to acquire user signup lock, please contact administrator", "error")
        return redirect("/admin/create-user")
    
    user = User.query.filter(func.lower(User.username) == func.lower(Username)).first()
    if user is not None:
        redislock.release_lock("UserSignupLock", UserSignupLock)
        flash("Username already taken", "error")
        return redirect("/admin/create-user")

    pastUsername = PastUsername.query.filter(func.lower(PastUsername.username) == func.lower(Username)).first()
    if pastUsername is not None:
        redislock.release_lock("UserSignupLock", UserSignupLock)
        flash("Username already taken", "error")
        return redirect("/admin/create-user")
    
    hashedPassword = hashlib.sha512(Password.encode("utf-8")).hexdigest()
    user = User(username=Username, password=hashedPassword, created=datetime.utcnow(), lastonline=datetime.utcnow())
    db.session.add(user)
    db.session.commit()
    userEconomy = UserEconomy(userid=user.id, robux=0, tix=10)
    db.session.add(userEconomy)
    userAvatar = UserAvatar(user_id=user.id)
    db.session.add(userAvatar)
    db.session.commit()
    redislock.release_lock("UserSignupLock", UserSignupLock)
    TakeUserThumbnail(user.id)

    flash("User created", "success")
    return redirect("/admin/create-user")

@AdminRoute.route("/create-giftcard", methods=['GET'])
def CreateGiftcard():
    AdminPermissionRequired('CreateGiftcard')
    return render_template("admin/creategiftcard.html")

@AdminRoute.route("/create-giftcard", methods=['POST'])
def CreateGiftcardPost():
    AdminPermissionRequired('CreateGiftcard')

    GiftcardTypeInput = request.form.get( key='giftcard-type', default=None, type=int )
    CopiesAmount = request.form.get( key='copies', default=None, type=int )
    GiftcardValue = request.form.get( key='value', default=None, type=int )

    if GiftcardTypeInput is None or CopiesAmount is None or GiftcardValue is None:
        flash("Invalid request", "error")
        return redirect("/admin/create-giftcard")
    
    if CopiesAmount < 1 or CopiesAmount > 15:
        flash("Copies value must be between 1 and 15", "error")
        return redirect("/admin/create-giftcard")
    
    if GiftcardTypeInput not in [0,1,2,3,4]:
        flash("Invalid giftcard type", "error")
        return redirect("/admin/create-giftcard")
    
    if GiftcardValue < 1:
        flash("Giftcard value must be at least 1", "error")
        return redirect("/admin/create-giftcard")

    GiftcardTypeInput : GiftcardType = GiftcardType(GiftcardTypeInput)

    if GiftcardTypeInput in [GiftcardType.RobuxCurrency, GiftcardType.TixCurrency]:
        if GiftcardValue > 10000:
            flash("Giftcard value must be at most 10000", "error")
            return redirect("/admin/create-giftcard")
    elif GiftcardTypeInput in [GiftcardType.Outrageous_BuildersClub, GiftcardType.Turbo_BuildersClub]:
        if GiftcardValue > 12:
            flash("Giftcard value must be at most 12", "error")
            return redirect("/admin/create-giftcard")
    elif GiftcardTypeInput == GiftcardType.Item:
        AssetObj : Asset = Asset.query.filter_by(id=GiftcardValue).first()
        if AssetObj is None:
            flash("Invalid asset", "error")
            return redirect("/admin/create-giftcard")
        if AssetObj.is_limited:
            flash("Cannot create giftcard for limited items", "error")
            return redirect("/admin/create-giftcard")
    else:
        flash("Invalid giftcard type", "error")
        return redirect("/admin/create-giftcard")
    
    AuthenticatedUser : User = auth.GetCurrentUser()

    if redis_controller.get(f"GiftcardCooldown_{AuthenticatedUser.id}") is not None:
        flash("You are on cooldown", "error")
        return redirect("/admin/create-giftcard")
    redis_controller.set(f"GiftcardCooldown_{AuthenticatedUser.id}", "1", ex=60)

    def GenerateCode():
        Code = ""
        for i in range(0, 5):
            Chunk = ''.join(random.choices(string.ascii_uppercase + string.digits, k=5))
            Code += Chunk
            if i != 4:
                Code += "-"
        return Code
    
    AllCodes = []

    for i in range(0, CopiesAmount):
        Code = GenerateCode()
        GiftcardObj : GiftcardKey = GiftcardKey(key=Code, value=GiftcardValue, type=GiftcardTypeInput)
        db.session.add(GiftcardObj)
        AllCodes.append(Code)
    db.session.commit()

    flash(f"Created {CopiesAmount} giftcards", "success")
    return render_template("admin/creategiftcard.html", codes=AllCodes)

@AdminRoute.route("/update-asset-file", methods=['GET'])
def UpdateAssetFile():
    AdminPermissionRequired('UpdateAssetFile')
    return render_template("admin/updateassetfile.html")
from app.util import s3helper
@AdminRoute.route("/update-asset-file", methods=['POST'])
def UpdateAssetFilePost():
    AdminPermissionRequired('UpdateAssetFile')
    AuthenticatedUser : User = auth.GetCurrentUser()
    AssetID = request.form.get( key='asset-id', default=None, type=int )
    if AssetID is None:
        flash("Invalid request", "error")
        return redirect("/admin/update-asset-file")
    
    AssetObj : Asset = Asset.query.filter_by(id=AssetID).first()
    if AssetObj is None:
        flash("Invalid asset", "error")
        return redirect("/admin/update-asset-file")
    if AssetObj.creator_id not in [1,2] or AssetObj.creator_type != 0:
        flash("Asset is not owned by Syntax", "error")
        return redirect("/admin/update-asset-file")
    if AssetObj.asset_type not in [AssetType(1), AssetType(2), AssetType(3), AssetType(4), AssetType(8), AssetType(11), AssetType(12), AssetType(17), AssetType(18), AssetType(19), AssetType(24), AssetType(27), AssetType(28), AssetType(29), AssetType(30), AssetType(31), AssetType(32), AssetType(41), AssetType(42), AssetType(43), AssetType(44), AssetType(45), AssetType(46), AssetType(47), AssetType(57), AssetType(58)]:
        if AuthenticatedUser.id != 1:
            flash("You are not allowed to update this type of asset", "error")
            return redirect("/admin/update-asset-file")
    
    if 'file' not in request.files:
        flash("No file uploaded", "error")
        return redirect("/admin/update-asset-file")
    
    AssetFile = request.files['file']
    if AssetFile.filename == '':
        flash("No file uploaded", "error")
        return redirect("/admin/update-asset-file")
    
    AssetFile.seek(0)
    AssetFileContent = AssetFile.read()
    AssetFileHash = hashlib.sha512(AssetFileContent).hexdigest()

    from app.util.assetvalidation import ValidateClothingImage, ValidatePlaceFile

    if AssetObj.asset_type == AssetType.Image:
        isAllowed = ValidateClothingImage( AssetFile, verifyResolution=False)
        if not isAllowed:
            flash("Invalid image", "error")
            return redirect("/admin/update-asset-file")
    else:
        isValidPlaceFile = ValidatePlaceFile( AssetFile)
        if type(isValidPlaceFile) is str:
            flash(f"Validation Failed: {isValidPlaceFile}", "error")
            return redirect("/admin/update-asset-file")
    
    if not s3helper.DoesKeyExist(AssetFileHash):
        s3helper.UploadBytesToS3(AssetFileContent, AssetFileHash)
    
    NewAssetVersion : AssetVersion = assetversion.CreateNewAssetVersion(AssetObj, AssetFileHash)
    AssetObj.updated_at = datetime.utcnow()
    db.session.commit()

    flash("Asset file updated", "success")
    return redirect("/admin/update-asset-file")

@AdminRoute.route("/copy-bundle", methods=['GET'])
def CopyBundle():
    AdminPermissionRequired('CopyBundle')
    return render_template("admin/bundlecopier.html")

@AdminRoute.route("/copy-bundle", methods=['POST'])
def CopyBundlePost():
    AdminPermissionRequired('CopyBundle')

    BundleID = request.form.get( key='bundle-id', default=None, type=int )
    if BundleID is None:
        flash("Invalid request", "error")
        return redirect("/admin/copy-bundle")

    from app.routes.asset import MigrateBundle, MigrateBundleException
    try:
        NewBundle : Asset = MigrateBundle(BundleID)
    except MigrateBundleException as e:
        flash(e.message, "error")
        return redirect("/admin/copy-bundle")
    except Exception as e:
        flash(f"An error occured, {str(e)}", "error")
        return redirect("/admin/copy-bundle")
    
    return redirect(f"/admin/manage-assets/{str(NewBundle.id)}")

@AdminRoute.route("/create-asset", methods=['GET'])
def CreateAsset():
    AdminPermissionRequired('CreateAsset')
    return render_template("admin/createasset.html")

@AdminRoute.route("/create-asset", methods=['POST'])
def CreateAssetPost():
    AdminPermissionRequired('CreateAsset')

    AssetTypeInput = request.form.get( key='asset-type', default=None, type=int )
    AssetName = request.form.get( key='asset-name', default=None, type=str )
    AssetFile = request.files.get(key='file', default=None)

    if AssetTypeInput is None or AssetName is None or AssetFile is None:
        flash("Invalid request", "error")
        return redirect("/admin/create-asset")
    
    if AssetTypeInput not in [8,17,18,19,41,42,43,44,45,46,47,62]:
        flash("Invalid asset type", "error")
        return redirect("/admin/create-asset")
    
    if AssetName == "":
        flash("Asset name cannot be empty", "error")
        return redirect("/admin/create-asset")
    if len(AssetName) > 64:
        flash("Asset name is too long", "error")
        return redirect("/admin/create-asset")

    if AssetFile.content_length > 1024*1024*5:
        flash("File is too big", "error")
        return redirect("/admin/create-asset")
    
    from app.util.assetvalidation import ValidatePlaceFile
    if AssetTypeInput not in [62]:
        isValidBinaryFile = ValidatePlaceFile( AssetFile )
        if isValidBinaryFile != True:
            flash(f"Validation Failed: {isValidBinaryFile}", "error")
            return redirect("/admin/create-asset")
    
    AssetTypeInput : AssetType = AssetType(AssetTypeInput)

    NewAssetObj : Asset = Asset(
        name = AssetName,
        creator_id = 1,
        creator_type = 0,
        asset_type = AssetTypeInput,
        created_at = datetime.utcnow(),
        updated_at = datetime.utcnow(),
        description = "",
        moderation_status = 0,
        asset_genre = 1
    )
    db.session.add(NewAssetObj)
    db.session.commit()

    AssetFile.seek(0)
    AssetFileContent = AssetFile.read()
    AssetFileHash = hashlib.sha512(AssetFileContent).hexdigest()
    s3helper.UploadBytesToS3(AssetFileContent, AssetFileHash)
    NewAssetVersion : AssetVersion = assetversion.CreateNewAssetVersion(NewAssetObj, AssetFileHash)

    return redirect(f"/admin/manage-assets/{str(NewAssetObj.id)}")

@AdminRoute.route("/moderate-asset", methods=['GET'])
def ModerateAsset():
    AdminPermissionRequired('ModerateAsset')
    return render_template("admin/moderateUGC.html")

@AdminRoute.route("/moderate-asset/<int:assetid>", methods=['GET'])
def ModerateAssetView( assetid : int ):
    AdminPermissionRequired('ModerateAsset')

    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        flash("Invalid asset", "error")
        return redirect("/admin/moderate-asset")
    if AssetObj.creator_id in [1] and AssetObj.creator_type == 0:
        if not HasAdminPermission("ManageAsset"):
            flash("You are not allowed to manage a Admin owned asset", "error")
            return redirect("/admin/moderate-asset")
    
    AllAssetThumbnails : list[AssetThumbnail] = AssetThumbnail.query.filter_by(asset_id=assetid).order_by(AssetThumbnail.id.desc()).all()
    AllAssetVersions : list[AssetVersion] = AssetVersion.query.filter_by(asset_id=assetid).order_by(AssetVersion.id.desc()).all()
    RelatedAssetsLink : list[AssetModerationLink] = AssetModerationLink.query.filter(or_(AssetModerationLink.ParentAssetId == AssetObj.id, AssetModerationLink.ChildAssetId == AssetObj.id)).all()
    if AssetObj.creator_type == 0:
        CreatorObj : User = User.query.filter_by(id=AssetObj.creator_id).first()
    else:
        CreatorObj : Group = Group.query.filter_by(id=AssetObj.creator_id).first()

    RelatedAssets : list[Asset] = []
    for assetlink in RelatedAssetsLink:
        if assetlink.ParentAssetId == AssetObj.id:
            RelatedAssets.append(assetlink.ChildAsset)
        else:
            RelatedAssets.append(assetlink.ParentAsset)

    return render_template(
        "admin/moderateUGC.html", 
        AssetObj=AssetObj, 
        AllAssetThumbnails=AllAssetThumbnails, 
        AllAssetVersions=AllAssetVersions,
        CreatorObj=CreatorObj,
        RelatedAssets=RelatedAssets
    )
StatusToColor = {
    0 : {
        "color" : 0x0ef05d,
        "name" : "Approved"
    },
    1 : {
        "color" : 0xffc107,
        "name" : "Pending Review"
    },
    2 : {
        "color" : 0xff0000,
        "name" : "Deleted"
    }
}

def LogAssetModerationAction( Actor : User, AssetObj : Asset ):
    def thread_func():
        EmbedObj = {
            "type": "rich",
            "title": "Asset Moderation",
            "description": f"Asset [{AssetObj.id}](https://www.syntax.eco/admin/moderate-asset/{AssetObj.id}) moderation status has been updated by **{Actor.username}** ({Actor.id})",
            "color": StatusToColor[AssetObj.moderation_status]["color"],
            "fields": [
                {
                    "name": "Asset Type",
                    "value": AssetObj.asset_type.name,
                    "inline": False
                },
                {
                    "name": "Asset Moderation Status",
                    "value": StatusToColor[AssetObj.moderation_status]["name"],
                    "inline": False
                }
            ],
            "author": {
                "name": Actor.username,
                "icon_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(Actor.id)}"
            },
            "footer": {
                "text": "Syntax Asset Moderation Log"
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        try:
            requests.post(
                url = config.DISCORD_ADMIN_LOGS_WEBHOOK,
                json = {
                    "username": "Syntax Asset Moderation Log",
                    "embeds" : [EmbedObj],
                    "avatar_url": f"https://www.syntax.eco/Thumbs/Head.ashx?x=48&y=48&userId={str(Actor.id)}"
                }
            )
        except Exception as e:
            logging.warn(f"Admin > LogAssetModerationAction: Exception raised when sending webhook - {str(e)}")
    threading.Thread(target=thread_func).start()

@AdminRoute.route("/moderate-asset/<int:assetid>/quick-delete", methods=['POST'])
def ModerateAssetQuickDelete( assetid : int ):
    AdminPermissionRequired('ModerateAsset')

    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        flash("Invalid asset", "error")
        return redirect("/admin/moderate-asset")
    if AssetObj.creator_id in [1] and AssetObj.creator_type == 0:
        if not HasAdminPermission("ManageAsset"):
            flash("You are not allowed to manage a Admin owned asset", "error")
            return redirect("/admin/moderate-asset")
    if AssetObj.moderation_status == 2:
        flash("Asset is already deleted", "error")
        return redirect(f"/admin/moderate-asset/{str(assetid)}")
    AuthenticatedUser : User = auth.GetCurrentUser()
    if redis_controller.exists(f"ModerateAssetCooldown_{AuthenticatedUser.id}") and AuthenticatedUser.id != 1:
        flash("You are on cooldown", "error")
        return redirect(f"/admin/moderate-asset/{str(assetid)}")
    redis_controller.set(f"ModerateAssetCooldown_{AuthenticatedUser.id}", "1", ex=20)
    
    def ContentDeleteAssetObj( AssetObj : Asset ):
        AssetObj.moderation_status = 2 # Deleted
        AssetObj.name = f"[ Content Deleted {AssetObj.id} ]"
        AssetObj.description = ""
        AssetObj.updated_at = datetime.utcnow()
        AssetObj.is_for_sale = False

        AllAssetThumbnails : list[AssetThumbnail] = AssetThumbnail.query.filter_by(asset_id=AssetObj.id).order_by(AssetThumbnail.id.desc()).all()

        for assetthumbnail in AllAssetThumbnails:
            assetthumbnail.moderation_status = 2
            assetthumbnail.updated_at = datetime.utcnow()

        if AssetObj.asset_type == AssetType.Place:
            PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=AssetObj.id).first()
            if PlaceIconObj is not None:
                PlaceIconObj.moderation_status = 2
                PlaceIconObj.updated_at = datetime.utcnow()
        db.session.commit()
    
    ContentDeleteAssetObj(AssetObj)
    RelatedAssetsLink : list[AssetModerationLink] = AssetModerationLink.query.filter(or_(AssetModerationLink.ParentAssetId == AssetObj.id, AssetModerationLink.ChildAssetId == AssetObj.id)).all()
    for assetlink in RelatedAssetsLink:
        if assetlink.ParentAssetId == AssetObj.id:
            ContentDeleteAssetObj(assetlink.ChildAsset)
            flash(f"Asset [{assetlink.ChildAssetId}] deleted as it was linked.", "success")
        else:
            ContentDeleteAssetObj(assetlink.ParentAsset)
            flash(f"Asset [{assetlink.ParentAssetId}] deleted as it was linked.", "success")
    
    flash("Asset Content deleted", "success")
    LogAssetModerationAction(AuthenticatedUser, AssetObj)
    return redirect(f"/admin/moderate-asset/{str(assetid)}")

@AdminRoute.route("/moderate-asset/<int:assetid>/quick-approve", methods=['POST'])
def ModerateAssetQuickApporve( assetid : int ):
    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        flash("Invalid asset", "error")
        return redirect("/admin/moderate-asset")
    if AssetObj.creator_id in [1] and AssetObj.creator_type == 0:
        if not HasAdminPermission("ManageAsset"):
            flash("You are not allowed to manage a Admin owned asset", "error")
            return redirect("/admin/moderate-asset")
    if AssetObj.moderation_status == 0:
        flash("Asset is already approved", "error")
        return redirect(f"/admin/moderate-asset/{str(assetid)}")
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    if redis_controller.exists(f"ModerateAssetCooldown_{AuthenticatedUser.id}") and AuthenticatedUser.id != 1:
        flash("You are on cooldown", "error")
        return redirect(f"/admin/moderate-asset/{str(assetid)}")
    redis_controller.set(f"ModerateAssetCooldown_{AuthenticatedUser.id}", "1", ex=20)

    def AllowContentAssetObj( AssetObj : Asset ):
        AssetObj.moderation_status = 0
        AssetObj.updated_at = datetime.utcnow()

        AllAssetThumbnails : list[AssetThumbnail] = AssetThumbnail.query.filter_by(asset_id=AssetObj.id).order_by(AssetThumbnail.id.desc()).all()
        for assetthumbnail in AllAssetThumbnails:
            assetthumbnail.moderation_status = 0
            assetthumbnail.updated_at = datetime.utcnow()

        if AssetObj.asset_type == AssetType.Place:
            PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=AssetObj.id).first()
            if PlaceIconObj is not None:
                PlaceIconObj.moderation_status = 0
                PlaceIconObj.updated_at = datetime.utcnow()
        db.session.commit()
    
    AllowContentAssetObj(AssetObj)
    RelatedAssetsLink : list[AssetModerationLink] = AssetModerationLink.query.filter(or_(AssetModerationLink.ParentAssetId == AssetObj.id, AssetModerationLink.ChildAssetId == AssetObj.id)).all()
    for assetlink in RelatedAssetsLink:
        if assetlink.ParentAssetId == AssetObj.id:
            AllowContentAssetObj(assetlink.ChildAsset)
            flash(f"Asset [{assetlink.ChildAssetId}] approved as it was linked.", "success")
        else:
            AllowContentAssetObj(assetlink.ParentAsset)
            flash(f"Asset [{assetlink.ParentAssetId}] approved as it was linked.", "success")
    
    flash("Asset approved", "success")
    LogAssetModerationAction(AuthenticatedUser, AssetObj)
    return redirect(f"/admin/moderate-asset/{str(assetid)}")

@AdminRoute.route("/moderate-asset/<int:assetid>/quick-pending", methods=['POST'])
def ModerateAssetQuickPending( assetid : int ):
    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        flash("Invalid asset", "error")
        return redirect("/admin/moderate-asset")
    if AssetObj.creator_id in [1] and AssetObj.creator_type == 0:
        if not HasAdminPermission("ManageAsset"):
            flash("You are not allowed to manage a Admin owned asset", "error")
            return redirect("/admin/moderate-asset")
    if AssetObj.moderation_status == 1:
        flash("Asset is already pending", "error")
        return redirect(f"/admin/moderate-asset/{str(assetid)}")
    AuthenticatedUser : User = auth.GetCurrentUser()
    if redis_controller.exists(f"ModerateAssetCooldown_{AuthenticatedUser.id}") and AuthenticatedUser.id != 1:
        flash("You are on cooldown", "error")
        return redirect(f"/admin/moderate-asset/{str(assetid)}")
    redis_controller.set(f"ModerateAssetCooldown_{AuthenticatedUser.id}", "1", ex=20)

    def PendingContentAssetObj( AssetObj : Asset ):
        AssetObj.moderation_status = 1
        AssetObj.updated_at = datetime.utcnow()

        AllAssetThumbnails : list[AssetThumbnail] = AssetThumbnail.query.filter_by(asset_id=AssetObj.id).order_by(AssetThumbnail.id.desc()).all()
        for assetthumbnail in AllAssetThumbnails:
            assetthumbnail.moderation_status = 1
            assetthumbnail.updated_at = datetime.utcnow()

        if AssetObj.asset_type == AssetType.Place:
            PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=AssetObj.id).first()
            if PlaceIconObj is not None:
                PlaceIconObj.moderation_status = 1
                PlaceIconObj.updated_at = datetime.utcnow()
        db.session.commit()

    PendingContentAssetObj(AssetObj)
    RelatedAssetsLink : list[AssetModerationLink] = AssetModerationLink.query.filter(or_(AssetModerationLink.ParentAssetId == AssetObj.id, AssetModerationLink.ChildAssetId == AssetObj.id)).all()
    for assetlink in RelatedAssetsLink:
        if assetlink.ParentAssetId == AssetObj.id:
            PendingContentAssetObj(assetlink.ChildAsset)
            flash(f"Asset [{assetlink.ChildAssetId}] pending as it was linked.", "success")
        else:
            PendingContentAssetObj(assetlink.ParentAsset)
            flash(f"Asset [{assetlink.ParentAssetId}] pending as it was linked.", "success")
    
    flash("Asset set to pending", "success")
    LogAssetModerationAction(AuthenticatedUser, AssetObj)
    return redirect(f"/admin/moderate-asset/{str(assetid)}")

@AdminRoute.route("/moderate-asset", methods=['POST'])
def ModerateAssetSearch():
    AdminPermissionRequired('ModerateAsset')

    AssetID = request.form.get( key='asset-id', default=None, type=int )
    if AssetID is None:
        flash("Invalid request", "error")
        return redirect("/admin/moderate-asset")
    if AssetID < 0:
        flash("Invalid request", "error")
        return redirect("/admin/moderate-asset")
    return redirect(f"/admin/moderate-asset/{str(AssetID)}")

@AdminRoute.route("/lottery", methods=["GET"])
def LotteryIndex():
    AdminPermissionRequired('Lottery')

    EligibleUsers = User.query.filter(or_( User.accountstatus == 3, User.accountstatus == 4, User.lastonline < datetime.utcnow() - timedelta( days = 31 ) ))
    EligibleUsers = EligibleUsers.outerjoin( UserAsset, UserAsset.userid == User.id ).outerjoin( Asset, Asset.id == UserAsset.assetid ).filter( Asset.is_limited == True ).group_by( User.id ).all()

    def GetTotalLimiteds( UserObject : User ) -> int:
        if redis_controller.exists(f"LotteryLimitedCountCache:{UserObject.id}"):
            return int(redis_controller.get(f"LotteryLimitedCountCache:{UserObject.id}"))
        TotalLimiteds : int = UserAsset.query.filter_by( userid = UserObject.id ).join( Asset, Asset.id == UserAsset.assetid ).filter( Asset.is_limited == True ).count()
        redis_controller.set(f"LotteryLimitedCountCache:{UserObject.id}", str(TotalLimiteds), ex=120)
        return TotalLimiteds

    return render_template("admin/lottery/index.html", EligibleUsers=EligibleUsers, GetTotalLimiteds=GetTotalLimiteds, InactiveTime = (datetime.utcnow() - timedelta( days = 31 )) )

@AdminRoute.route("/lottery", methods=["POST"])
def LotteryPost():
    AdminPermissionRequired('Lottery')

    SelectedUser : int = request.form.get( key='selected-user', default=None, type=int )
    if SelectedUser is None:
        flash("Invalid request", "error")
        return redirect("/admin/lottery")
    
    UserObject : User = User.query.filter_by( id = SelectedUser ).first()
    if UserObject is None:
        flash("Invalid user", "error")
        return redirect("/admin/lottery")
    
    if UserObject.accountstatus not in [3,4] and UserObject.lastonline > datetime.utcnow() - timedelta( days = 31 ):
        flash("User is not eligible", "error")
        return redirect("/admin/lottery")
    
    TotalUsersOnline : int = User.query.filter( User.lastonline > datetime.utcnow() - timedelta( minutes = 2 ) ).count()
    if TotalUsersOnline < 10:
        flash("Not enough users online", "error")
        return redirect("/admin/lottery")

    EligibleLimiteds : list[UserAsset] = UserAsset.query.filter_by( userid = UserObject.id ).join( Asset, Asset.id == UserAsset.assetid ).filter( Asset.is_limited == True ).all()
    if len(EligibleLimiteds) < 1:
        flash("User does not have any limiteds", "error")
        return redirect("/admin/lottery")
    
    AuthenticatedUser : User = auth.GetCurrentUser()

    PreviousWinner = None
    for UserAssetObj in EligibleLimiteds:
        RandomWinner : User = User.query.filter(and_(
            User.id != UserObject.id,
            User.id != AuthenticatedUser.id,
            User.id != PreviousWinner,
            User.lastonline > datetime.utcnow() - timedelta( minutes = 2 )
        )).order_by(func.random()).first()

        if RandomWinner is None:
            flash("Not enough users online", "error")
            return redirect("/admin/lottery")
        
        PreviousWinner = RandomWinner.id
        UserAssetObj.userid = RandomWinner.id
        UserAssetObj.updated = datetime.utcnow()
        CreateSystemMessage( 
            f"You won a free limited!",
            f"""You have been randomly selected to be given a free limited by Syntax.
You have won: {UserAssetObj.asset.name} ( {UserAssetObj.asset.id} ) [ UAID: {UserAssetObj.id} / Serial: { UserAssetObj.serial if UserAssetObj.serial is not None else 'None'} ]

- Syntax Team
""",
            RandomWinner.id
        )
        CreateSystemMessage(
            f"Limited Item removed",
            f""""Your limited {UserAssetObj.asset.name} ( {UserAssetObj.asset.id} ) [ UAID: {UserAssetObj.id} / Serial: { UserAssetObj.serial if UserAssetObj.serial is not None else 'None'} ] has been removed from your account and was given to another SYNTAX User
This was because you are either:
    - Inactive for over 31 days
    - Terminated

We apologize for any inconvenience this may have caused.

- Syntax Team
""",
            UserObject.id
        )

        TargetUserAvatarAsset : UserAvatarAsset = UserAvatarAsset.query.filter_by( user_id = UserObject.id, asset_id = UserAssetObj.asset.id ).first()
        if TargetUserAvatarAsset is not None:
            db.session.delete(TargetUserAvatarAsset)
        
        db.session.commit()

        try:
            newLimitedTransfer = LimitedItemTransfer(
                original_owner_id = UserObject.id,
                new_owner_id = RandomWinner.id,
                asset_id = UserAssetObj.assetid,
                user_asset_id = UserAssetObj.id,
                transfer_method = LimitedItemTransferMethod.WonByLottery,
                purchased_price = None
            )
            db.session.add(newLimitedTransfer)
            db.session.commit()
        except Exception as e:
            flash(f"Failed to create LimitedItemTransfer: {str(e)}, but lottery items has still been given away", "error")

    TakeUserThumbnail( UserObject.id )
    flash("Lottery completed", "success")
    return redirect("/admin/lottery")
        