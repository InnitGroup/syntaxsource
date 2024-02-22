from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort, Response
import hashlib
import gzip
import json
from PIL import Image
from app.models.groups import GroupIcon
from app.models.user_thumbnail import UserThumbnail
from app.models.asset_thumbnail import AssetThumbnail
from app.models.place_icon import PlaceIcon
from app.models.user import User
from app.models.asset import Asset
from app.routes.thumbnailer import TakeThumbnail
from app.util import s3helper
from app.extensions import redis_controller, csrf
from config import Config
from io import BytesIO

config = Config()
ImageRoute = Blueprint('image', __name__)

def HandleResolutionCheck(
    WidthParametersName : list[ str ] = [ 'width', 'x' ],
    HeightParametersName : list[ str ] = [ 'height', 'y' ],
    AllowedWidths : list[ int ] = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
    AllowedHeights : list[ int ] = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
    MustBeSquare : bool = True,
    CanRoundToNearest : bool = True
) -> ( int, int ):
    """
        Handles resolution checking for images. Aborts the request if the resolution is invalid.
        Must be called in a flask request context.

        :param WidthParametersName: The names of valid parameters for width.
        :param HeightParametersName: The names of valid parameters for height.
        :param AllowedWidths: The allowed widths.
        :param AllowedHeights: The allowed heights.
        :param MustBeSquare: Whether or not the image must be square.
        :param CanRoundToNearest: Whether or not the image can round to the nearest resolution.

        :return: ( width, height )
    """
    Width : int = None
    Height : int = None
    for WidthParameterName in WidthParametersName:
        if WidthParameterName in request.args:
            Width = request.args.get( key=WidthParameterName, default=None, type=int )
            break
    for HeightParameterName in HeightParametersName:
        if HeightParameterName in request.args:
            Height = request.args.get( key=HeightParameterName, default=None, type=int )
            break
    
    
    if Width is None or Height is None:
        abort( 400 )
    if ( Width not in AllowedWidths or Height not in AllowedHeights ) and not CanRoundToNearest:
        abort( 400 )
    if MustBeSquare and Width != Height:
        abort( 400 )
    
    
    if CanRoundToNearest:
        if Width not in AllowedWidths:
            Width = min( AllowedWidths, key=lambda x:abs(x-Width) )
        if Height not in AllowedHeights:
            Height = min( AllowedHeights, key=lambda x:abs(x-Height) )
    
    return ( Width, Height )

def HandleImageResize(
    ImageContentHash : str,
    TargetWidth : int,
    TargetHeight : int,
    CroppedHash : str,
    CacheControl : str = "max-age=120",
    SkipCacheCroppedImage : bool = False,
    ReturnAsJSON : bool = False
) -> Response:
    """
        Handles image resizing

        :param ImageContentHash: The content hash of the image.
        :param TargetWidth: The target width.
        :param TargetHeight: The target height.
        :param CroppedHash: The hash of the cropped image.

        :return: Flask Response
    """
    if s3helper.DoesKeyExist(CroppedHash) and not SkipCacheCroppedImage:
        if ReturnAsJSON:
            return jsonify({
                "Final": True,
                "Url": f"{config.CDN_URL}/{CroppedHash}"
            })
        ImageResponse = make_response(redirect(f"{config.CDN_URL}/{CroppedHash}"))
        ImageResponse.headers['Cache-Control'] = CacheControl
        return ImageResponse
    
    if not s3helper.DoesKeyExist(ImageContentHash):
        if ReturnAsJSON:
            return jsonify({
                "Final": False,
                "Url": "/static/img/placeholder.png"
            })
        return redirect("/static/img/placeholder.png")
    
    ImageContent = BytesIO( s3helper.GetFileFromS3(ImageContentHash) )
    ImageObj = Image.open(ImageContent)
    ImageObj = ImageObj.resize((int(TargetWidth),int(TargetHeight))).convert('RGBA')
    
    VirtualFile = BytesIO()
    ImageObj.save(VirtualFile, "PNG")
    VirtualFile.seek(0)
    s3helper.UploadBytesToS3(VirtualFile.getvalue(), CroppedHash, contentType="image/png")

    if ReturnAsJSON:
        return jsonify({
            "Final": True,
            "Url": f"{config.CDN_URL}/{CroppedHash}"
        })
    ImageResponse = make_response(redirect(f"{config.CDN_URL}/{CroppedHash}"))
    ImageResponse.headers['Cache-Control'] = CacheControl
    return ImageResponse

@ImageRoute.route("/avatar-thumbnail/image", methods=["GET"])
@ImageRoute.route('/Thumbs/Avatar.ashx', methods=['GET'])
@ImageRoute.route('/thumbs/avatar.ashx', methods=['GET'])
def avatar():
    userId = request.args.get('userId', default = None, type = int)
    username = request.args.get('username', default = None, type = str)

    if (userId is None and username is None):
        return redirect("/static/img/placeholder.png")
    
    TargetX, TargetY = HandleResolutionCheck(
        WidthParametersName = [ 'x', 'width' ],
        HeightParametersName = [ 'y', 'height' ],
        AllowedWidths = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
        AllowedHeights = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
        MustBeSquare = True,
        CanRoundToNearest = True
    )

    if username is not None and userId is None:
        UserObj : User = User.query.filter_by(username=username).first()
        if UserObj is None:
            return redirect("/static/img/placeholder.png")
        userId = UserObj.id

    ThumbnailObj : UserThumbnail = UserThumbnail.query.filter_by(userid=userId).first()
    if ThumbnailObj is None:
        return redirect("/static/img/placeholder.png")
    
    ContentHash = ThumbnailObj.full_contenthash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetX}-{TargetY}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetX,
        TargetHeight = TargetY,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120"
    )

@ImageRoute.route('/avatar-thumbnail/json', methods=['GET'])
def avatar_json():
    userId = request.args.get('userId', None, type=int)
    if userId is None:
        return jsonify({
            "Final": False,
            "Url": "/static/img/placeholder.png"
        })
    
    TargetWidth, TargetHeight = HandleResolutionCheck(
        WidthParametersName = [ 'width', 'x' ],
        HeightParametersName = [ 'height', 'y' ],
        AllowedWidths = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
        AllowedHeights = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
        MustBeSquare = True,
        CanRoundToNearest = True
    )
    
    thumbnail : UserThumbnail = UserThumbnail.query.filter_by(userid=userId).first()
    if thumbnail is None:
        return jsonify({
            "Final": False,
            "Url": "/static/img/placeholder.png"
        })
    ContentHash = thumbnail.full_contenthash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetWidth}-{TargetHeight}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetWidth,
        TargetHeight = TargetHeight,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120",
        ReturnAsJSON = True
    )

@ImageRoute.route('/headshot-thumbnail/image', methods=['GET'])
@ImageRoute.route('/Thumbs/Head.ashx', methods=['GET'])
def head():
    userId = request.args.get('userId', default = None, type = int)
    if userId is None:
        return redirect("/static/img/placeholder.png")
    
    TargetX, TargetY = HandleResolutionCheck(
        WidthParametersName = [ 'x', 'width' ],
        HeightParametersName = [ 'y', 'height' ],
        AllowedWidths = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
        AllowedHeights = [ 48, 180, 420, 60, 100, 150, 352, 200, 500 ],
        MustBeSquare = True,
        CanRoundToNearest = True
    )

    ThumbnailObj : UserThumbnail = UserThumbnail.query.filter_by(userid=userId).first()
    if ThumbnailObj is None:
        return redirect("/static/img/placeholder.png")
    
    ContentHash = ThumbnailObj.headshot_contenthash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetX}-{TargetY}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetX,
        TargetHeight = TargetY,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120"
    )

@ImageRoute.route('/asset-thumbnail/json', methods=['GET'])
def asset_json():
    assetId = request.args.get( 'assetId',  None, type=int )
    if assetId is None:
        return jsonify({
            "Final": False,
            "Url": "/static/img/placeholder.png"
        })
    
    TargetWidth, TargetHeight = HandleResolutionCheck(
        WidthParametersName = [ 'width', 'x' ],
        HeightParametersName = [ 'height', 'y' ],
        AllowedWidths = [48,180,420,60,100,150,352,396,480,512,576,700,768,640,360,1280,720],
        AllowedHeights = [48,180,420,60,100,150,352,396,480,512,576,700,768,640,360,1280,720],
        MustBeSquare = False,
        CanRoundToNearest = True
    )

    thumbnailObj : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=assetId).order_by(AssetThumbnail.asset_version_id.desc()).first()
    if thumbnailObj is None:
        return jsonify({
            "Final": False,
            "Url": "/static/img/placeholder.png"
        })
    if thumbnailObj.moderation_status != 0 or thumbnailObj.asset.moderation_status != 0:
        if thumbnailObj.moderation_status == 2 or thumbnailObj.asset.moderation_status == 2:
            return jsonify({
                "Final": True,
                "Url": "/static/img/ContentDeleted.png"
            })
        return jsonify({
            "Final": False,
            "Url": "/static/img/placeholder.png"
        })
    
    ContentHash = thumbnailObj.content_hash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetWidth}-{TargetHeight}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetWidth,
        TargetHeight = TargetHeight,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120",
        ReturnAsJSON = True
    )

@ImageRoute.route('/asset-thumbnail/image', methods=['GET'])
@ImageRoute.route('/thumbs/asset.ashx', methods=['GET'])
@ImageRoute.route('/Thumbs/Asset.ashx', methods=['GET'])
def asset():
    assetId = request.args.get('assetId', default = None, type = int) or request.args.get('assetid', default = None, type = int)
    if assetId is None:
        return redirect("/static/img/placeholder.png")
    
    TargetX, TargetY = HandleResolutionCheck(
        WidthParametersName = [ 'x', 'width' ],
        HeightParametersName = [ 'y', 'height' ],
        AllowedWidths = [48,180,420,60,100,150,352,396,480,512,576,700,768,640,360,1280,720],
        AllowedHeights = [48,180,420,60,100,150,352,396,480,512,576,700,768,640,36,1280,720],
        MustBeSquare = False,
        CanRoundToNearest = True
    )

    ThumbnailObj : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=assetId).order_by(AssetThumbnail.asset_version_id.desc()).first()
    if ThumbnailObj is None:
        return redirect("/static/img/placeholder.png")
    if ThumbnailObj.moderation_status != 0 or ThumbnailObj.asset.moderation_status != 0:
        if ThumbnailObj.moderation_status == 2 or ThumbnailObj.asset.moderation_status == 2:
            return redirect("/static/img/ContentDeleted.png")
        return redirect("/static/img/placeholder.png")
    ContentHash = ThumbnailObj.content_hash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetX}-{TargetY}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetX,
        TargetHeight = TargetY,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120"
    )

@ImageRoute.route('/Thumbs/GroupIcon.ashx', methods=['GET'])
def groupicon():
    groupid = request.args.get( key='groupid', default=None, type=int )
    if groupid is None:
        return redirect("/static/img/placeholder.png")
    
    TargetX, TargetY = HandleResolutionCheck(
        WidthParametersName = [ 'x', 'width' ],
        HeightParametersName = [ 'y', 'height' ],
        AllowedWidths = [48,180,420,60,100,150,352],
        AllowedHeights = [48,180,420,60,100,150,352],
        MustBeSquare = True,
        CanRoundToNearest = True
    )

    ThumbnailObj : GroupIcon = GroupIcon.query.filter_by(group_id=groupid).first()
    if ThumbnailObj is None:
        return redirect("/static/img/placeholder.png")
    if ThumbnailObj.moderation_status != 0:
        if ThumbnailObj.moderation_status == 2:
            return redirect("/static/img/ContentDeleted.png")
        return redirect("/static/img/placeholder.png")
    
    ContentHash = ThumbnailObj.content_hash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetX}-{TargetY}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetX,
        TargetHeight = TargetY,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120"
    )

@ImageRoute.route('/Thumbs/GameIcon.ashx', methods=['GET'])
@ImageRoute.route('/Thumbs/PlaceIcon.ashx', methods=['GET'])
def placeicon():
    assetId = request.args.get('assetId', default = None, type = int) or request.args.get('assetid', default = None, type = int)
    if assetId is None:
        return redirect("/static/img/placeholder.png")
    
    TargetX, TargetY = HandleResolutionCheck(
        WidthParametersName = [ 'x', 'width' ],
        HeightParametersName = [ 'y', 'height' ],
        AllowedWidths = [48,180,420,60,100,150,352,324,576],
        AllowedHeights = [48,180,420,60,100,150,352,324,576],
        MustBeSquare = False,
        CanRoundToNearest = True
    )

    PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=assetId).first()
    if PlaceIconObj is None:
        return redirect("/static/img/placeholder.png")
    if PlaceIconObj.moderation_status != 0 or PlaceIconObj.asset.moderation_status != 0:
        if PlaceIconObj.moderation_status == 2 or PlaceIconObj.asset.moderation_status == 2:
            return redirect("/static/img/ContentDeleted.png")
        return redirect("/static/img/placeholder.png")

    ContentHash = PlaceIconObj.contenthash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetX}-{TargetY}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetX,
        TargetHeight = TargetY,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120"
    )

@ImageRoute.route('/Game/Tools/ThumbnailAsset.ashx', methods=['GET'])
def thumbnail_asset():
    ExpectedFormat : str = request.args.get( key='fmt', default='png', type=str )
    AssetId : int = request.args.get( key='aid', default=None, type=int )

    if AssetId is None:
        return redirect("/static/img/placeholder.png")
    if ExpectedFormat.lower() != "png":
        return redirect("/static/img/placeholder.png")

    AssetObj : Asset = Asset.query.filter_by(id=AssetId).first()
    if AssetObj is None:
        return redirect("/static/img/placeholder.png")
    
    TargetWidth, TargetHeight = HandleResolutionCheck(
        WidthParametersName = [ 'wd', 'width' ],
        HeightParametersName = [ 'ht', 'height' ],
        AllowedWidths = [48,180,420,60,100,150,352,75],
        AllowedHeights = [48,180,420,60,100,150,352,75],
        MustBeSquare = True,
        CanRoundToNearest = True
    )
    
    thumbnail : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=AssetId).order_by(AssetThumbnail.asset_version_id.desc()).first()
    if thumbnail is None:
        TakeThumbnail(AssetId)
        return redirect("/static/img/placeholder.png")
    if thumbnail.moderation_status != 0:
        if thumbnail.moderation_status == 2 or thumbnail.asset.moderation_status == 2:
            return redirect("/static/img/ContentDeleted.png")
        return redirect("/static/img/placeholder.png")
    
    ContentHash = thumbnail.content_hash
    CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetWidth}-{TargetHeight}-v3".encode('utf-8')).hexdigest()
    
    return HandleImageResize(
        ImageContentHash = ContentHash,
        TargetWidth = TargetWidth,
        TargetHeight = TargetHeight,
        CroppedHash = CroppedHash,
        CacheControl = "max-age=120"
    )

import urllib.parse

@ImageRoute.route("/v1/batch", methods=["POST"])
@csrf.exempt
def BatchImageRequest():
    if request.headers.get("Content-Encoding") == "gzip":
        try:
            data = gzip.decompress(request.data)
        except Exception as e:
            return jsonify({"success": False, "message": "Invalid gzip data"}), 400
        try:
            JSONData = json.loads(data)
        except Exception as e:
            return jsonify({"success": False, "message": "Invalid JSON data"}), 400
    else:
        JSONData = request.json
    if JSONData is None:
        return jsonify({"success": False, "message": "Missing JSON data"}), 400

    # [{'requestId': 'type=GameIcon&id=1&w=128&h=128&filters=', 'targetId': 1, 'type': 'GameIcon', 'size': '128x128', 'isCircular': False}]

    if len(JSONData) > 15:
        return jsonify({"success": False, "message": "Too many requests"}), 400
    if len(JSONData) == 0:
        return jsonify({"data":[]}), 200
    
    ProcessedRequests = []
    for RequestObj in JSONData:
        if "requestId" not in RequestObj or "targetId" not in RequestObj or "type" not in RequestObj or "size" not in RequestObj:
            continue
        if RequestObj["type"] not in [ "Avatar", "AvatarHeadShot", "GameIcon", "GameThumbnail", "Asset", "GroupIcon"]:
            continue

        if "x" not in RequestObj["size"]:
            continue
        SplittedSize = RequestObj["size"].split("x")
        if len(SplittedSize) != 2:
            continue
        try:
            TargetWidth = int(SplittedSize[0])
            TargetHeight = int(SplittedSize[1])
        except:
            continue

        AllowedSizes = [48,180,420,60,100,150,352,396,480,512,576,700,768,640,36,1280,720]
        TargetWidth = min(AllowedSizes, key=lambda x:abs(x-TargetWidth))
        TargetHeight = min(AllowedSizes, key=lambda x:abs(x-TargetHeight))

        RequestType = RequestObj["type"]

        if RequestType == "Avatar":
            ThumbnailObj : UserThumbnail = UserThumbnail.query.filter_by(userid=RequestObj["targetId"]).first()
            if ThumbnailObj is None:
                continue
            ContentHash = ThumbnailObj.full_contenthash
        elif RequestType == "AvatarHeadShot":
            ThumbnailObj : UserThumbnail = UserThumbnail.query.filter_by(userid=RequestObj["targetId"]).first()
            if ThumbnailObj is None:
                continue
            ContentHash = ThumbnailObj.headshot_contenthash
        elif RequestType == "GameIcon":
            PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=RequestObj["targetId"]).first()
            if PlaceIconObj is None:
                continue
            ContentHash = PlaceIconObj.contenthash
        elif RequestType == "GameThumbnail" or RequestType == "Asset":
            thumbnailObj : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=RequestObj["targetId"]).order_by(AssetThumbnail.asset_version_id.desc()).first()
            if thumbnailObj is None:
                continue
            if thumbnailObj.moderation_status != 0:
                continue
            ContentHash = thumbnailObj.content_hash
        elif RequestType == "GroupIcon":
            ThumbnailObj : GroupIcon = GroupIcon.query.filter_by(group_id=RequestObj["targetId"]).first()
            if ThumbnailObj is None:
                continue
            if ThumbnailObj.moderation_status != 0:
                continue
            ContentHash = ThumbnailObj.content_hash
        else:
            continue
        CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetWidth}-{TargetHeight}-v3".encode('utf-8')).hexdigest()
        if not s3helper.DoesKeyExist(CroppedHash):
            if not s3helper.DoesKeyExist(ContentHash):
                continue
            ImageContent = BytesIO( s3helper.GetFileFromS3(ContentHash) )
            ImageObj = Image.open(ImageContent)
            ImageObj = ImageObj.resize((int(TargetWidth),int(TargetHeight))).convert('RGBA')
            
            VirtualFile = BytesIO()
            ImageObj.save(VirtualFile, "PNG")
            VirtualFile.seek(0)
            s3helper.UploadBytesToS3(VirtualFile.getvalue(), CroppedHash, contentType="image/png")
        ProcessedRequests.append({
            "requestId": RequestObj["requestId"],
            "targetId": RequestObj["targetId"],
            "state": "Completed",
            "imageUrl": f"{config.CDN_URL}/{CroppedHash}",
            "version": None
        })

    return jsonify({
        "data": ProcessedRequests
    })

@ImageRoute.route("/v1/users/avatar-headshot", methods=["GET"])
def multi_avatar_headshot():
    userIdsCSV = request.args.get('userIds', default = None, type = str)
    if userIdsCSV is None:
        return jsonify( { "errors": [ { "code": 4, "message": "The requested Ids are invalid, of an invalid type or missing." } ] } ), 400
    
    userIds = userIdsCSV.split(",")
    if len(userIds) > 100:
        return jsonify( { "errors": [ { "code": 1, "message": "There are too many requested Ids." } ] } ), 400
    
    requestedSize = request.args.get('size', default = "48x48", type = str)

    if "x" not in requestedSize:
        return jsonify( { "errors": [ { "code": 3, "message": "The requested size is invalid. Please see documentation for valid thumbnail size parameter name and format." } ] } ), 400
    
    SplittedSize = requestedSize.split("x")
    if len(SplittedSize) != 2:
        return jsonify( { "errors": [ { "code": 3, "message": "The requested size is invalid. Please see documentation for valid thumbnail size parameter name and format." } ] } ), 400
    
    try:
        TargetWidth = int(SplittedSize[0])
        TargetHeight = int(SplittedSize[1])

        AllowedSizes = [48,180,420,60,100,150,352,396,480,512,576,700,768,640,36,1280,720]
        TargetWidth = min(AllowedSizes, key=lambda x:abs(x-TargetWidth))
        TargetHeight = min(AllowedSizes, key=lambda x:abs(x-TargetHeight))
    except:
        return jsonify( { "errors": [ { "code": 3, "message": "The requested size is invalid. Please see documentation for valid thumbnail size parameter name and format." } ] } ), 400

    ProcessedRequests = []
    for userId in userIds:
        try:
            userId = int(userId)
        except:
            continue
        ThumbnailObj : UserThumbnail = UserThumbnail.query.filter_by(userid=userId).first()
        if ThumbnailObj is None:
            continue
        ContentHash = ThumbnailObj.headshot_contenthash
        CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetWidth}-{TargetHeight}-v3".encode('utf-8')).hexdigest()
        if not s3helper.DoesKeyExist(CroppedHash):
            if not s3helper.DoesKeyExist(ContentHash):
                continue
            ImageContent = BytesIO( s3helper.GetFileFromS3(ContentHash) )
            ImageObj = Image.open(ImageContent)
            ImageObj = ImageObj.resize((int(TargetWidth),int(TargetHeight))).convert('RGBA')
            
            VirtualFile = BytesIO()
            ImageObj.save(VirtualFile, "PNG")
            VirtualFile.seek(0)
            s3helper.UploadBytesToS3(VirtualFile.getvalue(), CroppedHash, contentType="image/png")
        ProcessedRequests.append({
            "targetId": userId,
            "state": "Completed",
            #"imageUrl": f"{config.CDN_URL}/{CroppedHash}", # 2020 Does not allow things like cdn.syntax.eco to be used directly in the "Texture" property so we have to redirect them to an allowed route on the www. domain
            "imageUrl": f"{config.BaseURL}/headshot-thumbnail/image?userId={userId}&x={TargetWidth}&y={TargetHeight}",
            "version": "1"
        })

    return jsonify({
        "data": ProcessedRequests
    }), 200

@ImageRoute.route("/v1/games/icons", methods=["GET"])
def get_game_icons():
    universeIdsCSV = request.args.get('universeIds', default = None, type = str)
    if universeIdsCSV is None:
        return jsonify( { "errors": [ { "code": 4, "message": "The requested Ids are invalid, of an invalid type or missing." } ] } ), 400
    universeIdsList = universeIdsCSV.split(",")
    if len(universeIdsList) > 100:
        return jsonify( { "errors": [ { "code": 1, "message": "There are too many requested Ids." } ] } ), 400
    
    requestedSize = request.args.get('size', default = "50x50", type = str)
    if "x" not in requestedSize:
        return jsonify( { "errors": [ { "code": 3, "message": "The requested size is invalid. Please see documentation for valid thumbnail size parameter name and format." } ] } ), 400
    
    SplittedSize = requestedSize.split("x")
    if len(SplittedSize) != 2:
        return jsonify( { "errors": [ { "code": 3, "message": "The requested size is invalid. Please see documentation for valid thumbnail size parameter name and format." } ] } ), 400
    
    try:
        TargetWidth = int(SplittedSize[0])
        TargetHeight = int(SplittedSize[1])

        AllowedSizes = [50, 128, 150, 256, 420, 512]
        TargetWidth = min(AllowedSizes, key=lambda x:abs(x-TargetWidth))
        TargetHeight = min(AllowedSizes, key=lambda x:abs(x-TargetHeight))
    except:
        return jsonify( { "errors": [ { "code": 3, "message": "The requested size is invalid. Please see documentation for valid thumbnail size parameter name and format." } ] } ), 400
    
    ProcessedRequests = []
    for universeId in universeIdsList:
        try:
            universeId = int(universeId)
        except:
            continue
        PlaceIconObj : PlaceIcon = PlaceIcon.query.filter_by(placeid=universeId).first()
        if PlaceIconObj is None:
            continue
        ContentHash = PlaceIconObj.contenthash
        CroppedHash = hashlib.sha512(f"{ContentHash}-{TargetWidth}-{TargetHeight}-v3".encode('utf-8')).hexdigest()
        if not s3helper.DoesKeyExist(CroppedHash):
            if not s3helper.DoesKeyExist(ContentHash):
                continue
            ImageContent = BytesIO( s3helper.GetFileFromS3(ContentHash) )
            ImageObj = Image.open(ImageContent)
            ImageObj = ImageObj.resize((int(TargetWidth),int(TargetHeight))).convert('RGBA')
            
            VirtualFile = BytesIO()
            ImageObj.save(VirtualFile, "PNG")
            VirtualFile.seek(0)
            s3helper.UploadBytesToS3(VirtualFile.getvalue(), CroppedHash, contentType="image/png")
        ProcessedRequests.append({
            "targetId": universeId,
            "state": "Completed",
            #"imageUrl": f"{config.CDN_URL}/{CroppedHash}"
            "imageUrl": f"{config.BaseURL}/Thumbs/GameIcon.ashx?assetId={str(universeId)}&x={str(TargetWidth)}&y={str(TargetHeight)}"
        })

    return jsonify({
        "data": ProcessedRequests
    }), 200