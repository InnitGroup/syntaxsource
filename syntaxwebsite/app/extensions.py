from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import or_, and_, text
from flask_limiter import Limiter, HEADERS
from flask_apscheduler import APScheduler
from flask import request
from flask_cors import CORS
import redis
import datetime
from config import Config
import logging
import time
from flask_wtf.csrf import CSRFProtect
from app.enums.AssetType import AssetType
csrf = CSRFProtect()
db = SQLAlchemy()
Config = Config()
CORS = CORS()

def get_remote_address() -> str:
    cloudflare = request.headers.get("CF-Connecting-IP")
    if cloudflare is not None:
        return cloudflare
    return request.remote_addr or "127.0.0.1"

def get_user_id() -> str:
    """
        Gets the UserId for the current request

        :return: UserId or -1 if not logged in
    """
    if ".ROBLOSECURITY" in request.cookies:
        return "user_id:-1"

    from app.util.auth import GetTokenInfo
    UserTokenInfo = GetTokenInfo( request.cookies.get(".ROBLOSECURITY", default = "None", type = str) )
    if UserTokenInfo is None:
        return "user_id:-1"
    
    return f"user_id:{ UserTokenInfo[0] }"

limiter = Limiter(
    get_remote_address,
    storage_uri=Config.FLASK_LIMITED_STORAGE_URI,
    strategy="fixed-window-elastic-expiry",
    headers_enabled=True,
    key_prefix = "address_limiter"
)

user_limiter = Limiter(
    key_func = get_user_id,
    storage_uri=Config.FLASK_LIMITED_STORAGE_URI,
    strategy="fixed-window-elastic-expiry",
    headers_enabled=True,
    key_prefix = "user_limiter"
)

redis_controller = Config.REDIS_CLIENT

scheduler = APScheduler()
logging.getLogger('apscheduler').setLevel(logging.ERROR)

@scheduler.task('interval', id='item_release_pool_releaser', seconds=60, misfire_grace_time=60)
def item_release_pool_releaser():
    with scheduler.app.app_context():
        import time
        import json
        import random
        import uuid
        import requests
        from app.models.asset import Asset
        from app.pages.admin.admin import GetNextItemDropDateTime, SetAssetOffsaleJob

        if redis_controller.get("item_release_pool_releaser") is not None:
            return
        redis_controller.set("item_release_pool_releaser", "busy", ex=120)
        if redis_controller.llen("ItemReleasePool:Items") <= 0:
            redis_controller.set("ItemReleasePool:LastDropTimestamp", value = str(round(time.time())))
            return
        
        if datetime.datetime.utcnow() < GetNextItemDropDateTime():
            return
        random.seed( time.time() )
        RandomIndex = random.randint( 0, redis_controller.llen("ItemReleasePool:Items") - 1 )
        SelectedAssetId = redis_controller.lindex( "ItemReleasePool:Items", RandomIndex )
        if SelectedAssetId is None:
            logging.warning("item_release_pool_releaser failed to selected random asset, lindex returned None")
            return
        redis_controller.lrem("ItemReleasePool:Items", count = 0, value = SelectedAssetId)
        try:
            SelectedAssetId = int(SelectedAssetId)
        except Exception as e:
            logging.warn(f"item_release_pool_releaser failed to cast string to integer, value: {SelectedAssetId}")
            return
        
        AssetMetadata = redis_controller.get(f"ItemReleasePool:Item_Metadata:{SelectedAssetId}")
        if AssetMetadata is None:
            logging.warn(f"item_release_pool_releaser failed to get asset metadata for {SelectedAssetId}")
            return
        try:
            AssetMetadata = json.loads(AssetMetadata)
        except Exception as e:
            logging.warn(f"item_release_pool_releaser failed to parse json from item metadata {SelectedAssetId}, {str(e)}")
            return

        AssetObj : Asset = Asset.query.filter_by( id = SelectedAssetId ).first()
        if AssetObj is None:
            logging.warn(f"item_release_pool_releaser asset id {SelectedAssetId} does not exist")
            return

        AssetObj.name = AssetMetadata["Name"]
        AssetObj.description = AssetMetadata["Description"]
        AssetObj.price_robux = AssetMetadata["RobuxPrice"]
        AssetObj.price_tix = AssetMetadata["TicketsPrice"]
        AssetObj.is_limited = AssetMetadata["IsLimited"]
        AssetObj.is_limited_unique = AssetMetadata["IsLimitedUnique"]
        AssetObj.serial_count = AssetMetadata["SerialCount"]
        AssetObj.moderation_status = 0
        AssetObj.updated_at = datetime.datetime.utcnow()
        AssetObj.is_for_sale = True

        if AssetMetadata["OffsaleAfter"] is not None:
            OffsaleAfter = datetime.timedelta( seconds = AssetMetadata["OffsaleAfter"] )
            AssetOffsaleAt = datetime.datetime.utcnow() + OffsaleAfter

            if redis_controller.exists(f"APSchedulerTaskJobUUID:{str(AssetObj.id)}"):
                try:
                    scheduler.remove_job(redis_controller.get(f"APSchedulerTaskJobUUID:{str(AssetObj.id)}"))
                except:
                    logging.warning(f"Failed to remove job {redis_controller.get(f'APSchedulerTaskJobUUID:{str(AssetObj.id)}')}")
            
            APSchedulerTaskJobUUID = str(uuid.uuid4())
            scheduler.add_job(id=APSchedulerTaskJobUUID, func=SetAssetOffsaleJob, trigger='date', run_date=AssetOffsaleAt, args=[AssetObj.id])
            redis_controller.set(f"APSchedulerTaskJobUUID:{str(AssetObj.id)}", APSchedulerTaskJobUUID)
            logging.info(f"Asset {str(AssetObj.id)} has been set to go offsale at {str(AssetOffsaleAt)}, job UUID: {APSchedulerTaskJobUUID}")

            AssetObj.offsale_at = AssetOffsaleAt

        db.session.commit()
        logging.info(f"Released Item {AssetObj.id}")
        redis_controller.set("ItemReleasePool:LastDropTimestamp", value = str(round(time.time())))

        try:
            requests.post(
                Config.ITEMRELEASER_DISCORD_WEBHOOK,
                json = {
                    "content": f"<@&{Config.ITEMRELEASER_ITEM_PING_ROLE_ID}> New Item Drop!",
                    "allowed_mentions": {
                        "replied_user": False,
                        "parse": [],
                        "roles": [
                            Config.ITEMRELEASER_ITEM_PING_ROLE_ID
                        ]
                    },
                    "username": "Automatic Item Release Bot",
                    "avatar_url": f"{Config.BaseURL}/Thumbs/Head.ashx?x=48&y=48&userId=1",
                    "embeds": [{
                        "type": "rich",
                        "title": AssetObj.name,
                        "description": AssetObj.description,
                        "color": 0x00ff62,
                        "fields": [
                            {
                                "name": "Robux Price",
                                "value": f"R${AssetObj.price_robux}",
                                "inline": True
                            },
                            {
                                "name": "Tickets Price",
                                "value": f"T${AssetObj.price_tix}",
                                "inline": True
                            },
                            {
                                "name": "Limited Unique",
                                "value": str(AssetObj.is_limited_unique),
                                "inline": True
                            },
                            {
                                "name": "Serial Count",
                                "value": "None" if AssetObj.serial_count == 0 else str(AssetObj.serial_count),
                                "inline": True
                            },
                            {
                                "name": "Offsale in",
                                "value": "Never" if AssetObj.offsale_at is None else f"<t:{int(AssetObj.offsale_at.timestamp())}:R>",
                                "inline": True
                            }
                        ],
                        "thumbnail": {
                            "url": f"{Config.BaseURL}/Thumbs/Asset.ashx?x=180&y=180&assetId={AssetObj.id}",
                            "height": 120,
                            "width": 120   
                        },
                        "url": f"{Config.BaseURL}/catalog/{AssetObj.id}/--",
                        "footer": {
                            "text": f"Syntax Item Release Bot"
                        },
                        "timestamp": datetime.datetime.utcnow().isoformat()
                    }]
                }
            )
        except Exception as e:
            logging.warn(f"item_release_pool_releaser failed to send Discord Webhook message, {e}")

@scheduler.task('interval', id='builders_club_stipend', seconds=120, misfire_grace_time=60)
def builders_club_stipend():
    with scheduler.app.app_context():
        if redis_controller.get("builders_club_stipend") is not None:
            return
        redis_controller.set("builders_club_stipend", "busy", ex=120)
        from app.models.user_membership import UserMembership
        from app.models.user import User
        from app.models.game_session_log import GameSessionLog
        from app.enums.MembershipType import MembershipType
        from app.enums.TransactionType import TransactionType
        from app.services.economy import IncrementTargetBalance
        from app.util.transactions import CreateTransaction
        from app.util.membership import GetUserMembership, RemoveUserMembership, GiveUserMembership
        from app.pages.messages.messages import CreateSystemMessage
        from app.models.linked_discord import LinkedDiscord

        # Get all users who membership has expired
        ExpiredMemberships : list[UserMembership] = UserMembership.query.filter(
            UserMembership.expiration < datetime.datetime.utcnow()
        )
        for MembershipObj in ExpiredMemberships:
            try:
                if MembershipObj.membership_type == MembershipType.BuildersClub:
                    # Check if their discord is still linked
                    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(user_id=MembershipObj.user_id).first()
                    if LinkedDiscordObj is not None:
                        # Give them a free month of BC
                        MembershipObj.membership_type = MembershipType.BuildersClub
                        MembershipObj.expiration = datetime.datetime.utcnow() + datetime.timedelta(days=31)
                        db.session.commit()
                        continue
                elif MembershipObj.membership_type == MembershipType.TurboBuildersClub or MembershipObj.membership_type == MembershipType.OutrageousBuildersClub:
                    UserObj : User = User.query.filter_by(id=MembershipObj.user_id).first()
                    CreateSystemMessage(
                        subject = "Builders Club membership expired",
                        message = f"""Hello {UserObj.username},
This is an automated message to inform you that your Builders Club membership has expired, if you wish to renew your membership you can do so by following the instructions below
 - For Turbo Builders Club members:
    - You can renew your membership in the Discord Server by running the '/claim-turbo' command in the #bot-commands channel, this does require you to still be boosting our Discord Server
 - For Outrageous Builders Club members:
    - You can renew your membership by donating $5 to our Ko-Fi page https://ko-fi.com/syntaxeco

If you have any questions or concerns, please contact our support in our Discord Server

Sincerely,
The SYNTAX Team""",
                        userid = MembershipObj.user_id
                    )
                # Remove the membership
                RemoveUserMembership(MembershipObj.user_id)
                LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(user_id=MembershipObj.user_id).first()
                if LinkedDiscordObj is not None:
                    GiveUserMembership(MembershipObj.user_id, MembershipType.BuildersClub, expiration=datetime.timedelta(days=31))
            except Exception as e:
                logging.info(f"Error while removing expired membership, Exception: {str(e)}")
                continue
        
        WaitingMemberships : list[UserMembership] = UserMembership.query.filter(
            or_(
                UserMembership.membership_type == MembershipType.TurboBuildersClub,
                UserMembership.membership_type == MembershipType.OutrageousBuildersClub
            )
        ).filter(
            UserMembership.next_stipend < datetime.datetime.utcnow()
        ).all()
        if len(WaitingMemberships) > 0:
            logging.info(f"Found {len(WaitingMemberships)} users waiting for stipend")
        for MembershipObj in WaitingMemberships:
            UserObj : User = User.query.filter_by(id=MembershipObj.user_id).first()
            if UserObj is None:
                continue
            if MembershipObj.membership_type == MembershipType.TurboBuildersClub:
                IncrementTargetBalance(UserObj, 45, 0)
                MembershipObj.next_stipend = MembershipObj.next_stipend + datetime.timedelta(hours=24)
                CreateTransaction(
                    Reciever = UserObj,
                    Sender = User.query.filter_by(id=1).first(),
                    CurrencyAmount = 45,
                    CurrencyType = 0,
                    TransactionType = TransactionType.BuildersClubStipend,
                    AssetId = None,
                    CustomText = "Builders Club Stipend"
                )
                logging.info(f"Sent stipend to {UserObj.username} ({UserObj.id})")
            elif MembershipObj.membership_type == MembershipType.OutrageousBuildersClub:
                IncrementTargetBalance(UserObj, 80, 0)
                MembershipObj.next_stipend = MembershipObj.next_stipend + datetime.timedelta(hours=24)
                CreateTransaction(
                    Reciever = UserObj,
                    Sender = User.query.filter_by(id=1).first(),
                    CurrencyAmount = 80,
                    CurrencyType = 0,
                    TransactionType = TransactionType.BuildersClubStipend,
                    AssetId = None,
                    CustomText = "Builders Club Stipend"
                )
                logging.info(f"Sent stipend to {UserObj.username} ({UserObj.id})")
            db.session.commit()
        WaitingMemberships : list[UserMembership] = UserMembership.query.filter(
            UserMembership.membership_type == MembershipType.BuildersClub
        ).filter(
            UserMembership.next_stipend < datetime.datetime.utcnow()
        ).join(User).filter(
            User.lastonline > datetime.datetime.utcnow() - datetime.timedelta(hours=24)
        ).all()
        for MembershipObj in WaitingMemberships:
            UserObj : User = User.query.filter_by(id=MembershipObj.user_id).first()
            if UserObj is None:
                continue
            #if GameSessionLog.query.filter_by(user_id=UserObj.id).filter( GameSessionLog.joined_at > datetime.datetime.utcnow() - datetime.timedelta( days = 2 ) ).first() is None:
            #    MembershipObj.next_stipend = datetime.datetime.utcnow() + datetime.timedelta(hours=6)
            #    db.session.commit()
            #    return
            IncrementTargetBalance(UserObj, 10, 0)
            CreateTransaction(
                    Reciever = UserObj,
                    Sender = User.query.filter_by(id=1).first(),
                    CurrencyAmount = 10,
                    CurrencyType = 0,
                    TransactionType = TransactionType.BuildersClubStipend,
                    AssetId = None,
                    CustomText = "Builders Club Stipend"
                )
            MembershipObj.next_stipend = datetime.datetime.utcnow() + datetime.timedelta(hours=24)
            logging.info(f"Sent stipend to {UserObj.username} ({UserObj.id})")
            db.session.commit()

        redis_controller.delete("builders_club_stipend")

@scheduler.task('interval', id='refresh_discord_token', seconds=300, misfire_grace_time=900)
def refresh_discord_token():
    with scheduler.app.app_context():
        if redis_controller.get("refresh_discord_token") is not None:
            return
        redis_controller.set("refresh_discord_token", "busy", ex=120)
        from app.models.linked_discord import LinkedDiscord
        from app.models.user import User
        from app.models.user_membership import UserMembership
        from app.enums.MembershipType import MembershipType
        from app.util.membership import GetUserMembership, RemoveUserMembership
        from app.pages.messages.messages import CreateSystemMessage
        from app.util.discord import RefreshAccessToken, GetUserInfoFromToken, DiscordUserInfo, UnexpectedStatusCode, MissingScope

        def SendUnlinkedNotification( UserId : int , Reason : str ):
            UserObj : User = User.query.filter_by(id=UserId).first()
            if UserObj is None:
                return
            CreateSystemMessage(
                subject = "Discord Account unlinked",
                message = f"""Hello {UserObj.username},
Your discord account was unlinked from your account because \"{Reason}\", if you currently have a Builders Club membership it will be automatically removed from your account until you link your discord account again.

If you have any questions or concerns, please contact our support in our Discord Server

Sincerely,
The SYNTAX Team""",
                userid = UserObj.id
            )
            CurrentUserMembership : MembershipType = GetUserMembership(UserObj)
            if CurrentUserMembership == MembershipType.BuildersClub:
                # Remove the membership
                RemoveUserMembership(UserObj)

        # Get all users who has a linked discord account and has a discord_expiry that is less than the current time
        WaitingDiscordLinks : list[LinkedDiscord] = LinkedDiscord.query.filter(
            LinkedDiscord.discord_expiry < datetime.datetime.utcnow()
        )
        for LinkedDiscordObj in WaitingDiscordLinks:
            try:
                try:
                    DiscordOAuth2TokenExchangeResponseJSON = RefreshAccessToken(LinkedDiscordObj.discord_refresh_token)
                except UnexpectedStatusCode as e:
                    db.session.delete(LinkedDiscordObj)
                    SendUnlinkedNotification(LinkedDiscordObj.user_id, f"UnexpectedStatusCodeException_RefreshAccessToken: {str(e)}")
                    continue
                except MissingScope as e:
                    db.session.delete(LinkedDiscordObj)
                    SendUnlinkedNotification(LinkedDiscordObj.user_id, f"MissingScopeException_RefreshAccessToken: {str(e)}")
                    continue
                # Get user info
                try:
                    DiscordUserInfoObj : DiscordUserInfo = GetUserInfoFromToken(DiscordOAuth2TokenExchangeResponseJSON["access_token"])
                except UnexpectedStatusCode as e:
                    db.session.delete(LinkedDiscordObj)
                    SendUnlinkedNotification(LinkedDiscordObj.user_id, f"UnexpectedStatusCodeException_RefreshUserInfo: {str(e)}")
                    continue
                if DiscordUserInfoObj is None:
                    continue
                LinkedDiscordObj.discord_access_token = DiscordOAuth2TokenExchangeResponseJSON["access_token"]
                LinkedDiscordObj.discord_refresh_token = DiscordOAuth2TokenExchangeResponseJSON["refresh_token"]
                LinkedDiscordObj.discord_expiry = datetime.datetime.utcnow() + datetime.timedelta(seconds=DiscordOAuth2TokenExchangeResponseJSON["expires_in"])
                LinkedDiscordObj.discord_username = DiscordUserInfoObj.Username
                LinkedDiscordObj.discord_discriminator = DiscordUserInfoObj.Discriminator
                LinkedDiscordObj.discord_avatar = DiscordUserInfoObj.AvatarHash
                LinkedDiscordObj.last_updated = datetime.datetime.utcnow()
                db.session.commit()
            except Exception as e:
                logging.info(f"Error while refreshing discord token, Exception: {str(e)}")
                continue


@scheduler.task('interval', id='migrate_assets', seconds=120, misfire_grace_time=60)
def migrate_assets():
    with scheduler.app.app_context():
        if redis_controller.get("migrate_assets_lock") is not None:
            return
        redis_controller.set("migrate_assets_lock", "busy", ex=120)
        from app.routes.asset import migrateAsset, AddAssetToMigrationQueue, AddAudioAssetToAudioMigrationQueue
        from app.routes.asset import NoPermissionException, AssetDeliveryAPIFailedException, AssetOnCooldownException, EconomyAPIFailedException, RatelimittedReachedException, AssetNotFoundException, AssetNotAllowedException
        from app.models.asset import Asset
        
        EconomyFailedCount : int = 0

        while True:
            if redis_controller.llen("migrate_assets_queue") == 0:
                break
            # Get an asset from the queue
            AssetId : int = int(redis_controller.lpop("migrate_assets_queue"))
            if AssetId <= 1:
                continue
            try:
                logging.info(f"AutoAssetMigrator: Auto migrating asset {AssetId}, {redis_controller.llen('migrate_assets_queue')} assets left in queue")
                migrateAsset(AssetId, throwException=True)
            except RatelimittedReachedException:
                logging.info("AutoAssetMigrator: Ratelimit reached while auto migrating assets, stopping")
                AddAssetToMigrationQueue(AssetId, bypassQueueLimit=False)
                break
            except EconomyAPIFailedException:
                EconomyFailedCount += 1
                if EconomyFailedCount >= 4:
                    logging.info("AutoAssetMigrator: Economy API failed while auto migrating assets, stopping")
                    #AddAssetToMigrationQueue(AssetId, bypassQueueLimit=False)
                    break
                else:
                    logging.info("AutoAssetMigrator: Economy API failed while auto migrating assets, retrying")
                    continue
            except NoPermissionException:
                logging.info(f"AutoAssetMigrator: No permission to migrate asset from Roblox, assetId: {AssetId}")
                continue
            except AssetDeliveryAPIFailedException:
                logging.info(f"AutoAssetMigrator: AssetDelivery API failed while migrating asset, assetId: {AssetId}")
                continue
            except AssetOnCooldownException:
                logging.info(f"AutoAssetMigrator: Asset is on cooldown, assetId: {AssetId}")
                continue
            except AssetNotAllowedException:
                logging.info(f"AutoAssetMigrator: Asset is not allowed, assetId: {AssetId}")
                continue
            except AssetNotFoundException:
                logging.info(f"AutoAssetMigrator: Asset not found, assetId: {AssetId}")
                continue
            except Exception as e:
                logging.info(f"AutoAssetMigrator: Unknown error while migrating asset, Exception: {str(e)} ,assetId: {AssetId}")
                continue
            except:
                logging.info(f"AutoAssetMigrator: Unknown error while migrating asset, assetId: {AssetId}")
                continue

        while True:
            # Migrating audios have a different queue
            if redis_controller.llen("migrate_audio_assets_queue") == 0:
                break
            AssetId : int = int(redis_controller.lpop("migrate_audio_assets_queue"))
            if AssetId <= 1:
                continue
            try:
                AssociatedPlaceId : int = int(redis_controller.get(f"audio_asset:{AssetId}:placeid"))
                if AssociatedPlaceId <= 1:
                    continue
            except:
                continue

            logging.info(f"AutoAssetMigrator: Auto migrating audio asset {AssetId}, {redis_controller.llen('migrate_audio_assets_queue')} assets left in queue")
            try:
                migrateAsset(AssetId, allowedTypes = [3], throwException=True, bypassCooldown = True, attemptSoundWithPlaceId = AssociatedPlaceId)
            except RatelimittedReachedException:
                logging.info("AutoAssetMigrator: Ratelimit reached while auto migrating assets, stopping")
                AddAudioAssetToAudioMigrationQueue(AssetId, bypassQueueLimit=False, placeId = AssociatedPlaceId)
                break
            except EconomyAPIFailedException:
                EconomyFailedCount += 1
                if EconomyFailedCount >= 4:
                    logging.info("AutoAssetMigrator: Economy API failed while auto migrating assets, stopping")
                    #AddAssetToMigrationQueue(AssetId, bypassQueueLimit=False)
                    break
                else:
                    logging.info("AutoAssetMigrator: Economy API failed while auto migrating assets, retrying")
                    continue
            except NoPermissionException:
                logging.info(f"AutoAssetMigrator: No permission to migrate asset from Roblox, assetId: {AssetId}")
                continue
            except AssetDeliveryAPIFailedException:
                logging.info(f"AutoAssetMigrator: AssetDelivery API failed while migrating asset, assetId: {AssetId}")
                continue
            except AssetOnCooldownException:
                logging.info(f"AutoAssetMigrator: Asset is on cooldown, assetId: {AssetId}")
                continue
            except AssetNotAllowedException:
                logging.info(f"AutoAssetMigrator: Asset is not allowed, assetId: {AssetId}")
                continue
            except AssetNotFoundException:
                logging.info(f"AutoAssetMigrator: Asset not found, assetId: {AssetId}")
                continue
            except Exception as e:
                logging.info(f"AutoAssetMigrator: Unknown error while migrating asset, Exception: {str(e)} ,assetId: {AssetId}")
                continue
            except:
                logging.info(f"AutoAssetMigrator: Unknown error while migrating asset, assetId: {AssetId}")
                continue

        redis_controller.delete("migrate_assets_lock")

                

@scheduler.task('interval', id='fix_thumbnails', seconds = 600, misfire_grace_time=60)
def fix_thumbnails():
    with scheduler.app.app_context():
        if redis_controller.get("fix_thumbnails") is not None:
            return
        redis_controller.set("fix_thumbnails", "busy", ex=60)
        from app.models.gameservers import GameServer
        from app.models.asset_thumbnail import AssetThumbnail
        from app.models.asset_version import AssetVersion
        from app.models.asset import Asset
        from app.models.user import User
        from app.models.user_thumbnail import UserThumbnail
        from app.models.place_icon import PlaceIcon
        from app.util.assetversion import GetLatestAssetVersion

        from app.routes.thumbnailer import TakeThumbnail, TakeUserThumbnail
        assetVersions = AssetVersion.query.filter(
            ~db.session.query(AssetThumbnail.asset_id).filter(
                AssetThumbnail.asset_id == AssetVersion.asset_id,
            ).filter(
                AssetThumbnail.asset_version_id == AssetVersion.version
            ).exists()
        ).join(Asset, Asset.id == AssetVersion.asset_id).filter(
            and_(
                Asset.moderation_status == 0,
                Asset.asset_type != AssetType.Place
            )
        ).distinct(AssetVersion.asset_id).order_by(AssetVersion.asset_id, AssetVersion.version.desc()).all()

        if len(assetVersions) > 0:
            AssetTypeBrokenCounter = {}
            logging.info(f"Found {len(assetVersions)} broken thumbnails")
            SuccessCount = 0
            for assetVersion in assetVersions:
                AssetObj : Asset = Asset.query.filter_by(id=assetVersion.asset_id).first()
                if AssetObj is None:
                    continue
                if AssetObj.asset_type == AssetType.Place:
                    continue
                if AssetObj.moderation_status == 0:
                    LatestVersion : AssetVersion = GetLatestAssetVersion(AssetObj)
                    if LatestVersion is not assetVersion:
                        continue
                    Result = TakeThumbnail(assetVersion.asset_id)
                    if Result == "Thumbnail request sent":
                        SuccessCount += 1
                    else:
                        if AssetObj.asset_type.name in AssetTypeBrokenCounter:
                            AssetTypeBrokenCounter[AssetObj.asset_type.name] += 1
                        else:
                            AssetTypeBrokenCounter[AssetObj.asset_type.name] = 1
                if SuccessCount >= 30:
                    logging.info(f"Stopping thumbnail fixer, reached 30 thumbnails fixed")
                    break
            
            for key, value in AssetTypeBrokenCounter.items():
                logging.info(f"Thumbnail fixer: {value} {key} assets failed to fix")
        users = User.query.filter(User.id.notin_(db.session.query(UserThumbnail.userid))).all()
        for user in users:
            TakeUserThumbnail(user.id)
        users = UserThumbnail.query.filter(or_(UserThumbnail.full_contenthash == None, UserThumbnail.headshot_contenthash == None)).all()
        for user in users:
            TakeUserThumbnail(user.userid)
        
        Places : list[Asset] = Asset.query.filter(Asset.asset_type == AssetType.Place).filter(Asset.id.notin_(db.session.query(PlaceIcon.placeid))).all()
        for PlaceObj in Places:
            TakeThumbnail(PlaceObj.id, isIcon=True)


@scheduler.task('interval', id='heartbeat', seconds=15, misfire_grace_time=10)
def heartbeat():
    with scheduler.app.app_context():
        if redis_controller.get("heartbeat") is not None:
            return # Another instance is already running
        redis_controller.set("heartbeat", "busy", ex=14)
        from app.models.gameservers import GameServer
        from app.models.placeserver_players import PlaceServerPlayer
        from app.models.placeservers import PlaceServer
        from app.models.user import User
        from app.services.gameserver_comm import perform_get, perform_post
        from app.routes.jobreporthandler import HandleUserTimePlayed
        import requests
        import time
        import threading

        def HandlePlayerDeletion( playerObj : PlaceServerPlayer, placeId : int = None):
            if placeId is not None:
                try:
                    TotalTimePlayed = (datetime.datetime.utcnow() - playerObj.joinTime).total_seconds()
                    userObj : User = User.query.filter_by(id=playerObj.userid).first()
                    HandleUserTimePlayed(userObj, TotalTimePlayed, serverUUID = str(playerObj.serveruuid), placeId = placeId)
                except Exception as e:
                    logging.warn(f"Failed to handle player deletion, Exception: {str(e)}")
            db.session.delete(playerObj)
            db.session.commit() 

        def RefreshServerInfo( server : GameServer ):
            with scheduler.app.app_context():
                server : GameServer = server
                startTime = time.time()
                statsRequest = None
                try:
                    statsRequest = perform_get(
                        TargetGameserver = server,
                        Endpoint = "stats",
                        RequestTimeout = 6
                    )
                except Exception as e:
                    # Mark the server as offline
                    server.isRCCOnline = False
                    server.thumbnailQueueSize = 0
                    server.RCCmemoryUsage = 0
                    server.heartbeatResponseTime = 0
                    if server.lastHeartbeat < datetime.datetime.utcnow() - datetime.timedelta(seconds=90):
                        # Delete all placeservers
                        GhostServers = PlaceServer.query.filter_by(originServerId=server.serverId).all()
                        for GhostServer in GhostServers:
                            GhostPlayers = PlaceServerPlayer.query.filter_by(serveruuid=GhostServer.serveruuid).all()
                            for GhostPlayer in GhostPlayers:
                                HandlePlayerDeletion(GhostPlayer, placeId = GhostServer.serverPlaceId)
                            db.session.delete(GhostServer)
                        db.session.commit()
                        return
                if statsRequest is not None and statsRequest.status_code != 200:
                    # Mark the server as offline
                    server.isRCCOnline = False
                    server.thumbnailQueueSize = 0
                    server.RCCmemoryUsage = 0
                    server.heartbeatResponseTime = 0
                    if server.lastHeartbeat < datetime.datetime.utcnow() - datetime.timedelta(seconds=90):
                        # Delete all placeservers
                        GhostServers = PlaceServer.query.filter_by(originServerId=server.serverId).all()
                        for GhostServer in GhostServers:
                            GhostPlayers = PlaceServerPlayer.query.filter_by(serveruuid=GhostServer.serveruuid).all()
                            for GhostPlayer in GhostPlayers:
                                HandlePlayerDeletion(GhostPlayer, placeId = GhostServer.serverPlaceId)
                            db.session.delete(GhostServer)
                        db.session.commit()
                        return
                if statsRequest is not None and statsRequest.status_code == 200:
                    endTime = time.time()
                    server.lastHeartbeat = datetime.datetime.utcnow()
                    server.heartbeatResponseTime = endTime - startTime
                    stats = statsRequest.json()
                    server.isRCCOnline = stats["RCCOnline"]
                    server.thumbnailQueueSize = stats["ThumbnailQueueSize"]
                    server.RCCmemoryUsage = stats["RCCMemoryUsage"]
                    db.session.commit()

                    if "RunningJobs" in stats:
                        for RunningJob in stats["RunningJobs"]:
                            PlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serveruuid = RunningJob).first()
                            if PlaceServerObj is None:
                                logging.debug(f"CloseJob : Closing {RunningJob} because PlaceServer does not exist in database, Owner: {server.serverId} / {server.serverName}")
                                try:
                                    CloseJobRequest = perform_post(
                                        TargetGameserver = server,
                                        Endpoint = "CloseJob",
                                        JSONData = {
                                            "jobid": RunningJob
                                        }
                                    )
                                except Exception as e:
                                    continue
        
        refresh_server_thread_list : list[threading.Thread] = []
        servers : list[GameServer] = GameServer.query.all()
        for server in servers:
            refresh_server_thread_list.append(threading.Thread(target=RefreshServerInfo, args=(server,)))
        for thread in refresh_server_thread_list:
            thread.start()
        for thread in refresh_server_thread_list:
            thread.join()
        
        GhostServers : list[PlaceServer] = PlaceServer.query.filter(PlaceServer.lastping < datetime.datetime.utcnow() - datetime.timedelta(seconds=60)).all()
        for GhostServer in GhostServers:
            GhostPlayers = PlaceServerPlayer.query.filter_by(serveruuid=GhostServer.serveruuid).all()
            for GhostPlayer in GhostPlayers:
                HandlePlayerDeletion(GhostPlayer, placeId = GhostServer.serverPlaceId)
            db.session.delete(GhostServer)

        GhostPlayers : list[PlaceServerPlayer] = PlaceServerPlayer.query.filter(PlaceServerPlayer.lastHeartbeat < datetime.datetime.utcnow() - datetime.timedelta(seconds=120)).all()
        for GhostPlayer in GhostPlayers:
            db.session.delete(GhostPlayer)

        db.session.commit()

        redis_controller.delete("heartbeat")


