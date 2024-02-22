from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort
from config import Config
import requests
import hashlib
import os
import random
import logging
import json
import time
from datetime import datetime
from app.util import auth, websiteFeatures, assetversion, redislock, s3helper, RBXMesh
from app.enums.AssetType import AssetType
from app.extensions import db, redis_controller, get_remote_address, csrf

from app.models.asset import Asset
from app.models.asset_version import AssetVersion

from app.models.user import User
from app.models.user_avatar import UserAvatar
from app.models.place import Place
from app.enums.PlaceRigChoice import PlaceRigChoice
from app.models.user_avatar_asset import UserAvatarAsset
from app.routes.thumbnailer import TakeThumbnail
from app.models.gameservers import GameServer
from app.models.package_asset import PackageAsset

config = Config()
AssetRoute = Blueprint('asset', __name__, url_prefix='/')

if config.USE_LOCAL_STORAGE:
    if not os.path.exists(config.AWS_S3_DOWNLOAD_CACHE_DIR):
        os.makedirs(config.AWS_S3_DOWNLOAD_CACHE_DIR)
    @AssetRoute.route("/cdn_local/<path:filehash>", methods=["GET"])
    def LocalCDN(filehash):
        if not os.path.exists(config.AWS_S3_DOWNLOAD_CACHE_DIR + "/" + filehash):
            return abort(404)
        with open(config.AWS_S3_DOWNLOAD_CACHE_DIR + "/" + filehash, "rb") as f:
            FileContents = f.read()
        resp = make_response(FileContents,200)
        resp.headers['Content-Type'] = 'application/octet-stream'
        return resp

# Special Route used for rendering clothing
@AssetRoute.route('/Asset/SpecialCharacterFetch', methods=['GET'])
def specialCharacterFetch():
    assetId = request.args.get('assetId')
    if assetId is None:
        return 'Invalid request',400
    assetObj : Asset = Asset.query.filter_by(id=assetId).first()
    if assetObj is None:
        return 'Invalid request',400
    if assetObj.asset_type == AssetType.Package:
        # Get the package assets
        packageAssets : list[PackageAsset] = PackageAsset.query.filter_by(package_asset_id=assetObj.id).all()
        FinalAvatarData = f"{config.BaseURL}/Asset/BodyColors.ashx?userId=0;"
        for packageAsset in packageAssets:
            FinalAvatarData += f"{config.BaseURL}/Asset/?id={str(packageAsset.asset_id)};"
        return FinalAvatarData,200
    
    return f"{config.BaseURL}/Asset/BodyColors.ashx?userId=0;{config.BaseURL}/Asset/?id={str(assetId)}",200

@AssetRoute.route('/Asset/CharacterFetch.ashx', methods=['GET'])
def characterFetch():
    userId = request.args.get('userId', default=5973, type=int)
    if userId is None:
        userId = 5973
    isLegacy = request.args.get('legacy', default=None, type=int) == 1

    user = User.query.filter_by(id=userId).first()
    if user is None:
        return 'https://www.syntax.eco/Asset/BodyColors.ashx?userId=5973;https://www.syntax.eco/Asset/?id=23882;https://www.syntax.eco/Asset/?id=28253;',200
    serverPlaceId = request.args.get('serverplaceid', default=None, type=int)
    
    avatar = UserAvatar.query.filter_by(user_id=userId).first()
    if avatar is None:
        avatar = UserAvatar(user_id=userId)
        db.session.add(avatar)
        db.session.commit()
    
    avatarAssets = UserAvatarAsset.query.filter_by(user_id=userId).all()
    
    FinalAvatarData = f"{config.BaseURL}/Asset/BodyColors.ashx?userId={str(userId)};"
    for avatarAsset in avatarAssets:
        asset : Asset = Asset.query.filter_by(id=avatarAsset.asset_id).first()
        if asset is None:
            continue
        if asset.moderation_status != 0:
            continue
        if asset.asset_type == AssetType.Gear and (serverPlaceId is not None or isLegacy):
            continue #  Gears are not allowed in games for now

        if not isLegacy or asset.asset_type not in [AssetType.Shirt, AssetType.TShirt, AssetType.Pants, AssetType.Head, AssetType.Hat, AssetType.HairAccessory, AssetType.FaceAccessory, AssetType.NeckAccessory, AssetType.ShoulderAccessory, AssetType.FrontAccessory, AssetType.BackAccessory, AssetType.WaistAccessory, AssetType.Gear, AssetType.Face]:
            FinalAvatarData += f"{config.BaseURL}/Asset/?id={str(asset.id)};"
        else:
            FinalAvatarData += f"{config.BaseURL}/Asset/legacy/?id={str(asset.id)};"
    
    return FinalAvatarData,200

@AssetRoute.route('/Asset/BodyColors.ashx', methods=['GET'])
def bodyColors():
    userId = request.args.get('userId')
    if userId is None:
        return 'Invalid request',400

    user = User.query.filter_by(id=userId).first()
    if user is None:
        if userId == '0':
            resp = make_response(f"""<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
        <External>null</External>
        <External>nil</External>
        <Item class="BodyColors">
            <Properties>
            <int name="HeadColor">1001</int>
            <int name="LeftArmColor">1001</int>
            <int name="LeftLegColor">1001</int>
            <string name="Name">Body Colors</string>
            <int name="RightArmColor">1001</int>
            <int name="RightLegColor">1001</int>
            <int name="TorsoColor">1001</int>
            <bool name="archivable">true</bool>
            </Properties>
        </Item>
        </roblox>
        """,200)
            resp.headers['Content-Type'] = 'text/xml'
            return resp
        return 'Invalid request',400
    
    avatar : UserAvatar = UserAvatar.query.filter_by(user_id=userId).first()
    if avatar is None:
        return 'Invalid request',400
    
    resp = make_response(f"""<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
  <External>null</External>
  <External>nil</External>
  <Item class="BodyColors">
    <Properties>
      <int name="HeadColor">{str(avatar.head_color_id)}</int>
      <int name="LeftArmColor">{str(avatar.left_arm_color_id)}</int>
      <int name="LeftLegColor">{str(avatar.left_leg_color_id)}</int>
      <string name="Name">Body Colors</string>
      <int name="RightArmColor">{str(avatar.right_arm_color_id)}</int>
      <int name="RightLegColor">{str(avatar.right_leg_color_id)}</int>
      <int name="TorsoColor">{str(avatar.torso_color_id)}</int>
      <bool name="archivable">true</bool>
    </Properties>
  </Item>
</roblox>
""",200)
    resp.headers['Content-Type'] = 'text/xml'
    return resp

@AssetRoute.route('/v1.1/avatar-fetch/custom', methods=['GET'])
def AvatarFetchCustom():
    assetId = request.args.get('assetId')
    if assetId is None:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400
    assetObj : Asset = Asset.query.filter_by(id=assetId).first()
    if assetObj is None:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400
    AvatarAssetsList = []
    if assetObj.asset_type == AssetType.Package:
        # Get the package assets
        packageAssets : list[PackageAsset] = PackageAsset.query.filter_by(package_asset_id=assetObj.id).all()
        for packageAsset in packageAssets:
            AvatarAssetsList.append(packageAsset.asset_id)
    else:
        AvatarAssetsList.append(assetObj.id)
    return jsonify({
        "resolvedAvatarType": "R6",
        "accessoryVersionIds": AvatarAssetsList,
        "equippedGearVersionIds": [],
        "backpackGearVersionIds": [],
        "bodyColors": {
            "HeadColor": 1001,
            "LeftArmColor": 1001,
            "LeftLegColor": 1001,
            "RightArmColor": 1001,
            "RightLegColor": 1001,
            "TorsoColor": 1001
        },
        "animations": {},
        "scales": {
            "height": 1,
            "width": 1,
            "head": 1,
            "depth": 1,
            "proportion": 0,
            "bodyType": 0
        }
    })
@AssetRoute.route('/v1/avatar-fetch/', methods=["GET"])
def AvatarFetchV1():
    UserId = request.args.get('userId', None, int)
    PlaceId = request.args.get('placeId', None, int)
    if UserId is None:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400
    if PlaceId is not None and PlaceId <= 0:
        PlaceId = None
    
    UserObj : User = User.query.filter_by(id=UserId).first()
    if UserObj is None:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400
    
    PlayerAvatar : UserAvatar = UserAvatar.query.filter_by(user_id=UserId).first()
    AvatarAssets : list[UserAvatarAsset] = UserAvatarAsset.query.filter_by(user_id=UserId).all()
    assetAndAssetTypeIds : list = []
    equippedGearVersionIds : list = []
    AvatarAssetsList : list = []

    for AvatarAsset in AvatarAssets:
        if AvatarAsset.asset.asset_type == AssetType.Gear and PlaceId is not None:
            continue
        if AvatarAsset.asset.moderation_status != 0:
            continue
        if AvatarAsset.asset.asset_type == AssetType.Gear:
            equippedGearVersionIds.append(AvatarAsset.asset_id)
            continue
        AvatarAssetsList.append(AvatarAsset.asset_id)
        assetAndAssetTypeIds.append({
            "assetId": AvatarAsset.asset_id,
            "assetTypeId": AvatarAsset.asset.asset_type.value
        })
    resolvedAvatarType = "R6" if not PlayerAvatar.r15 else "R15"
    if PlaceId is not None:
        PlaceObj : Place = Place.query.filter_by(placeid = PlaceId).first()
        if PlaceObj is None:
            return jsonify({
                "success": False,
                "error": "Invalid request"
            }),400
        
        if PlaceObj.rig_choice == PlaceRigChoice.ForceR6:
            resolvedAvatarType = "R6"
        elif PlaceObj.rig_choice == PlaceRigChoice.ForceR15:
            resolvedAvatarType = "R15"

    return jsonify({
        "resolvedAvatarType": resolvedAvatarType,
        "equippedGearVersionIds": equippedGearVersionIds,
        "backpackGearVersionIds": equippedGearVersionIds,
        "accessoryVersionIds": AvatarAssetsList,
        "assetAndAssetTypeIds": assetAndAssetTypeIds,
        "bodyColors": {
            "headColorId": PlayerAvatar.head_color_id,
            "leftArmColorId": PlayerAvatar.left_arm_color_id,
            "leftLegColorId": PlayerAvatar.left_leg_color_id,
            "rightArmColorId": PlayerAvatar.right_arm_color_id,
            "rightLegColorId": PlayerAvatar.right_leg_color_id,
            "torsoColorId": PlayerAvatar.torso_color_id,

            "HeadColor": PlayerAvatar.head_color_id,
            "LeftArmColor": PlayerAvatar.left_arm_color_id,
            "LeftLegColor": PlayerAvatar.left_leg_color_id,
            "RightArmColor": PlayerAvatar.right_arm_color_id,
            "RightLegColor": PlayerAvatar.right_leg_color_id,
            "TorsoColor": PlayerAvatar.torso_color_id
        },
        "animationAssetIds": {},
        "scales": {
            "height": PlayerAvatar.height_scale,
            "width": PlayerAvatar.width_scale,
            "head": PlayerAvatar.head_scale,
            "depth": 1,
            "proportion": PlayerAvatar.proportion_scale,
            "bodyType": PlayerAvatar.body_type_scale,

            "Height": PlayerAvatar.height_scale,
            "Width": PlayerAvatar.width_scale,
            "Head": PlayerAvatar.head_scale,
            "Depth": 1,
            "Proportion": PlayerAvatar.proportion_scale,
            "BodyType": PlayerAvatar.body_type_scale
        },
        "emotes": []
    })


@AssetRoute.route('/v1.1/avatar-fetch/', methods=["GET"])
def AvatarFetch():
    UserId = request.args.get('userId', None, int)
    PlaceId = request.args.get('placeId', None, int)
    if UserId is None:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400
    if PlaceId is not None and PlaceId <= 0:
        PlaceId = None
    
    UserObj : User = User.query.filter_by(id=UserId).first()
    if UserObj is None:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400
    
    PlayerAvatar : UserAvatar = UserAvatar.query.filter_by(user_id=UserId).first()
    AvatarAssets : list[UserAvatarAsset] = UserAvatarAsset.query.filter_by(user_id=UserId).all()
    AvatarAssetsList : list = []
    AvatarGearsList : list = []
    assetAndAssetTypeIds : list = []
    for AvatarAsset in AvatarAssets:
        if AvatarAsset.asset.asset_type == AssetType.Gear and PlaceId is not None:
            continue
        if AvatarAsset.asset.moderation_status != 0:
            continue
        if AvatarAsset.asset.asset_type == AssetType.Gear:
            AvatarGearsList.append(AvatarAsset.asset_id)
            continue
        AvatarAssetsList.append(AvatarAsset.asset_id)
        assetAndAssetTypeIds.append({
            "assetId": AvatarAsset.asset_id,
            "assetTypeId": AvatarAsset.asset.asset_type.value
        })

    avatarTypeOverwrite = None
    if PlaceId is not None:
        PlaceObj : Place = Place.query.filter_by(placeid = PlaceId).first()
        if PlaceObj is not None:
            if PlaceObj.rig_choice == PlaceRigChoice.ForceR6:
                avatarTypeOverwrite = "R6"
            elif PlaceObj.rig_choice == PlaceRigChoice.ForceR15:
                avatarTypeOverwrite = "R15"

    return jsonify({
        "resolvedAvatarType": avatarTypeOverwrite if avatarTypeOverwrite is not None else ( "R6" if not PlayerAvatar.r15 else "R15" ),
        "accessoryVersionIds": AvatarAssetsList,
        "equippedGearVersionIds": AvatarGearsList,
        "backpackGearVersionIds": AvatarGearsList,
        "assetAndAssetTypeIds": assetAndAssetTypeIds,
        "bodyColors": {
            "HeadColor": PlayerAvatar.head_color_id,
            "LeftArmColor": PlayerAvatar.left_arm_color_id,
            "LeftLegColor": PlayerAvatar.left_leg_color_id,
            "RightArmColor": PlayerAvatar.right_arm_color_id,
            "RightLegColor": PlayerAvatar.right_leg_color_id,
            "TorsoColor": PlayerAvatar.torso_color_id,

            "headColorId": PlayerAvatar.head_color_id,
            "leftArmColorId": PlayerAvatar.left_arm_color_id,
            "leftLegColorId": PlayerAvatar.left_leg_color_id,
            "rightArmColorId": PlayerAvatar.right_arm_color_id,
            "rightLegColorId": PlayerAvatar.right_leg_color_id,
            "torsoColorId": PlayerAvatar.torso_color_id
        },
        "animations": {},
        "scales": {
            "Height": PlayerAvatar.height_scale,
            "Width": PlayerAvatar.width_scale,
            "Head": PlayerAvatar.head_scale,
            "Depth": 1,
            "Proportion": PlayerAvatar.proportion_scale,
            "BodyType": PlayerAvatar.body_type_scale
        },
        "bodyColorsUrl": f"{config.BaseURL}/Asset/BodyColors.ashx?userId={str(UserId)}",
        "emotes": []
    })

class InvalidAssetHashException(Exception):
    """Raised when the asset hash is invalid"""
    pass

def CreateFakeAsset( AssetName = "Temporary Asset", Expiration = 600, AssetFileHash = "" ) -> int:
    """
        Creates a fake asset in redis and returns a temporary asset id
    """
    if AssetFileHash == "":
        raise InvalidAssetHashException("AssetFileHash cannot be empty")
    TemporaryAssetId : int = random.randint(1000000000,9999999999)
    redis_controller.set(f"temp_asset:{str(TemporaryAssetId)}", json.dumps({
        "name": AssetName,
        "hash": AssetFileHash
    }), ex=Expiration)
    return TemporaryAssetId

class RatelimittedReachedException(Exception):
    """Raised when the ratelimit has been reached from the roblox api"""
    pass
class AssetNotFoundException(Exception):
    """Raised when the asset has not been found"""
    pass
class AssetNotAllowedException(Exception):
    """Raised when the asset is not allowed to be migrated"""
    pass

def GetRandomProxy():
    """
        Gets a random proxy from the proxy set in redis
    """
    ProxyList = list(redis_controller.smembers("assetmigrator_proxies"))
    if len(ProxyList) == 0:
        return None
    return f"http://{random.choice(ProxyList)}"

def GetOriginalAssetInfo(assetId, throwException = False, attempt = 0):
    """
        Gets the original asset info from the roblox api
    """
    try:
        if redis_controller.get(f"FetchAssetInfo_v2:EconomyAPI:{str(assetId)}:Blocked") is not None:
            if throwException:
                raise AssetNotAllowedException("The asset is not allowed to be migrated")
            return None
        if redis_controller.get(f"FetchAssetInfo:EconomyAPI:{str(assetId)}") is not None:
            return json.loads(redis_controller.get(f"FetchAssetInfo:EconomyAPI:{str(assetId)}"))
        if config.ASSETMIGRATOR_USE_PROXIES:
            assignedProxy = GetRandomProxy()
            if assignedProxy is not None:
                assetInfoReq = requests.get(
                    f"https://economy.roblox.com/v2/assets/{str(assetId)}/details",
                    proxies = {
                        "http": assignedProxy,
                        "https": assignedProxy
                    }
                )
            else:
                logging.warning("No proxies available, using default ip")
                assetInfoReq = requests.get(
                    f"https://economy.roblox.com/v2/assets/{str(assetId)}/details"
                )
        else:
            assetInfoReq = requests.get(
                f"https://economy.roblox.com/v2/assets/{str(assetId)}/details"
            )
        if assetInfoReq.status_code != 200:
            if assetInfoReq.status_code == 429:
                if attempt < 2:
                    time.sleep(1)
                    return GetOriginalAssetInfo(assetId, attempt=attempt+1, throwException=throwException)
                else:
                    if throwException:
                        raise RatelimittedReachedException("The ratelimit has been reached")
                    else:
                        return None
            elif assetInfoReq.status_code == 400:
                redis_controller.set(f"FetchAssetInfo_v2:EconomyAPI:{str(assetId)}:Blocked", "true", ex=60 * 60 * 24 * 7)
                if throwException:
                    raise AssetNotFoundException("The asset has not been found")
            return None
    except:
        return None
    assetInfo = assetInfoReq.json()
    redis_controller.set(f"FetchAssetInfo:EconomyAPI:{str(assetId)}", json.dumps(assetInfo), ex=60 * 60 * 24 * 7) # Cache this information for 7 days since it's most likely not going to change
    return assetInfo

class NoPermissionException(Exception):
    """Raised when Roblox does not allow us to download the asset"""
    pass
class AssetDeliveryAPIFailedException(Exception):
    """Raised when the asset delivery api fails"""
    pass
class AssetOnCooldownException(Exception):
    """Raised when the asset was recently attempted to be migrated but failed"""
    pass
class EconomyAPIFailedException(Exception):
    """Raised when the economy api fails"""
    pass
class CatalogAPIFailedException(Exception):
    """Raised when the catalog api fails"""
    pass

def GetBundleInformation( bundleId : int ) -> dict:
    """
        Gets the bundle information from the catalog api
    """
    if redis_controller.get(f"FetchBundleInfo_v2:CatalogAPI:{str(bundleId)}") is not None:
        return json.loads(redis_controller.get(f"FetchBundleInfo_v2:CatalogAPI:{str(bundleId)}"))
    bundleInfoReq = requests.get(f"https://catalog.roblox.com/v1/bundles/{str(bundleId)}/details")
    if bundleInfoReq.status_code != 200:
        if bundleInfoReq.status_code == 429:
            raise RatelimittedReachedException("The ratelimit has been reached")
        elif bundleInfoReq.status_code == 400:
            raise AssetNotFoundException("The asset has not been found")
        raise CatalogAPIFailedException(f"The catalog api failed with status code {str(bundleInfoReq.status_code)}")
    bundleInfo = bundleInfoReq.json()
    redis_controller.set(f"FetchBundleInfo_v2:CatalogAPI:{str(bundleId)}", json.dumps(bundleInfo), ex=60 * 60 * 24 * 7) # Cache this information for 7 days since it's most likely not going to change
    return bundleInfo

class MigrateBundleException(Exception):
    """Raised when the bundle migration fails"""
    pass
class PackageLinkAlreadyExistsException(Exception):
    """Raised when the package link already exists"""
    pass

def MigrateBundle( bundleId : int ) -> Asset:
    """
        Migrates a bundle from Roblox
    """
    bundleInfo : dict = GetBundleInformation(bundleId)
    
    AllAssets : list[int] = []
    for item in bundleInfo["items"]:
        if item["type"] != "Asset":
            continue
        AllAssets.append(item["id"])

    MigratedAssets : list[Asset] = [] 
    # Migrate all the assets first before we create the package asset
    for assetId in AllAssets:
        try:
            assetObj : Asset = migrateAsset(
                assetid = assetId,
                forceMigration = True,
                keepRobloxId = False,
                throwException = True,
                assetVersionId=1,
                creatorId=1
            )
            MigratedAssets.append(assetObj)
            # Check if the package link already exists
            if PackageAsset.query.filter_by(asset_id=assetObj.id).first() is not None:
                raise PackageLinkAlreadyExistsException("The package link already exists")

        except RatelimittedReachedException:
            # We should try again
            time.sleep(1)
            return MigrateBundle(bundleId)
        except AssetNotFoundException:
            # This shouldnt happen
            pass
        except AssetNotAllowedException:
            # This shouldnt happen
            pass
        except NoPermissionException:
            # This shouldnt happen
            pass
        except AssetDeliveryAPIFailedException:
            # We should try again
            time.sleep(1)
            return MigrateBundle(bundleId)
        except Exception as e:
            logging.error(f"Failed to migrate asset {str(assetId)}, error: {str(e)}")
            raise MigrateBundleException(f"Failed to migrate asset {str(assetId)}, error: {str(e)}")
    
    # Create the package asset
    NewPackageAsset : Asset = Asset(
        name = bundleInfo["name"],
        description = bundleInfo["description"],
        asset_type = AssetType.Package,
        moderation_status = 0,
        creator_id = 1,
    )
    db.session.add(NewPackageAsset)
    db.session.commit()

    # Get the sha512 of the package assets ids and create a new asset version
    Content = ""
    for asset in MigratedAssets:
        Content += str(asset.id)
    Content += str(NewPackageAsset.id)

    NewPackageAssetHash = hashlib.sha512(Content.encode("utf-8")).hexdigest()
    assetversion.CreateNewAssetVersion(NewPackageAsset, NewPackageAssetHash)

    # Create the package link
    for asset in MigratedAssets:
        PackageLink = PackageAsset(
            asset_id = asset.id,
            package_asset_id = NewPackageAsset.id
        )
        db.session.add(PackageLink)
    db.session.commit()
    TakeThumbnail(NewPackageAsset.id)

    return NewPackageAsset


def AddAssetToMigrationQueue( assetId : int, bypassQueueLimit : bool = False ) -> bool:
    """
        Adds an asset to the migration queue so it can be migrated later
    """
    if redis_controller.get(f"asset_migrate_v2:{str(assetId)}:blocked") is not None:
        return False
    if not bypassQueueLimit:
        if redis_controller.llen("migrate_assets_queue") >= 900:
            return False
        # Make sure the asset is not already in the queue
        if redis_controller.lrange("migrate_assets_queue", 0, -1).count(str(assetId)) > 0:
            return False
    
    redis_controller.rpush("migrate_assets_queue", str(assetId))
    return True

def AddAudioAssetToAudioMigrationQueue( assetId : int, bypassQueueLimit : bool = False, placeId : int = -1 ) -> bool:
    """
        Adds an audio asset to the migration queue so it can be migrated later
    """
    if placeId < 0:
        raise Exception("Invalid place id")
    
    if not bypassQueueLimit:
        if redis_controller.llen("migrate_audio_assets_queue") >= 900:
            return False
        # Make sure the asset is not already in the queue
        if redis_controller.lrange("migrate_audio_assets_queue", 0, -1).count(str(assetId)) > 0:
            return False
    
    redis_controller.rpush("migrate_audio_assets_queue", str(assetId))
    redis_controller.set(f"audio_asset:{str(assetId)}:placeid", str(placeId), ex=60 * 60 * 24 * 7)

    return True


def getAudioData_V2( assetId : int, placeId : int = None ) -> bytes:
    if placeId is None:
        placeId = 1818

    RequestSession : requests.Session = requests.Session()
    RequestSession.headers.update({
        "User-Agent": "Roblox/WinInet",
        "Accept": "*/*",
        "Roblox-Browser-Asset-Request": "false",
        "Roblox-Place-Id": str(placeId)
    })
    RequestSession.cookies.update({
        ".ROBLOSECURITY": config.ASSETMIGRATOR_ROBLOSECURITY
    })

    try:
        AssetFetchReq : requests.Response = RequestSession.get(
            url = f"https://assetdelivery.roblox.com/v1/asset/?id={str(assetId)}"
        )
    except Exception as e:
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, error: {str(e)}")
    
    if AssetFetchReq.status_code != 200:
        if AssetFetchReq.status_code == 429:
            raise RatelimittedReachedException("The ratelimit has been reached")
        if AssetFetchReq.status_code == 403:
            raise NoPermissionException(f"Forbidden from downloading asset {str(assetId)}, status code: {str(AssetFetchReq.status_code)}")
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, status code: {str(AssetFetchReq.status_code)}")
    
    return AssetFetchReq.content

def getAudioData( assetId : int, placeid : int = None ) -> bytes:
    """
        [ DEPRECATED ] ( Please use getAudioData_V2 )
        Downloads the sound data from roblox assetdelivery api
    """ 

    if placeid is None:
        placeid = findPlaceId(assetId)

    RequestSession : requests.Session = requests.Session()
    RequestSession.headers.update({
        "User-Agent": "Roblox/WinInet",
        "Accept": "*/*",
        "Roblox-Browser-Asset-Request": "false",
        "Roblox-Place-Id": str(placeid)
    })
    RequestSession.cookies.update({
        ".ROBLOSECURITY": config.ASSETMIGRATOR_ROBLOSECURITY
    })

    JSONPayload = [{
        "assetId": assetId,
        "assetType": "Audio",
        "requestId": "0"
    }]

    try:
        AssetFetchReq : requests.Response = RequestSession.post(
            f"https://assetdelivery.roblox.com/v2/assets/batch", 
            json = JSONPayload # We can't use proxies on this since Roblox deletes cookies when using a different continent
        )
    except Exception as e:
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, error: {str(e)}")
    if AssetFetchReq.status_code != 200:
        if AssetFetchReq.status_code == 429:
            raise RatelimittedReachedException("The ratelimit has been reached")
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, status code: {str(AssetFetchReq.status_code)}")
    AssetLocations = AssetFetchReq.json()
    if not AssetLocations or len(AssetLocations) == 0:
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, no locations found")
    RequestObj : dict = AssetLocations[0]
    if RequestObj.get("locations") and RequestObj["locations"][0].get("location"):
        AudioURL = RequestObj["locations"][0]["location"]
    else:
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, no locations found")
    
    try:
        AssetCDNFetchReq : requests.Response = RequestSession.get(AudioURL)
    except Exception as e:
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, error: {str(e)}")
    if AssetCDNFetchReq.status_code != 200:
        raise AssetDeliveryAPIFailedException(f"Failed to fetch asset {str(assetId)}, status code: {str(AssetCDNFetchReq.status_code)}")

    return AssetCDNFetchReq.content

def findPlaceId( assetId : int ) -> int:
    """
        Finds a place which belongs to the asset creator so we can download the asset
    """
    assetInfo = GetOriginalAssetInfo(assetId, throwException=True)
    CreatorId = assetInfo["Creator"]["Id"]
    CreatorType = assetInfo["Creator"]["CreatorType"]
    if CreatorType == "User":
        # Find a place which belongs to the user
        PlaceInfo = requests.get(f"https://games.roblox.com/v2/users/{str(CreatorId)}/games")
        if PlaceInfo.status_code != 200:
            raise AssetNotFoundException(f"Failed to find a place which belongs to the asset creator, status code: {str(PlaceInfo.status_code)}")
        PlaceInfo = PlaceInfo.json()
        for Place in PlaceInfo["data"]:
            return Place["rootPlace"]["id"]
        raise AssetNotFoundException(f"Failed to find a place which belongs to the asset creator")
    elif CreatorType == "Group":
        # Find a place which belongs to the group
        PlaceInfo = requests.get(f"https://games.roblox.com/v2/groups/{str(CreatorId)}/gamesV2")
        if PlaceInfo.status_code != 200:
            raise AssetNotFoundException(f"Failed to find a place which belongs to the asset creator, status code: {str(PlaceInfo.status_code)}")
        PlaceInfo = PlaceInfo.json()
        for Place in PlaceInfo["data"]:
            return Place["rootPlace"]["id"]
        raise AssetNotFoundException(f"Failed to find a place which belongs to the asset creator")
    else:
        raise AssetNotFoundException(f"Failed to find a place which belongs to the asset creator")

def migrateAsset( assetid : int, forceMigration : bool = False, allowedTypes = [1,3,4,5,10,13,24,39,40,50,51,52,53,54,55,56], creatorId : int = 2, keepRobloxId : bool = True, migrateInfo : bool = True, attempt : int = 0, throwException : bool = False, allowBackgroundMigration : bool = False, assetVersionId : int = None, bypassCooldown : bool = False, attemptSoundWithPlaceId : int = -1 ) -> Asset:
    asset = Asset.query.filter_by(id=assetid).first()
    if asset is not None:
        return asset
    if redis_controller.get(f"asset_migrate_v2:{str(assetid)}:blocked") is not None and not bypassCooldown:
        if throwException:
            raise AssetOnCooldownException("Asset is on cooldown")
        return None
    
    try:
        assetInfo = GetOriginalAssetInfo(assetid, throwException=True)
    except RatelimittedReachedException:
        if allowBackgroundMigration:
            AddAssetToMigrationQueue(assetid)
        if throwException:
            raise RatelimittedReachedException("The ratelimit has been reached")
        return None
    except AssetNotFoundException:
        if throwException:
            raise AssetNotFoundException("The asset has not been found")
        return None
    except AssetNotAllowedException:
        if throwException:
            raise AssetNotAllowedException("The asset is not allowed to be migrated")
        return None
    if assetInfo is None:
        if allowBackgroundMigration:
            AddAssetToMigrationQueue(assetid)
        if throwException:
            raise EconomyAPIFailedException("Failed to get asset information")
        return None
    
    if assetInfo['AssetTypeId'] not in allowedTypes and not forceMigration:
        if throwException:
            raise AssetNotAllowedException("Asset is not allowed to be migrated")
        return None
    
    if assetInfo['AssetTypeId'] == 3:
        if attemptSoundWithPlaceId == -1:
            try:
                robloxAsset = requests.get(f"https://api.hyra.io/audio/{str(assetid)}")
            except:
                if throwException:
                    raise AssetDeliveryAPIFailedException("Failed to get asset from hyra")
                return None
            if robloxAsset.status_code != 200:
                if robloxAsset.status_code != 429:
                    redis_controller.setex(f"asset_migrate_v2:{str(assetid)}:blocked", 60 * 60 * 24, "true")
                    if throwException:
                        raise NoPermissionException("Roblox does not allow us to download this asset")
                    return None
                #logging.error(f"Failed to download asset {assetid}")
                if allowBackgroundMigration:
                    AddAssetToMigrationQueue(assetid)
                if throwException:
                    raise RatelimittedReachedException("Rate limit reached")
                return None
            else:
                # We got the asset from hyra, it should return a mp3 file in bytes
                robloxAssetContent = robloxAsset.content
                asset = Asset(roblox_asset_id=assetid, force_asset_id=assetid, creator_id=creatorId,asset_type=AssetType.Audio, name=f"Asset {assetid}", description="Migrated from Roblox", asset_genre=1, moderation_status=0, created_at=datetime.utcnow(), updated_at=datetime.utcnow())
                db.session.add(asset)
                try:
                    db.session.commit()
                except:
                    # Race condition, lets try again
                    return migrateAsset(assetid, forceMigration, allowedTypes, creatorId, keepRobloxId, migrateInfo, attempt+1, throwException, allowBackgroundMigration, assetVersionId)
                
                ContentHash = hashlib.sha512(robloxAssetContent).hexdigest()
                s3helper.UploadBytesToS3(robloxAssetContent, ContentHash)
                assetVersion = assetversion.CreateNewAssetVersion(asset, ContentHash)
                TakeThumbnail(asset.id)
                return asset
        else:
            try:
                robloxAssetContent = getAudioData_V2(assetid, attemptSoundWithPlaceId)
            except RatelimittedReachedException:
                if throwException:
                    raise RatelimittedReachedException("The ratelimit has been reached")
                return None
            except Exception as e:
                if throwException:
                    raise e
                return None
            
            asset = Asset(roblox_asset_id=assetid, force_asset_id=assetid, creator_id=creatorId,asset_type=AssetType.Audio, name=f"Asset {assetid}", description="Migrated from Roblox", asset_genre=1, moderation_status=0, created_at=datetime.utcnow(), updated_at=datetime.utcnow())
            db.session.add(asset)
            try:
                db.session.commit()
            except:
                return migrateAsset(assetid, forceMigration, allowedTypes, creatorId, keepRobloxId, migrateInfo, attempt+1, throwException, allowBackgroundMigration, assetVersionId, bypassCooldown, attemptSoundWithPlaceId)
            
            ContentHash = hashlib.sha512(robloxAssetContent).hexdigest()
            s3helper.UploadBytesToS3(robloxAssetContent, ContentHash)
            assetVersion = assetversion.CreateNewAssetVersion(asset, ContentHash)
            TakeThumbnail(asset.id)

            return asset
    
    try:
        if assetVersionId != None:
            robloxAssetContent = requests.get(f"https://assetdelivery.roblox.com/v1/asset/?id={str(assetid)}&version={str(assetVersionId)}", timeout=5)
        else:
            robloxAssetContent = requests.get(f"https://assetdelivery.roblox.com/v1/asset/?id={str(assetid)}", timeout=5)
        if robloxAssetContent.status_code != 200:
            if robloxAssetContent.status_code == 409:
                redis_controller.set(f"asset_migrate_v2:{str(assetid)}:blocked", "true", ex=3600 * 7)
                if throwException:
                    raise NoPermissionException("Roblox does not allow us to download this asset")
                return None
            elif robloxAssetContent.status_code == 429:
                if allowBackgroundMigration:
                    AddAssetToMigrationQueue(assetid)
                logging.error(f"Failed to download asset {assetid} after 2 attempts for rate limiting")
                if throwException:
                    raise RatelimittedReachedException("Rate limit reached")
                return None
            #logging.error(f"Failed to download asset {assetid}")
            return None
    except:
        # rbxcdn is prob down
        #logging.error(f"Failed to download asset {assetid}")
        if throwException:
            raise AssetDeliveryAPIFailedException("Asset delivery api failed")
        return None
    
    try:
        robloxAssetContent = robloxAssetContent.content
        robloxAssetContent = robloxAssetContent.replace("roblox.com".encode("utf-8"), config.BaseDomain.encode("utf-8"))
    except:
        # Means that the file is not an rbxmx or rbxm file
        robloxAssetContent = robloxAssetContent.content

    if assetInfo['AssetTypeId'] == 4:
        originalAssetContent = robloxAssetContent
        try:
            if RBXMesh.get_mesh_version(robloxAssetContent) not in [2.0]:
                meshData : RBXMesh.FileMeshData = RBXMesh.read_mesh_data(robloxAssetContent)
                robloxAssetContent = RBXMesh.export_mesh_v2(meshData)
        except Exception as e:
            logging.warning(f"Failed to downgrade mesh {str(assetid)}, error: {str(e)}")
            robloxAssetContent = originalAssetContent

    AssetName = "Asset " + str(assetid)
    AssetDescription = "Migrated from Roblox"
    if migrateInfo:
        if assetInfo is not None:
            AssetName = assetInfo['Name']
            AssetDescription = assetInfo['Description']
        else:
            logging.warning(f"Failed to get asset info for {assetid}")
    if keepRobloxId:
        asset = Asset(roblox_asset_id=assetid, force_asset_id=assetid, asset_type=AssetType(assetInfo['AssetTypeId']), name=AssetName, description=AssetDescription, asset_genre=1, moderation_status=0, created_at=datetime.utcnow(), updated_at=datetime.utcnow(), creator_id=creatorId)
    else:
        asset = Asset(roblox_asset_id=assetid, asset_type=AssetType(assetInfo['AssetTypeId']), name=AssetName, description=AssetDescription, asset_genre=1, moderation_status=0, created_at=datetime.utcnow(), updated_at=datetime.utcnow(), creator_id=creatorId)
    db.session.add(asset)
    try:
        db.session.commit()
    except:
        # Race condition, lets try again
        return migrateAsset(assetid, forceMigration)
    

    ContentHash = hashlib.sha512(robloxAssetContent).hexdigest()
    s3helper.UploadBytesToS3(robloxAssetContent, ContentHash)

    assetVersion = AssetVersion(asset_id=asset.id, content_hash=ContentHash, created_at=datetime.utcnow(), version=1)
    db.session.add(assetVersion)
    db.session.commit()
    return asset
import uuid

def GenerateTempAuthToken( AssetId : int, Expiration : int = 600, CreatorIP : str = None ) -> str:
    """
        Generates a temporary auth token for downloading places from RCC
        
        :param AssetId: The asset id
        :param Expiration: The expiration in seconds
        :param CreatorIP: The ip of the creator

        :return: The auth token
    """
    AuthToken = str(uuid.uuid4())
    redis_controller.setex(f"AssetTempAuthToken:{AuthToken}:{str(AssetId)}", time = Expiration, value = json.dumps({
        "CreatorIP" : CreatorIP
    }))
    return AuthToken

def VerifyTempAuthToken( AuthToken : str, AssetId : int, RequesterIP : str = None ) -> bool:
    """
        Verifies a temporary auth token for downloading places from RCC

        :param AuthToken: The auth token
        :param AssetId: The asset id
        :param RequesterIP: The ip of the requester

        :return: True if the auth token is valid, False if not
    """

    AuthTokenData = redis_controller.get(f"AssetTempAuthToken:{AuthToken}:{str(AssetId)}")
    if AuthTokenData is None:
        return False
    AuthTokenData = json.loads(AuthTokenData)
    if AuthTokenData['CreatorIP'] is not None:
        if AuthTokenData['CreatorIP'] != RequesterIP:
            return False
        
    redis_controller.delete(f"AssetTempAuthToken:{AuthToken}:{str(AssetId)}")
    return True

@AssetRoute.route("/v1/asset/", methods=["GET"])
@AssetRoute.route("/v1/asset", methods=["GET"])
@AssetRoute.route('/Asset', methods=['GET'])
@AssetRoute.route('/Asset/', methods=['GET'])
@AssetRoute.route('/asset/', methods=['GET'])
@AssetRoute.route('/asset', methods=['GET'])
def AssetHandler():
    id = request.args.get('id', type=int) or request.args.get("assetversionid", type=int, default=None)
    if id is None:
        return jsonify({'error':'Invalid request'}),400
    serverplaceid = request.args.get('serverplaceid', type=int, default=0)
    isScriptInsert = request.args.get('scriptinsert', type=int, default=0) == 1
    isClientInsert = request.args.get('clientinsert', type=int, default=0) == 1
    
    asset : Asset = Asset.query.filter_by(id=id).first()
    if asset is None:
        if id >= 1000000000 and id <= 9999999999:
            # Could be a temporary asset
            AssetInfo : str = redis_controller.get(f"temp_asset:{str(id)}")
            if AssetInfo is not None:
                AssetInfo = json.loads(AssetInfo)
                return redirect(f"{config.CDN_URL}/{AssetInfo['hash']}")

        if redis_controller.get(f"asset_migrate_v2:{str(id)}:blocked") is not None:
            return jsonify({'error':'Invalid request'}),400

        MigrateAssetLockName = f"asset_migrate_v2:{str(id)}:lock"
        MigrateLock = redislock.acquire_lock( lock_name = MigrateAssetLockName, acquire_timeout = 50, lock_timeout = 2 ) # Prevents multiple migrations at once which can happen when server and client loads assets at the same time
        if MigrateLock is None:
            return redirect(f"/asset/?id={str(id)}", code=301)
        
        if redis_controller.lrange("migrate_assets_queue", 0, -1).count(str(id)) > 0:
            return jsonify({'error': 'Server is handling too many asset migrations at this time, try again later.'}),500
        
        asset : Asset = Asset.query.filter_by(id=id).first()
        if asset is None:
            try:
                asset = migrateAsset(
                    assetid = id,
                    forceMigration = False,
                    throwException = True,
                    allowBackgroundMigration = True
                )
            except AssetDeliveryAPIFailedException:
                return jsonify({'error': 'Failed to migrate asset from roblox'}),500
            except RatelimittedReachedException:
                return jsonify({'error': 'Server is handling too many asset migrations at this time, try again later.'}),500
            except AssetNotAllowedException:
                return jsonify({'error': 'This asset is not allowed to be migrated at this time'}),403
            except NoPermissionException:
                return jsonify({'error': 'This asset is either a private or archived asset on Roblox and cannot be migrated'}),400
            except EconomyAPIFailedException:
                return jsonify({'error': 'Failed to get information about this asset from Roblox'}),500
            except AssetOnCooldownException:
                return jsonify({'error': 'This asset is either a private or archived asset on Roblox and cannot be migrated'}),400
            except AssetNotFoundException:
                return jsonify({'error': 'This asset does not exist on Roblox'}),400
            except:
                return jsonify({'error': 'Failed to migrate asset from roblox'}),500
            redislock.release_lock(MigrateAssetLockName, MigrateLock)
            if asset is None:
                return jsonify({'error':'Something went wrong!'}),500
        redislock.release_lock(MigrateAssetLockName, MigrateLock)
    CacheNotAllowed = False
    if asset.asset_type == AssetType.Place:
        CacheNotAllowed = True
        if isScriptInsert or isClientInsert:
            return jsonify({'error':'You do not have permission to access this asset'}),403
        authToken = request.args.get('access', type=str, default=None) or request.cookies.get('Temp-Place-Access-Key', default="", type=str)
        isValidToken = VerifyTempAuthToken(authToken, asset.id, get_remote_address()) or GameServer.query.filter_by(serverIP=get_remote_address(), accessKey=authToken).first() is not None
        if not isValidToken:
            AccessKey = request.headers.get("AccessKey", type=str, default="")
            if AccessKey == "":
                return jsonify({'error':'You do not have permission to access this asset'}),403
            if request.headers.get("User-Agent") != "Roblox/WinInet":
                return jsonify({'error':'You do not have permission to access this asset'}),403
            ServerAddress = get_remote_address()
            GameServerObj : GameServer = GameServer.query.filter_by(serverIP=ServerAddress).first()
            if GameServerObj is None:
                return jsonify({'error':'You do not have permission to access this asset'}),403
            if GameServerObj.accessKey != AccessKey:
                return jsonify({'error':'You do not have permission to access this asset'}),403
        
        if "UserRequest" in request.headers.get( key = "accesskey", default = "" ):
            return jsonify({
                "success": False,
                "message": "Invalid request"
            }), 400
    
    if asset.asset_type == AssetType.Gear and serverplaceid > 0:
        return jsonify({'error':'Invalid request, Gears are not allowed in games'}),400

    # Return the place
    
    if asset.moderation_status != 0:
        CacheNotAllowed = True
        # Request must be coming from a RCCService Server and not from client
        # This allows for renders to still work but not for unmoderated content to be downloaded from the client
        if request.headers.get("Requester") != "Server":
            return jsonify({'error':'Invalid request'}),400

    assetVersion : AssetVersion = AssetVersion.query.filter_by(asset_id=asset.id).order_by(AssetVersion.version.desc()).first()
    if assetVersion is None:
        return jsonify({'error':'Invalid request'}),400
    
    Response = make_response(redirect(f"{config.CDN_URL}/{assetVersion.content_hash}"))
    if CacheNotAllowed:
        Response.headers['Cache-Control'] = 'no-store'
    else:
        Response.headers['Cache-Control'] = 'public, max-age=3600'
        Response.status_code = 301
    return Response

@AssetRoute.route("/v1/assets/batch/", methods=["POST"])
@AssetRoute.route("/asset/batch/", methods=["POST"])
@csrf.exempt
def AssetBatchRequest():
    RequestData = request.json

    if type(RequestData) is not list:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400

    if len(RequestData) > 100:
        return jsonify({
            "success": False,
            "error": "Invalid request"
        }),400
    
    AssetReturnInfo : list[dict] = []
    for RequestObj in RequestData:
        if "assetId" not in RequestObj or "assetType" not in RequestObj or "requestId" not in RequestObj:
            continue
        AssetId = RequestObj["assetId"]
        ExpectedAssetType = str(RequestObj["assetType"])

        AssetObj : Asset = Asset.query.filter_by( id = AssetId ).first()
        if AssetObj is None:
            continue
        if AssetObj.asset_type.name.lower() != ExpectedAssetType.lower():
            continue
        if AssetObj.asset_type == AssetType.Place or AssetObj.moderation_status != 0:
            continue
        LatestAssetVersion : AssetVersion = assetversion.GetLatestAssetVersion( AssetObj )
        if LatestAssetVersion is None:
            continue
        AssetReturnInfo.append({
            "Location": f"{config.CDN_URL}/{LatestAssetVersion.content_hash}",
            "RequestId": RequestObj["requestId"]
        })
    
    return jsonify(AssetReturnInfo), 200

@AssetRoute.route("/Asset/legacy/", methods=["GET"])
def LegacyAssetSupport():
    AssetId = request.args.get('id', type=int, default=None)
    if AssetId is None:
        return jsonify({'error':'Invalid request'}),400
    AssetObj : Asset = Asset.query.filter_by(id=AssetId).first()
    if AssetObj is None:
        return jsonify({'error':'Invalid request'}),400
    
    if AssetObj.asset_type not in [AssetType.Shirt, AssetType.TShirt, AssetType.Pants, AssetType.Head, AssetType.Hat, AssetType.HairAccessory, AssetType.FaceAccessory, AssetType.NeckAccessory, AssetType.ShoulderAccessory, AssetType.FrontAccessory, AssetType.BackAccessory, AssetType.WaistAccessory, AssetType.Gear, AssetType.Face]:
        return redirect(f"/asset/?id={str(AssetId)}", code=301)
    
    if AssetObj.moderation_status != 0:
        return jsonify({'error':'Invalid request'}),400
    
    LatestAssetVersion : AssetVersion = assetversion.GetLatestAssetVersion( AssetObj )
    if LatestAssetVersion is None:
        return jsonify({'error':'Invalid request'}),400

    if redis_controller.exists(f"legacy_asset_migration_v3:{LatestAssetVersion.content_hash}"):
        ConvertedContentHash = redis_controller.get(f"legacy_asset_migration_v3:{LatestAssetVersion.content_hash}")
        return redirect(f"{config.CDN_URL}/{ConvertedContentHash}")
    
    AssetVersonContent : bytes = s3helper.GetFileFromS3(
        LatestAssetVersion.content_hash,
        skipDownloadCache = False
    )

    try:
        AssetVersonContent.decode("utf-8")
    except:
        # Asset is not supported and could possibly crash 2014
        redis_controller.set(f"legacy_asset_migration_v3:{LatestAssetVersion.content_hash}", LatestAssetVersion.content_hash, ex=60 * 60 * 24 * 3)
        return redirect(f"{config.CDN_URL}/{LatestAssetVersion.content_hash}")

    try:
        AssetVersonContent = AssetVersonContent.replace("roblox.com".encode("utf-8"), config.BaseDomain.encode("utf-8"))
    except:
        pass

    if AssetObj.asset_type in [AssetType.Shirt, AssetType.TShirt, AssetType.Pants]: # Fix a mistake I made awhile ago with Shirts, TShirts and Pants where the asset content URL was https://syntax.eco/asset/?id= instead of http://www.syntax.eco/asset/?id=
        AssetVersonContent = AssetVersonContent.replace("https://syntax.eco/asset/?id=".encode("utf-8"), "http://www.syntax.eco/asset/?id=".encode("utf-8"))
    
    if AssetObj.asset_type in [AssetType.Hat, AssetType.HairAccessory, AssetType.FaceAccessory, AssetType.NeckAccessory, AssetType.ShoulderAccessory, AssetType.FrontAccessory, AssetType.BackAccessory, AssetType.WaistAccessory]:
        AssetVersonContent = AssetVersonContent.replace("Accessory".encode("utf-8"), "Hat".encode("utf-8")) # Shitty hack but I can't think of a better way to do it

    NewAssetHash = hashlib.sha512(AssetVersonContent).hexdigest()
    s3helper.UploadBytesToS3(AssetVersonContent, NewAssetHash)

    redis_controller.set(f"legacy_asset_migration_v3:{LatestAssetVersion.content_hash}", NewAssetHash, ex=60 * 60 * 24 * 14)
    return redirect(f"{config.CDN_URL}/{NewAssetHash}")
