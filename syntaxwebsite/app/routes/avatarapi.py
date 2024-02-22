# avatar.roblox.com
import logging
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, abort, jsonify, make_response
from app.util import auth
from app.extensions import db, csrf, limiter, user_limiter
from flask_wtf.csrf import CSRFError, generate_csrf

from app.routes.thumbnailer import TakeUserThumbnail

from app.models.user_avatar import UserAvatar
from app.models.user_avatar_asset import UserAvatarAsset
from app.models.user import User
from app.models.asset import Asset
from app.models.userassets import UserAsset

from app.enums.AssetType import AssetType

AvatarAPIRoute = Blueprint('avatarapi', __name__, url_prefix='/')

csrf.exempt(AvatarAPIRoute)
@AvatarAPIRoute.errorhandler(CSRFError)
def handle_csrf_error(e):
    ErrorResponse = make_response(jsonify({
        "errors": [
            {
                "code": 0,
                "message": "Token Validation Failed"
            }
        ]
    }))

    ErrorResponse.status_code = 403
    ErrorResponse.headers["x-csrf-token"] = generate_csrf()
    return ErrorResponse

@AvatarAPIRoute.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({
        "errors": [
            {
                "code": 9,
                "message": "The flood limit has been exceeded."
            }
        ]
    }), 429

@AvatarAPIRoute.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        csrf.protect()

@AvatarAPIRoute.route("/v1/avatar", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def get_authenticated_user_avatar():
    AuthenticatedUser : User = auth.GetCurrentUser()

    UserAvatarObject : UserAvatar = UserAvatar.query.filter_by(user_id = AuthenticatedUser.id).first()
    if UserAvatarObject is None:
        UserAvatarObject = UserAvatar(AuthenticatedUser.id)
        db.session.add(UserAvatarObject)
        db.session.commit()

    UserAvatarAssetObject : list[UserAvatarAsset] = UserAvatarAsset.query.filter_by(user_id = AuthenticatedUser.id).all()
    WearingAssets : list[dict] = []

    for AvatarAsset in UserAvatarAssetObject:
        AssetObject : Asset = AvatarAsset.asset
        WearingAssets.append({
            "id": AvatarAsset.asset_id,
            "name": AssetObject.name,
            "assetType": {
                "id": AssetObject.asset_type.value,
                "name": AssetObject.asset_type.name
            },
            "currentVersionId": AssetObject.id
        })

    return jsonify({
        "scales": {
            "height": UserAvatarObject.height_scale,
            "width": UserAvatarObject.width_scale,
            "head": UserAvatarObject.head_scale,
            "depth": 1,
            "proportion": UserAvatarObject.proportion_scale,
            "bodyType": UserAvatarObject.body_type_scale
        },
        "playerAvatarType": "R6" if not UserAvatarObject.r15 else "R15",
        "bodyColors": {
            "headColorId": UserAvatarObject.head_color_id,
            "torsoColorId": UserAvatarObject.torso_color_id,
            "rightArmColorId": UserAvatarObject.right_arm_color_id,
            "leftArmColorId": UserAvatarObject.left_arm_color_id,
            "rightLegColorId": UserAvatarObject.right_leg_color_id,
            "leftLegColorId": UserAvatarObject.left_leg_color_id
        },
        "assets": WearingAssets,
        "defaultShirtApplied": False,
        "defaultPantsApplied": False,
        "emotes": []
    })

@AvatarAPIRoute.route("/v1/avatar/metadata", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def get_avatar_editor_metadata():
    return jsonify({
        "enableDefaultClothingMessage": False,
        "isAvatarScaleEmbeddedInTab": True,
        "isBodyTypeScaleOutOfTab": True,
        "scaleHeightIncrement": 0.05,
        "scaleWidthIncrement": 0.05,
        "scaleHeadIncrement": 0.05,
        "scaleProportionIncrement": 0.05,
        "scaleBodyTypeIncrement": 0.05,
        "supportProportionAndBodyType": True,
        "showDefaultClothingMessageOnPageLoad": False,
        "areThreeDeeThumbsEnabled": False,
        "isAvatarWearingApiCallsLockingOnFrontendEnabled": True,
        "isOutfitHandlingOnFrontendEnabled": True,
        "isJustinUiChangesEnabled": True,
        "isCategoryReorgEnabled": True,
        "LCEnabledInEditorAndCatalog": True,
        "isLCCompletelyEnabled": True
    })

@AvatarAPIRoute.route("/v1/avatar-rules", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def get_avatar_editor_rules():
    return jsonify({"playerAvatarTypes":["R6","R15"],"scales":{"height":{"min":0.9,"max":1.05,"increment":0.01},"width":{"min":0.7,"max":1,"increment":0.01},"head":{"min":0.95,"max":1,"increment":0.01},"proportion":{"min":0,"max":1,"increment":0.01},"bodyType":{"min":0,"max":1,"increment":0.01}},"wearableAssetTypes":[{"maxNumber":1,"id":18,"name":"Face"},{"maxNumber":1,"id":19,"name":"Gear"},{"maxNumber":1,"id":17,"name":"Head"},{"maxNumber":1,"id":29,"name":"Left Arm"},{"maxNumber":1,"id":30,"name":"Left Leg"},{"maxNumber":1,"id":12,"name":"Pants"},{"maxNumber":1,"id":28,"name":"Right Arm"},{"maxNumber":1,"id":31,"name":"Right Leg"},{"maxNumber":1,"id":11,"name":"Shirt"},{"maxNumber":1,"id":2,"name":"T-Shirt"},{"maxNumber":1,"id":27,"name":"Torso"},{"maxNumber":1,"id":48,"name":"Climb Animation"},{"maxNumber":1,"id":49,"name":"Death Animation"},{"maxNumber":1,"id":50,"name":"Fall Animation"},{"maxNumber":1,"id":51,"name":"Idle Animation"},{"maxNumber":1,"id":52,"name":"Jump Animation"},{"maxNumber":1,"id":53,"name":"Run Animation"},{"maxNumber":1,"id":54,"name":"Swim Animation"},{"maxNumber":1,"id":55,"name":"Walk Animation"},{"maxNumber":1,"id":56,"name":"Pose Animation"},{"maxNumber":0,"id":61,"name":"Emote Animation"},{"maxNumber":3,"id":8,"name":"Hat"},{"maxNumber":5,"id":41,"name":"Hair Accessory"},{"maxNumber":5,"id":42,"name":"Face Accessory"},{"maxNumber":1,"id":43,"name":"Neck Accessory"},{"maxNumber":1,"id":44,"name":"Shoulder Accessory"},{"maxNumber":1,"id":45,"name":"Front Accessory"},{"maxNumber":1,"id":46,"name":"Back Accessory"},{"maxNumber":1,"id":47,"name":"Waist Accessory"},{"maxNumber":1,"id":72,"name":"Dress Skirt Accessory"},{"maxNumber":1,"id":67,"name":"Jacket Accessory"},{"maxNumber":1,"id":70,"name":"Left Shoe Accessory"},{"maxNumber":1,"id":71,"name":"Right Shoe Accessory"},{"maxNumber":1,"id":66,"name":"Pants Accessory"},{"maxNumber":1,"id":65,"name":"Shirt Accessory"},{"maxNumber":1,"id":69,"name":"Shorts Accessory"},{"maxNumber":1,"id":68,"name":"Sweater Accessory"},{"maxNumber":1,"id":64,"name":"T-Shirt Accessory"},{"maxNumber":1,"id":76,"name":"Eyebrow Accessory"},{"maxNumber":1,"id":77,"name":"Eyelash Accessory"},{"maxNumber":1,"id":78,"name":"Mood Animation"},{"maxNumber":1,"id":79,"name":"Dynamic Head"}],"bodyColorsPalette":[{"brickColorId":361,"hexColor":"#564236","name":"Dirt brown"},{"brickColorId":192,"hexColor":"#694028","name":"Reddish brown"},{"brickColorId":217,"hexColor":"#7C5C46","name":"Brown"},{"brickColorId":153,"hexColor":"#957977","name":"Sand red"},{"brickColorId":359,"hexColor":"#AF9483","name":"Linen"},{"brickColorId":352,"hexColor":"#C7AC78","name":"Burlap"},{"brickColorId":5,"hexColor":"#D7C59A","name":"Brick yellow"},{"brickColorId":101,"hexColor":"#DA867A","name":"Medium red"},{"brickColorId":1007,"hexColor":"#A34B4B","name":"Dusty Rose"},{"brickColorId":1014,"hexColor":"#AA5500","name":"CGA brown"},{"brickColorId":38,"hexColor":"#A05F35","name":"Dark orange"},{"brickColorId":18,"hexColor":"#CC8E69","name":"Nougat"},{"brickColorId":125,"hexColor":"#EAB892","name":"Light orange"},{"brickColorId":1030,"hexColor":"#FFCC99","name":"Pastel brown"},{"brickColorId":133,"hexColor":"#D5733D","name":"Neon orange"},{"brickColorId":106,"hexColor":"#DA8541","name":"Bright orange"},{"brickColorId":105,"hexColor":"#E29B40","name":"Br. yellowish orange"},{"brickColorId":1017,"hexColor":"#FFAF00","name":"Deep orange"},{"brickColorId":24,"hexColor":"#F5CD30","name":"Bright yellow"},{"brickColorId":334,"hexColor":"#F8D96D","name":"Daisy orange"},{"brickColorId":226,"hexColor":"#FDEA8D","name":"Cool yellow"},{"brickColorId":141,"hexColor":"#27462D","name":"Earth green"},{"brickColorId":1021,"hexColor":"#3A7D15","name":"Camo"},{"brickColorId":28,"hexColor":"#287F47","name":"Dark green"},{"brickColorId":37,"hexColor":"#4B974B","name":"Bright green"},{"brickColorId":310,"hexColor":"#5B9A4C","name":"Shamrock"},{"brickColorId":317,"hexColor":"#7C9C6B","name":"Moss"},{"brickColorId":119,"hexColor":"#A4BD47","name":"Br. yellowish green"},{"brickColorId":1011,"hexColor":"#002060","name":"Navy blue"},{"brickColorId":1012,"hexColor":"#2154B9","name":"Deep blue"},{"brickColorId":1010,"hexColor":"#0000FF","name":"Really blue"},{"brickColorId":23,"hexColor":"#0D69AC","name":"Bright blue"},{"brickColorId":305,"hexColor":"#527CAE","name":"Steel blue"},{"brickColorId":102,"hexColor":"#6E99CA","name":"Medium blue"},{"brickColorId":45,"hexColor":"#B4D2E4","name":"Light blue"},{"brickColorId":107,"hexColor":"#008F9C","name":"Bright bluish green"},{"brickColorId":1018,"hexColor":"#12EED4","name":"Teal"},{"brickColorId":1027,"hexColor":"#9FF3E9","name":"Pastel blue-green"},{"brickColorId":1019,"hexColor":"#00FFFF","name":"Toothpaste"},{"brickColorId":1013,"hexColor":"#04AFEC","name":"Cyan"},{"brickColorId":11,"hexColor":"#80BBDC","name":"Pastel Blue"},{"brickColorId":1024,"hexColor":"#AFDDFF","name":"Pastel light blue"},{"brickColorId":104,"hexColor":"#6B327C","name":"Bright violet"},{"brickColorId":1023,"hexColor":"#8C5B9F","name":"Lavender"},{"brickColorId":321,"hexColor":"#A75E9B","name":"Lilac"},{"brickColorId":1015,"hexColor":"#AA00AA","name":"Magenta"},{"brickColorId":1031,"hexColor":"#6225D1","name":"Royal purple"},{"brickColorId":1006,"hexColor":"#B480FF","name":"Alder"},{"brickColorId":1026,"hexColor":"#B1A7FF","name":"Pastel violet"},{"brickColorId":21,"hexColor":"#C4281C","name":"Bright red"},{"brickColorId":1004,"hexColor":"#FF0000","name":"Really red"},{"brickColorId":1032,"hexColor":"#FF00BF","name":"Hot pink"},{"brickColorId":1016,"hexColor":"#FF66CC","name":"Pink"},{"brickColorId":330,"hexColor":"#FF98DC","name":"Carnation pink"},{"brickColorId":9,"hexColor":"#E8BAC8","name":"Light reddish violet"},{"brickColorId":1025,"hexColor":"#FFC9C9","name":"Pastel orange"},{"brickColorId":364,"hexColor":"#5A4C42","name":"Dark taupe"},{"brickColorId":351,"hexColor":"#BC9B5D","name":"Cork"},{"brickColorId":1008,"hexColor":"#C1BE42","name":"Olive"},{"brickColorId":29,"hexColor":"#A1C48C","name":"Medium green"},{"brickColorId":1022,"hexColor":"#7F8E64","name":"Grime"},{"brickColorId":151,"hexColor":"#789082","name":"Sand green"},{"brickColorId":135,"hexColor":"#74869D","name":"Sand blue"},{"brickColorId":1020,"hexColor":"#00FF00","name":"Lime green"},{"brickColorId":1028,"hexColor":"#CCFFCC","name":"Pastel green"},{"brickColorId":1009,"hexColor":"#FFFF00","name":"New Yeller"},{"brickColorId":1029,"hexColor":"#FFFFCC","name":"Pastel yellow"},{"brickColorId":1003,"hexColor":"#111111","name":"Really black"},{"brickColorId":26,"hexColor":"#1B2A35","name":"Black"},{"brickColorId":199,"hexColor":"#635F62","name":"Dark stone grey"},{"brickColorId":194,"hexColor":"#A3A2A5","name":"Medium stone grey"},{"brickColorId":1002,"hexColor":"#CDCDCD","name":"Mid gray"},{"brickColorId":208,"hexColor":"#E5E4DF","name":"Light stone grey"},{"brickColorId":1,"hexColor":"#F2F3F3","name":"White"},{"brickColorId":1001,"hexColor":"#F8F8F8","name":"Institutional white"}],"basicBodyColorsPalette":[{"brickColorId":364,"hexColor":"#5A4C42","name":"Dark taupe"},{"brickColorId":217,"hexColor":"#7C5C46","name":"Brown"},{"brickColorId":359,"hexColor":"#AF9483","name":"Linen"},{"brickColorId":18,"hexColor":"#CC8E69","name":"Nougat"},{"brickColorId":125,"hexColor":"#EAB892","name":"Light orange"},{"brickColorId":361,"hexColor":"#564236","name":"Dirt brown"},{"brickColorId":192,"hexColor":"#694028","name":"Reddish brown"},{"brickColorId":351,"hexColor":"#BC9B5D","name":"Cork"},{"brickColorId":352,"hexColor":"#C7AC78","name":"Burlap"},{"brickColorId":5,"hexColor":"#D7C59A","name":"Brick yellow"},{"brickColorId":153,"hexColor":"#957977","name":"Sand red"},{"brickColorId":1007,"hexColor":"#A34B4B","name":"Dusty Rose"},{"brickColorId":101,"hexColor":"#DA867A","name":"Medium red"},{"brickColorId":1025,"hexColor":"#FFC9C9","name":"Pastel orange"},{"brickColorId":330,"hexColor":"#FF98DC","name":"Carnation pink"},{"brickColorId":135,"hexColor":"#74869D","name":"Sand blue"},{"brickColorId":305,"hexColor":"#527CAE","name":"Steel blue"},{"brickColorId":11,"hexColor":"#80BBDC","name":"Pastel Blue"},{"brickColorId":1026,"hexColor":"#B1A7FF","name":"Pastel violet"},{"brickColorId":321,"hexColor":"#A75E9B","name":"Lilac"},{"brickColorId":107,"hexColor":"#008F9C","name":"Bright bluish green"},{"brickColorId":310,"hexColor":"#5B9A4C","name":"Shamrock"},{"brickColorId":317,"hexColor":"#7C9C6B","name":"Moss"},{"brickColorId":29,"hexColor":"#A1C48C","name":"Medium green"},{"brickColorId":105,"hexColor":"#E29B40","name":"Br. yellowish orange"},{"brickColorId":24,"hexColor":"#F5CD30","name":"Bright yellow"},{"brickColorId":334,"hexColor":"#F8D96D","name":"Daisy orange"},{"brickColorId":199,"hexColor":"#635F62","name":"Dark stone grey"},{"brickColorId":1002,"hexColor":"#CDCDCD","name":"Mid gray"},{"brickColorId":1001,"hexColor":"#F8F8F8","name":"Institutional white"}],"minimumDeltaEBodyColorDifference":11.4,"proportionsAndBodyTypeEnabledForUser":True,"defaultClothingAssetLists":{"defaultShirtAssetIds":[855776103,855760101,855766176,855777286,855768342,855779323,855773575,855778084],"defaultPantAssetIds":[855783877,855780360,855781078,855782781,855781508,855785499,855782253,855784936]},"bundlesEnabledForUser":False,"emotesEnabledForUser":False})

@AvatarAPIRoute.route("/v1/avatar/set-player-avatar-type", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("30/minute")
@user_limiter.limit("30/minute")
def set_player_avatar_type():
    AuthenticatedUser : User = auth.GetCurrentUser()

    if not request.is_json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if "playerAvatarType" not in request.json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if request.json["playerAvatarType"] not in ["R6", "R15"]:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    UserAvatarObject : UserAvatar = UserAvatar.query.filter_by(user_id = AuthenticatedUser.id).first()
    if UserAvatarObject is None:
        UserAvatarObject = UserAvatar(AuthenticatedUser.id)
        db.session.add(UserAvatarObject)
        db.session.commit()

    UserAvatarObject.r15 = True if request.json["playerAvatarType"] == "R15" else False
    db.session.commit()

    TakeUserThumbnail(AuthenticatedUser.id)

    return jsonify({
        "success": True
    })

@AvatarAPIRoute.route("/v1/avatar/set-scales", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("30/minute")
@user_limiter.limit("30/minute")
def set_player_avatar_scale():
    AuthenticatedUser : User = auth.GetCurrentUser()

    if not request.is_json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if "height" not in request.json or "width" not in request.json or "head" not in request.json or "proportion" not in request.json or "bodyType" not in request.json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    AvatarScales = {}

    try:
        AvatarScales["height"] = float(request.json["height"])
        AvatarScales["width"] = float(request.json["width"])
        AvatarScales["head"] = float(request.json["head"])
        AvatarScales["proportion"] = float(request.json["proportion"])
        AvatarScales["bodyType"] = float(request.json["bodyType"])
    except ValueError:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if AvatarScales["height"] < 0.9 or AvatarScales["height"] > 1.05 or AvatarScales["width"] < 0.7 or AvatarScales["width"] > 1 or AvatarScales["head"] < 0.95 or AvatarScales["head"] > 1 or AvatarScales["proportion"] < 0 or AvatarScales["proportion"] > 1 or AvatarScales["bodyType"] < 0 or AvatarScales["bodyType"] > 1:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    UserAvatarObject : UserAvatar = UserAvatar.query.filter_by(user_id = AuthenticatedUser.id).first()
    if UserAvatarObject is None:
        UserAvatarObject = UserAvatar(AuthenticatedUser.id)
        db.session.add(UserAvatarObject)
        db.session.commit()

    UserAvatarObject.height_scale = AvatarScales["height"]
    UserAvatarObject.width_scale = AvatarScales["width"]
    UserAvatarObject.head_scale = AvatarScales["head"]
    UserAvatarObject.proportion_scale = AvatarScales["proportion"]
    UserAvatarObject.body_type_scale = AvatarScales["bodyType"]
    db.session.commit()

    TakeUserThumbnail(AuthenticatedUser.id)
    return jsonify({
        "success": True
    })

AllowedBodyColors = [361, 192, 217, 153, 359, 352, 5, 101, 1007, 1014, 38, 18, 125, 1030, 133, 106, 105, 1017, 24, 334, 226, 141, 1021, 28, 37, 310, 317, 119, 1011, 1012, 1010, 23, 305, 102, 45, 107, 1018, 1027, 1019, 1013, 11, 1024, 104, 1023, 321, 1015, 1031, 1006, 1026, 21, 1004, 1032, 1016, 330, 9, 1025, 364, 351, 1008, 29, 1022, 151, 135, 1020, 1028, 1009, 1029, 1003, 26, 199, 194, 1002, 208, 1, 1001]

@AvatarAPIRoute.route("/v1/avatar/set-body-colors", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("30/minute")
@user_limiter.limit("30/minute")
def set_player_avatar_body_colors():
    AuthenticatedUser : User = auth.GetCurrentUser()

    if not request.is_json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if "headColorId" not in request.json or "torsoColorId" not in request.json or "rightArmColorId" not in request.json or "leftArmColorId" not in request.json or "rightLegColorId" not in request.json or "leftLegColorId" not in request.json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if not isinstance(request.json["headColorId"], int) or not isinstance(request.json["torsoColorId"], int) or not isinstance(request.json["rightArmColorId"], int) or not isinstance(request.json["leftArmColorId"], int) or not isinstance(request.json["rightLegColorId"], int) or not isinstance(request.json["leftLegColorId"], int):
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if request.json["headColorId"] not in AllowedBodyColors or request.json["torsoColorId"] not in AllowedBodyColors or request.json["rightArmColorId"] not in AllowedBodyColors or request.json["leftArmColorId"] not in AllowedBodyColors or request.json["rightLegColorId"] not in AllowedBodyColors or request.json["leftLegColorId"] not in AllowedBodyColors:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    UserAvatarObject : UserAvatar = UserAvatar.query.filter_by(user_id = AuthenticatedUser.id).first()
    if UserAvatarObject is None:
        UserAvatarObject = UserAvatar(AuthenticatedUser.id)
        db.session.add(UserAvatarObject)
        db.session.commit()

    UserAvatarObject.head_color_id = request.json["headColorId"]
    UserAvatarObject.torso_color_id = request.json["torsoColorId"]
    UserAvatarObject.right_arm_color_id = request.json["rightArmColorId"]
    UserAvatarObject.left_arm_color_id = request.json["leftArmColorId"]
    UserAvatarObject.right_leg_color_id = request.json["rightLegColorId"]
    UserAvatarObject.left_leg_color_id = request.json["leftLegColorId"]

    db.session.commit()
    TakeUserThumbnail(AuthenticatedUser.id)

    return jsonify({
        "success": True
    })

@AvatarAPIRoute.route("/v1/avatar/set-wearing-assets", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("30/minute")
@user_limiter.limit("30/minute")
def set_player_avatar_wearing_assets():
    AuthenticatedUser : User = auth.GetCurrentUser()

    if not request.is_json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400

    if "assetIds" not in request.json:
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    if not isinstance(request.json["assetIds"], list):
        return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
    
    InvalidAssetIds : list[int] = []
    AssetTypeCounter : dict[int, int] = {}
    AllowedAssetIds : list[int] = []

    for AssetId in request.json["assetIds"]:
        try:
            AssetId = int(AssetId)
        except ValueError:
            return jsonify({"errors": [{"code": 0, "message": "Invalid JSON"}]}), 400
        
        if AssetId in InvalidAssetIds or AssetId in AllowedAssetIds:
            continue
        UserAssetObj : UserAsset = UserAsset.query.filter_by(userid = AuthenticatedUser.id, assetid = AssetId).first()

        if UserAssetObj is None:
            InvalidAssetIds.append(AssetId)
            continue

        AssetObj : Asset = UserAssetObj.asset

        if AssetObj.moderation_status != 0:
            InvalidAssetIds.append(AssetId)
            continue
        if AssetObj.asset_type.value not in [2,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
            return jsonify({"errors": [{"code": 3, "message": "Invalid AssetId"}]}), 400
        
        if AssetObj.asset_type.value not in AssetTypeCounter:
            AssetTypeCounter[AssetObj.asset_type.value] = 0

        if AssetTypeCounter[AssetObj.asset_type.value] >= 1 and AssetObj.asset_type != AssetType.Hat:
            return jsonify({"errors": [{"code": 3, "message": "Invalid AssetId"}]}), 400
        if AssetTypeCounter[AssetObj.asset_type.value] >= 3 and AssetObj.asset_type == AssetType.Hat:
            return jsonify({"errors": [{"code": 3, "message": "Invalid AssetId"}]}), 400

        AssetTypeCounter[AssetObj.asset_type.value] += 1
        AllowedAssetIds.append(AssetId)

    UserAvatarAsset.query.filter_by(user_id = AuthenticatedUser.id).delete()
    db.session.commit()

    for AssetId in AllowedAssetIds:
        NewAvatarAssetObj : UserAvatarAsset = UserAvatarAsset( user_id = AuthenticatedUser.id, asset_id = AssetId )
        db.session.add(NewAvatarAssetObj)

    db.session.commit()
    TakeUserThumbnail(AuthenticatedUser.id)

    return jsonify({
        "invalidAssetIds": InvalidAssetIds,
        "success": True
    })

