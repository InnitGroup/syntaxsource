from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify
import base64
import json
from app.extensions import db, redis_controller, limiter, csrf
from app.util import auth, websiteFeatures
from app.enums.AssetType import AssetType

from app.models.asset import Asset
from app.models.user_avatar_asset import UserAvatarAsset
from app.models.user_avatar import UserAvatar
from app.models.userassets import UserAsset
from app.models.user_thumbnail import UserThumbnail
from app.models.user import User

from app.routes.thumbnailer import TakeUserThumbnail
AllowedBodyColors = [361, 192, 217, 153, 359, 352, 5, 101, 1007, 1014, 38, 18, 125, 1030, 133, 106, 105, 1017, 24, 334, 226, 141, 1021, 28, 37, 310, 317, 119, 1011, 1012, 1010, 23, 305, 102, 45, 107, 1018, 1027, 1019, 1013, 11, 1024, 104, 1023, 321, 1015, 1031, 1006, 1026, 21, 1004, 1032, 1016, 330, 9, 1025, 364, 351, 1008, 29, 1022, 151, 135, 1020, 1028, 1009, 1029, 1003, 26, 199, 194, 1002, 208, 1, 1001]
ScalingLimits = {
    "height": {
      "min": 0.9,
      "max": 1.05,
      "increment": 0.01
    },
    "width": {
      "min": 0.7,
      "max": 1,
      "increment": 0.01
    },
    "head": {
      "min": 0.95,
      "max": 1,
      "increment": 0.01
    },
    "proportion": {
      "min": 0,
      "max": 1,
      "increment": 0.01
    },
    "bodyType": {
      "min": 0,
      "max": 1,
      "increment": 0.01
    }
}
AvatarRoute = Blueprint('avatar', __name__, template_folder='pages')

@AvatarRoute.route('/avatar', methods=['GET'])
@auth.authenticated_required
def avatar():
    AuthenticatedUser : User = auth.GetCurrentUser()
    return render_template('avatar/avatar.html', user=AuthenticatedUser)

@AvatarRoute.route("/avatar/getassets", methods=["GET"])
@auth.authenticated_required_api
def get_assets():
    ReqAssetType = request.args.get("type")
    if ReqAssetType is None:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    try:
        ReqAssetType = int(ReqAssetType)
    except:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    if ReqAssetType not in [2,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    PageNumber = request.args.get("page") or 0
    try:
        PageNumber = int(PageNumber)
    except:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    PageNumber += 1

    AuthenticatedUser : User = auth.GetCurrentUser()
    AssetsList : list[UserAsset] = UserAsset.query.filter_by(userid=AuthenticatedUser.id).join(Asset, Asset.id == UserAsset.assetid).filter(Asset.asset_type == AssetType(ReqAssetType)).distinct(Asset.id).paginate( page=PageNumber, per_page=12, error_out=False)    
    AssetList = []
    for AssetObj in AssetsList.items:
        AssetObj : Asset = Asset.query.filter_by(id=AssetObj.assetid).first()
        if AssetObj is None:
            continue
        AssetList.append({
            "id": AssetObj.id,
            "name": AssetObj.name,
            "moderation_status": AssetObj.moderation_status
        })

    return jsonify({
        "success": True,
        "assets": AssetList,
        "lastPage": not AssetsList.has_next
    })

@AvatarRoute.route('/avatar/getavatar', methods=['GET'])
@auth.authenticated_required_api
def get_avatar():
    AuthenticatedUser : User = auth.GetCurrentUser()
    userCurrentlyWearing : list[UserAvatarAsset] = UserAvatarAsset.query.filter_by(user_id=AuthenticatedUser.id).all()
    userCurrentlyWearingList : list[int] = []
    for asset in userCurrentlyWearing:
        AssetObj : Asset = Asset.query.filter_by(id=asset.asset_id).first()
        userCurrentlyWearingList.append({
            "id": AssetObj.id,
            "name": AssetObj.name,
            "type": AssetObj.asset_type.value,
            "moderation_status": AssetObj.moderation_status
        })
    avatar : UserAvatar = UserAvatar.query.filter_by(user_id=AuthenticatedUser.id).first()
    return jsonify({
        "success": True,
        "currentlyWearing": userCurrentlyWearingList,
        "bodyColors": [
            avatar.head_color_id,
            avatar.torso_color_id,
            avatar.left_arm_color_id,
            avatar.right_arm_color_id,
            avatar.left_leg_color_id,
            avatar.right_leg_color_id
        ],
        "rigType": "R15" if avatar.r15 else "R6",
        "scales": {
            "height": avatar.height_scale,
            "width": avatar.width_scale,
            "head": avatar.head_scale,
            "proportion": avatar.proportion_scale,
            "bodyType": avatar.body_type_scale
        }
    })

@AvatarRoute.route("/avatar/setavatar", methods=["POST"])
@auth.authenticated_required_api
@csrf.exempt
def set_wearing_assets():
    if not websiteFeatures.GetWebsiteFeature("AvatarUpdate"):
        return jsonify({"success": False, "message": "Avatar updating is currently disabled."}), 400

    newAvatarData = request.json
    if "bodyColors" not in newAvatarData or "assets" not in newAvatarData or "rigType" not in newAvatarData:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    if len(newAvatarData["bodyColors"]) != 6:
        return jsonify({"success": False, "message": "Invalid request"}), 400

    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return redirect('/login')
    if redis_controller.get(f"avatar:lock:{AuthenticatedUser.id}") is not None:
        return jsonify({"success": False, "message": "You are changing your avatar too fast."}), 429
    redis_controller.set(f"avatar:lock:{AuthenticatedUser.id}", "1", ex=5)
    avatar : UserAvatar = UserAvatar.query.filter_by(user_id=AuthenticatedUser.id).first()

    if len(newAvatarData["assets"]) > 32:
        return jsonify({"success": False, "message": "Too many assets"}), 400
    AssetTypeCount = {}
    for asset in newAvatarData["assets"]:
        AssetObj : Asset = Asset.query.filter_by(id=asset).first()
        if AssetObj is None:
            return jsonify({"success": False, "message": "Invalid asset"}), 400
        if AssetObj.asset_type.value not in [2,8,11,12,17,18,19,27,28,29,30,31,32,41,42,43,44,45,46,47,57,58]:
            return jsonify({"success": False, "message": "Invalid asset"}), 400
        if AssetTypeCount.get(AssetObj.asset_type.value) is None:
            AssetTypeCount[AssetObj.asset_type.value] = 1
        else:
            AssetTypeCount[AssetObj.asset_type.value] += 1
        if AssetTypeCount[AssetObj.asset_type.value] > 1 and AssetObj.asset_type != AssetType.Hat and AssetObj.asset_type != AssetType.HairAccessory and AssetObj.asset_type != AssetType.FaceAccessory:
            return jsonify({"success": False, "message": "Invalid configuration"}), 400
        elif AssetTypeCount[AssetObj.asset_type.value] > 5 and AssetObj.asset_type == AssetType.Hat:
            return jsonify({"success": False, "message": "Invalid configuration"}), 400
        
        if AssetObj.moderation_status != 0:
            newAvatarData["assets"].remove(asset)
        
        UserAssetObj : UserAsset = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=asset).first()
        if UserAssetObj is None:
            return jsonify({"success": False, "message": "Invalid asset"}), 400
    for Color in newAvatarData["bodyColors"]:
        if Color not in AllowedBodyColors:
            return jsonify({"success": False, "message": "Invalid body color"}), 400
    
    UserAvatarAsset.query.filter_by(user_id=AuthenticatedUser.id).delete()
    db.session.commit()
    for asset in newAvatarData["assets"]:
        UserAvatarAssetObj = UserAvatarAsset(
            user_id=AuthenticatedUser.id,
            asset_id=asset
        )
        db.session.add(UserAvatarAssetObj)
    avatar.head_color_id = newAvatarData["bodyColors"][0]
    avatar.torso_color_id = newAvatarData["bodyColors"][1]
    avatar.left_arm_color_id = newAvatarData["bodyColors"][2]
    avatar.right_arm_color_id = newAvatarData["bodyColors"][3]
    avatar.left_leg_color_id = newAvatarData["bodyColors"][4]
    avatar.right_leg_color_id = newAvatarData["bodyColors"][5]
    avatar.r15 = newAvatarData["rigType"] == "R15"

    if "scales" in newAvatarData:
        if "height" not in newAvatarData["scales"] or "width" not in newAvatarData["scales"] or "head" not in newAvatarData["scales"] or "proportion" not in newAvatarData["scales"]:
            return jsonify({"success": False, "message": "Invalid request"}), 400
        if newAvatarData["scales"]["height"] < ScalingLimits["height"]["min"] or newAvatarData["scales"]["height"] > ScalingLimits["height"]["max"]:
            return jsonify({"success": False, "message": "Invalid height scale"}), 400
        if newAvatarData["scales"]["width"] < ScalingLimits["width"]["min"] or newAvatarData["scales"]["width"] > ScalingLimits["width"]["max"]:
            return jsonify({"success": False, "message": "Invalid width scale"}), 400
        if newAvatarData["scales"]["head"] < ScalingLimits["head"]["min"] or newAvatarData["scales"]["head"] > ScalingLimits["head"]["max"]:
            return jsonify({"success": False, "message": "Invalid head scale"}), 400
        if newAvatarData["scales"]["proportion"] < ScalingLimits["proportion"]["min"] or newAvatarData["scales"]["proportion"] > ScalingLimits["proportion"]["max"]:
            return jsonify({"success": False, "message": "Invalid proportion scale"}), 400
        
        avatar.height_scale = round(newAvatarData["scales"]["height"], 2)
        avatar.width_scale = round(newAvatarData["scales"]["width"], 2)
        avatar.head_scale = round(newAvatarData["scales"]["head"], 2)
        avatar.proportion_scale = round(newAvatarData["scales"]["proportion"], 2)

    db.session.commit()

    UserThumbnail.query.filter_by(userid=AuthenticatedUser.id).delete()
    db.session.commit()
    TakeUserThumbnail(AuthenticatedUser.id, True, False)
    return jsonify({"success": True}), 200

@AvatarRoute.route("/avatar/forceredraw", methods=["POST"])
@auth.authenticated_required_api
@csrf.exempt
def force_redraw():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if redis_controller.get(f"avatar:lock:{AuthenticatedUser.id}") is not None:
        return jsonify({"success": False, "message": "A redraw has recently been started please try again later."}), 429
    redis_controller.set(f"avatar:lock:{AuthenticatedUser.id}", "1", ex=5)
    UserThumbnail.query.filter_by(userid=AuthenticatedUser.id).delete()
    db.session.commit()
    TakeUserThumbnail(AuthenticatedUser.id, True, True)
    return jsonify({"success": True}), 200

@AvatarRoute.route("/avatar/isthumbnailready", methods=["GET"])
@auth.authenticated_required_api
@csrf.exempt
def is_thumbnail_ready():
    AuthenticateUser : User = auth.GetCurrentUser()
    UserThumbnailObj : UserThumbnail = UserThumbnail.query.filter_by(userid=AuthenticateUser.id).first()
    if UserThumbnailObj is None:
        return jsonify({"success": True, "ready": False}), 200
    else:
        if UserThumbnailObj.full_contenthash is None:
            return jsonify({"success": True, "ready": False}), 200
        return jsonify({"success": True, "ready": True}), 200