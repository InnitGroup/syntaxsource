from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify
from app.extensions import db, redis_controller, csrf
import uuid
import json
import requests
import hashlib
import logging
import os
from datetime import datetime

from app.services.gameserver_comm import perform_post
from app.util import websiteFeatures, s3helper

from app.models.gameservers import GameServer
from app.models.asset_version import AssetVersion
from app.models.asset_thumbnail import AssetThumbnail
from app.models.user_thumbnail import UserThumbnail
from app.models.place_icon import PlaceIcon
from app.models.asset import Asset
from app.models.package_asset import PackageAsset
from app.models.place import Place
from app.models.user_avatar import UserAvatar
from app.models.user_avatar_asset import UserAvatarAsset

from app.enums.PlaceYear import PlaceYear

Thumbnailer = Blueprint('thumbnailer', __name__, url_prefix='/internal')
AssetTypetoThumbnailRenderType = {
    4 : 4,
    8 : 11,
    9 : 5,
    10 : 3,
    11 : 15,
    12 : 14,
    1 : 6,
    13 : 6,
    18 : 6,
    19 : 12,
    2 : 7,
    17 : 8,
    27 : 9,
    28 : 9,
    29 : 9,
    30 : 9,
    31 : 9,
    32 : 17,
    41 : 11,
    42 : 11,
    43 : 11,
    44 : 11,
    45 : 11,
    46 : 11,
    47 : 11,
    40 : 13,
}

"""
    omg was i fucking high or something several months ago i gotta rewrite this one day
    - something.else 19/2/2024
"""

def GetAvatarHash( userid : int ) -> str:
    """
    Returns the avatar hash for the userid provided
    """
    UserAvatarObject : UserAvatar = UserAvatar.query.filter_by(user_id=userid).first()
    if UserAvatarObject is None:
        return None
    UserAvatarAssetObject : UserAvatarAsset = UserAvatarAsset.query.filter_by(user_id=userid).all()
    HashString = ""
    for UserAvatarAssetObject in UserAvatarAssetObject:
        HashString += str(UserAvatarAssetObject.asset_id)+"-"
    HashString += str(UserAvatarObject.head_color_id)+"-"
    HashString += str(UserAvatarObject.torso_color_id)+"-"
    HashString += str(UserAvatarObject.left_arm_color_id)+"-"
    HashString += str(UserAvatarObject.right_arm_color_id)+"-"
    HashString += str(UserAvatarObject.left_leg_color_id)+"-"
    HashString += str(UserAvatarObject.right_leg_color_id)+'-'
    HashString += str(UserAvatarObject.r15)+'-'
    HashString += str(UserAvatarObject.height_scale)+'-'
    HashString += str(UserAvatarObject.width_scale)+'-'
    HashString += str(UserAvatarObject.head_scale)+'-'
    HashString += str(UserAvatarObject.proportion_scale)+'-'
    HashString += str(UserAvatarObject.body_type_scale)

    AvatarHash = hashlib.sha256(HashString.encode()).hexdigest()
    return AvatarHash

def findBestThumbnailer() -> GameServer | None:
    weight_ping_time = 3
    weight_queue_size = 0.3
    
    AllGameServers : list[GameServer] = GameServer.query.filter_by(allowThumbnailGen=True, isRCCOnline=True).filter( GameServer.thumbnailQueueSize < 40 ).all()
    if len(AllGameServers) == 0:
        return None
    BestGameServer : GameServer = None
    for GameServerObject in AllGameServers:
        GameServerObject.score = (weight_ping_time * GameServerObject.heartbeatResponseTime) + (weight_queue_size * GameServerObject.thumbnailQueueSize)
        if BestGameServer is None:
            BestGameServer = GameServerObject
            continue
        if GameServerObject.score < BestGameServer.score:
            BestGameServer = GameServerObject
    #logging.info(f"GameserverLoadBalancer: {str(BestGameServer.serverId)} - {str(BestGameServer.score)} - Ping: {str(round(BestGameServer.heartbeatResponseTime, 3))}secs - Queue: {str(BestGameServer.thumbnailQueueSize)}")
    return BestGameServer

def TakeUserThumbnail(UserId : int, bypassCooldown=False, bypassCache=False):
    """
    Takes a thumbnail and headshot for the userid provided
    bypassCooldown: Bypasses the 5 second cooldown for that user
    bypassCache: Bypasses the cache and takes a new thumbnail and headshot
    """
    if redis_controller.get(f"Thumbnailer:UserId:{UserId}:Taken") is not None and not bypassCooldown:
        return "Thumbnail Attempted Recently"
    redis_controller.set(f"Thumbnailer:UserId:{UserId}:Taken", "True", 5)
    ImageHeadshotCache = None
    ImageThumbnailCache = None
    AvatarHash = GetAvatarHash(UserId)
    if not bypassCache:
        UserThumbnailObject = UserThumbnail.query.filter_by(userid=UserId).first()
        if UserThumbnailObject is None:
            UserThumbnailObject = UserThumbnail(userid=UserId, full_contenthash=None, headshot_contenthash=None, updated_at=datetime.utcnow())
            db.session.add(UserThumbnailObject)
        ImageThumbnailCache = redis_controller.get(f"Thumbnailer:UserImage:{AvatarHash}:Thumbnail")
        if ImageThumbnailCache is not None:
            #logging.info(f"Thumbnail Cache found for UserId {UserId} - {AvatarHash}")
            UserThumbnailObject.full_contenthash = ImageThumbnailCache
        ImageHeadshotCache = redis_controller.get(f"Thumbnailer:UserImage:{AvatarHash}:Headshot")
        if ImageHeadshotCache is not None:
            #logging.info(f"Headshot Cache found for UserId {UserId} - {AvatarHash}")
            UserThumbnailObject.headshot_contenthash = ImageHeadshotCache
        db.session.commit()
        if ImageThumbnailCache is not None and ImageHeadshotCache is not None:
            return
    if redis_controller.get(f"Thumbnailer:AvatarHash:{AvatarHash}:Lock") is not None:
        return "Thumbnail Attempted Recently"
    redis_controller.set(f"Thumbnailer:AvatarHash:{AvatarHash}:Lock", "True", 5)

    if not websiteFeatures.GetWebsiteFeature("ThumbnailRendering"):
        return "Thumbnail Rendering is disabled"
    GameServerObject : GameServer = findBestThumbnailer()
    if GameServerObject is None:
        return "No suitable game servers found"
    ThumbnailReqId = str(uuid.uuid4())
    redis_controller.set(f"Thumbnailer:Request:{ThumbnailReqId}", json.dumps({
        "UserId": UserId,
        "Type": 0,
    }), ex=600)

    HeadshotReqId = str(uuid.uuid4())
    redis_controller.set(f"Thumbnailer:Request:{HeadshotReqId}", json.dumps({
        "UserId": UserId,
        "Type": 1,
    }), ex=600)
    UserAvatarObj : UserAvatar = UserAvatar.query.filter_by(user_id=UserId).first()
    try:
        if (not bypassCache and ImageHeadshotCache is None) or bypassCache:
            perform_post(
                TargetGameserver = GameServerObject,
                Endpoint = "Thumbnail",
                JSONData = {
                    "type": 1,
                    "userid": UserId,
                    "reqid": HeadshotReqId,
                    "image_x": 768,
                    "image_y": 768
                },
                RequestTimeout = 0.5
            )
        if (not bypassCache and ImageThumbnailCache is None) or bypassCache:
            perform_post(
                TargetGameserver = GameServerObject,
                Endpoint = "Thumbnail",
                JSONData = {
                    "type": 16 if UserAvatarObj.r15 else 0,
                    "userid": UserId,
                    "reqid": ThumbnailReqId,
                    "image_x": 768,
                    "image_y": 768
                },
                RequestTimeout = 0.5
            )
        GameServerObject.thumbnailQueueSize += 2
        db.session.commit()
    except Exception as e:
        return str(e)
    return "Thumbnail request sent"

def ValidatePlaceFileRequest(PlaceId : int, RequestId : str = None, AssetYear : PlaceYear = None ) -> None:
    """
        Sends a validate file request to a thumbnailer server
    """
    if not websiteFeatures.GetWebsiteFeature("AssetValidationService"):
        redis_controller.set(f"ValidatePlaceFileRequest:{RequestId}", json.dumps({
            "valid": False,
            "error": "Asset Validation Service is temporarily disabled, try again later"
        }), ex=600)

    GameServerObject : GameServer = findBestThumbnailer()
    if GameServerObject is None:
        redis_controller.set(f"ValidatePlaceFileRequest:{RequestId}", json.dumps({
            "valid": False,
            "error": "Cannot verify file at this time, try again later"
        }), ex=600)
        return
    if AssetYear is None:
        PlaceObj : Place = Place.query.filter_by(placeid=PlaceId).first()
        AssetYear = PlaceYear.Eighteen
        if PlaceObj is not None:
            AssetYear = PlaceObj.placeyear
    try:
        AssetYearToEndpoint = {
            PlaceYear.Eighteen: "AssetValidation2018",
            PlaceYear.Sixteen: "AssetValidation2016",
            PlaceYear.Fourteen: "AssetValidation2016",
            PlaceYear.Twenty: "AssetValidation2020",
            PlaceYear.TwentyOne: "AssetValidation2021"
        }
        if AssetYear not in AssetYearToEndpoint:
            redis_controller.set(f"ValidatePlaceFileRequest:{RequestId}", json.dumps({
                "valid": False,
                "error": "Invalid place year"
            }), ex=600)
            return
        
        response = perform_post(
            TargetGameserver = GameServerObject,
            Endpoint = AssetYearToEndpoint[AssetYear],
            JSONData = {
                "assetid": PlaceId
            },
            RequestTimeout = 60
        )

        response.raise_for_status()
        response = response.json()
        if response["valid"]:
            redis_controller.set(f"ValidatePlaceFileRequest:{RequestId}", json.dumps({
                "valid": True,
                "error": None
            }), ex=600)
            return
        else:
            redis_controller.set(f"ValidatePlaceFileRequest:{RequestId}", json.dumps({
                "valid": False,
                "error": response["reason"]
            }), ex=600)
            return
    except Exception as e:
        logging.error(f"Error while trying to validate place file: {str(e)}")
        redis_controller.set(f"ValidatePlaceFileRequest:{RequestId}", json.dumps({
            "valid": False,
            "error": "An error occured while trying to validate the place file"
        }), ex=600)
        return

def TakeThumbnail(AssetId : int, isIcon = False, bypassCooldown = False, bypassCache = False): # isIcon only used for game icons
    """
    Takes a thumbnail for the assetid provided
    bypassCooldown: Bypasses the 2 minute cooldown for that asset
    """
    from app.routes.asset import GenerateTempAuthToken
    if redis_controller.get(f"Thumbnailer:AssetId:{AssetId}:{str(isIcon)}:Taken") is not None and not bypassCooldown:
        return "Thumbnail Attempted Recently"
    redis_controller.set(f"Thumbnailer:AssetId:{AssetId}:{str(isIcon)}:Taken", "True", 120)
    AssetObject : Asset = Asset.query.filter_by(id=AssetId).first()
    AssetVersionObject : AssetVersion = AssetVersion.query.filter_by(asset_id=AssetId).order_by(AssetVersion.version.desc()).first()
    if AssetVersionObject is None and AssetObject.asset_type.value != 32:
        return "Asset version not found"
    if not bypassCache:
        if not isIcon:
            ImageThumbnailCache = redis_controller.get(f"Thumbnailer:AssetImage:{AssetVersionObject.content_hash}:Thumbnail")
            if ImageThumbnailCache is not None:
                ThumbnailObject : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=AssetId, asset_version_id=AssetVersionObject.version).first()
                if ThumbnailObject is None:
                    AssetModeration = 1
                    if AssetObject.roblox_asset_id is not None:
                        AssetModeration = 0
                    ThumbnailObject = AssetThumbnail(
                        asset_id=AssetId,
                        asset_version_id=AssetVersionObject.version,
                        content_hash=ImageThumbnailCache,
                        moderation_status=AssetModeration,
                        created_at=datetime.utcnow()
                    )
                    db.session.add(ThumbnailObject)
                    try:
                        db.session.commit()
                    except:
                        return
                    return
                if ThumbnailObject.content_hash == ImageThumbnailCache:
                    return
                ThumbnailObject.content_hash = ImageThumbnailCache
                ThumbnailObject.moderation_status = 1
                try:
                    db.session.commit()
                except:
                    return
                return
        else:
            ImageIconCache = redis_controller.get(f"Thumbnailer:AssetImage:{AssetVersionObject.content_hash}:PlaceIcon")
            if ImageIconCache is not None:
                PlaceIconObject : PlaceIcon = PlaceIcon.query.filter_by(placeid=AssetId).first()
                if PlaceIconObject is None:
                    PlaceIconObject = PlaceIcon(
                        placeid=AssetId,
                        contenthash=ImageIconCache,
                        updated_at=datetime.utcnow(),
                        moderation_status=1, # Pending
                    )
                    db.session.add(PlaceIconObject)
                    db.session.commit()
                    return
                if PlaceIconObject.contenthash == ImageIconCache:
                    return
                PlaceIconObject.contenthash = ImageIconCache
                PlaceIconObject.moderation_status = 1
                PlaceIconObject.updated_at = datetime.utcnow()
                db.session.commit()
                return
    
    AssetObject : Asset = Asset.query.filter_by(id=AssetId).first()
    if AssetObject is None:
        return "Asset not found"
    AssetType = AssetObject.asset_type.value
    ThumbnailType = AssetTypetoThumbnailRenderType.get(AssetType)
    if ThumbnailType is None:
        if AssetType in[39, 3, 24, 5, 48,49,50,51,52,53,54,55,56]: # SolidModel, Animation, Lua and Audio
            if AssetType == 39:
                StaticImage = open("./app/files/NoRender.png", "rb").read()
            elif AssetType == 3:
                StaticImage = open("./app/files/AudioThumbnail.png", "rb").read()
            elif AssetType in [24,48,49,50,51,52,53,54,55,56]:
                StaticImage = open("./app/files/AnimationThumbnail.png", "rb").read()
            elif AssetType == 5:
                StaticImage = open("./app/files/LuaThumbnail.png", "rb").read()
            ImageHash = hashlib.sha512(StaticImage).hexdigest()
            if not s3helper.DoesKeyExist(ImageHash):
                s3helper.UploadBytesToS3(StaticImage, ImageHash, contentType="image/png")
            try:
                NewThumbnailObject : AssetThumbnail = AssetThumbnail(
                    asset_id=AssetId,
                    asset_version_id=AssetVersionObject.version,
                    content_hash=ImageHash,
                    moderation_status=0,
                    created_at=datetime.utcnow()
                )
                db.session.add(NewThumbnailObject)
                db.session.commit()
            except:
                pass
            return "Used Static Image"

        return "Thumbnail type not found"
    
    if not websiteFeatures.GetWebsiteFeature("ThumbnailRendering"):
        return "Thumbnail Rendering is disabled"

    GameServerObject : GameServer = findBestThumbnailer()
    if GameServerObject is None:
        return "No suitable game servers found"
    
    ThumbnailReqId = str(uuid.uuid4())
    redis_controller.set(f"Thumbnailer:Request:{ThumbnailReqId}", json.dumps({
        "AssetId": AssetId,
        "AssetVersionId": AssetVersionObject.version,
        "isIcon": isIcon,
        "AssetType": AssetType,
    }), ex=600)
    TargetX = 1024
    TargetY = 1024
    PlaceAuthorisationToken = None
    if AssetType == 9:
        PlaceAuthorisationToken = GenerateTempAuthToken( AssetId, Expiration = 600, CreatorIP = None )
    if AssetType == 9 and not isIcon:
        TargetX = 1280
        TargetY = 720
    if AssetType == 1: # Image
        TargetX = 256
        TargetY = 256
    if AssetType == 32: # Package
        AllPackageAssets : list[PackageAsset] = PackageAsset.query.filter_by(package_asset_id=AssetId).all()
        AssetId = ""
        for i in range(len(AllPackageAssets)):
            AssetId += f"https://www.syntax.eco/asset/?id={str(AllPackageAssets[i].asset_id)}"
            if i != len(AllPackageAssets) - 1:
                AssetId += ";"
    try:
        logging.info(f"thumbnailer : TakeThumbnail : Sent request to thumbnailer for asset {AssetId} with type {ThumbnailType} to {GameServerObject.serverName} [ {GameServerObject.serverId} ]")
        perform_post(
            TargetGameserver = GameServerObject,
            Endpoint = "Thumbnail",
            JSONData = {
                "type": ThumbnailType,
                "asset": AssetId,
                "reqid": ThumbnailReqId,
                "image_x": TargetX,
                "image_y": TargetY,
                "placetoken": PlaceAuthorisationToken
            }
        )
        GameServerObject.thumbnailQueueSize += 1
        db.session.commit()
    except Exception as e:
        return str(e)
    return "Thumbnail request sent"
    

def isValidAuthorizationToken( authtoken : str) -> GameServer:
    if authtoken is None:
        return None
    GameServerObject = GameServer.query.filter_by(accessKey=authtoken).first()
    return GameServerObject

@Thumbnailer.route('/thumbnailreturn', methods=["POST"])
@csrf.exempt
def thumbnailreturn():
    AuthorizationToken = request.headers.get("Authorization")
    if AuthorizationToken is None:
        return jsonify({"status": "error", "message": "Invalid authorization token"}),400
    
    ThumbnailerOwner : GameServer = isValidAuthorizationToken(AuthorizationToken)
    if ThumbnailerOwner is None:
        return jsonify({"status": "error", "message": "Invalid authorization token"}),400
    
    ReqId = request.headers.get("ReturnUUID")
    if ReqId is None:
        return jsonify({"status": "error", "message": "Invalid request id"}),400

    RequestData = redis_controller.get(f"Thumbnailer:Request:{ReqId}")    
    if RequestData is None:
        return jsonify({"status": "error", "message": "Invalid request id"}),400
    redis_controller.delete(f"Thumbnailer:Request:{ReqId}")
    RequestData = json.loads(RequestData)
    if "UserId" not in RequestData:
        AssetId = RequestData["AssetId"]
        AssetVersionId = RequestData["AssetVersionId"]
        isIcon = RequestData["isIcon"]
        AssetType = RequestData["AssetType"]

        ImageData = request.data
        ImageHash = hashlib.sha512(ImageData).hexdigest()

        s3helper.UploadBytesToS3(ImageData, ImageHash, contentType="image/png")
        AssetVersionObject : AssetVersion = AssetVersion.query.filter_by(asset_id=AssetId, version=AssetVersionId).first()
        if isIcon and AssetType == 9:
            PlaceIconObject : PlaceIcon = PlaceIcon.query.filter_by(placeid=AssetId).first()
            if PlaceIconObject is None:
                PlaceIconObject = PlaceIcon(placeid=AssetId, contenthash=ImageHash, updated_at=datetime.utcnow())
                db.session.add(PlaceIconObject)
            else:
                PlaceIconObject.contenthash = ImageHash
                PlaceIconObject.updated_at = datetime.utcnow()
                PlaceIconObject.moderation_status = 1
            if AssetVersionObject:
                redis_controller.setex(f"Thumbnailer:AssetImage:{AssetVersionObject.content_hash}:PlaceIcon", 60 * 60 * 24 * 3, ImageHash)
            try:
                ThumbnailerOwner.thumbnailQueueSize -= 1
                db.session.commit()
            except:
                pass
            return jsonify({"status": "success", "message": "Thumbnail saved"}),200
        
        if AssetVersionObject:
            redis_controller.setex(f"Thumbnailer:AssetImage:{AssetVersionObject.content_hash}:Thumbnail", 60 * 60 * 24 * 3, ImageHash)
        
        ThumbnailObject : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=AssetId, asset_version_id=AssetVersionId).first()
        if ThumbnailObject is not None:
            ThumbnailObject.content_hash = ImageHash
            ThumbnailObject.updated_at = datetime.utcnow()
            ThumbnailerOwner.thumbnailQueueSize -= 1
            db.session.commit()
            return jsonify({"status": "success", "message": "Thumbnail saved"}),200
        
        AssetObject : Asset = Asset.query.filter_by(id=AssetId).first()
        AssetModeration = 1
        if AssetObject.roblox_asset_id is not None:
            AssetModeration = 0
        
        AssetThumbnailObject = AssetThumbnail(asset_id=AssetId, asset_version_id=AssetVersionId, content_hash=ImageHash, created_at=datetime.utcnow(), moderation_status=AssetModeration) # 0 = Approved, 1 = Pending, 2 = Denied
        db.session.add(AssetThumbnailObject)
        db.session.commit()

        return jsonify({"status": "success", "message": "Thumbnail saved"}),200
    else:
        UserId = RequestData["UserId"]
        ThumbnailType = RequestData["Type"]
        ImageData = request.data
        ImageHash = hashlib.sha512(ImageData).hexdigest()

        s3helper.UploadBytesToS3(ImageData, ImageHash, contentType="image/png")
        
        AvatarHash = GetAvatarHash(UserId)
        if ThumbnailType == 0:
            redis_controller.setex(f"Thumbnailer:UserImage:{AvatarHash}:Thumbnail", 60 * 60 * 24 * 3, ImageHash)
        elif ThumbnailType == 1:
            redis_controller.setex(f"Thumbnailer:UserImage:{AvatarHash}:Headshot", 60 * 60 * 24 * 3, ImageHash)
        
        UserThumbnailObject = UserThumbnail.query.filter_by(userid=UserId).first()
        if UserThumbnailObject is None:
            if ThumbnailType == 0:
                UserThumbnailObject = UserThumbnail(userid=UserId, full_contenthash=ImageHash, headshot_contenthash=None, updated_at=datetime.utcnow())
            else:
                UserThumbnailObject = UserThumbnail(userid=UserId, headshot_contenthash=ImageHash, full_contenthash=None, updated_at=datetime.utcnow())
            db.session.add(UserThumbnailObject)
            ThumbnailerOwner.thumbnailQueueSize -= 1
            db.session.commit()
            return jsonify({"status": "success", "message": "Thumbnail saved"}),200
        else:
            if ThumbnailType == 0:
                UserThumbnailObject.full_contenthash = ImageHash
            else:
                UserThumbnailObject.headshot_contenthash = ImageHash
            UserThumbnailObject.updated_at = datetime.utcnow()
            ThumbnailerOwner.thumbnailQueueSize -= 1
            db.session.commit()
            return jsonify({"status": "success", "message": "Thumbnail updated"}),200