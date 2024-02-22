# inventory.roblox.com

from flask import Blueprint, jsonify, request, make_response
from flask_wtf.csrf import CSRFError, generate_csrf
from app.extensions import db, redis_controller, limiter, csrf
from app.models.user import User
from app.models.userassets import UserAsset
from app.models.asset import Asset
from app.util import membership
from app.enums.AssetType import AssetType
from app.enums.MembershipType import MembershipType

InventoryAPI = Blueprint('InventoryAPI', __name__, url_prefix='/')
csrf.exempt(InventoryAPI)
@InventoryAPI.errorhandler(CSRFError)
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

@InventoryAPI.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({
        "errors": [
            {
                "code": 9,
                "message": "The flood limit has been exceeded."
            }
        ]
    }), 429

@InventoryAPI.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        csrf.protect()

itemTypes = {
    "asset": 0,
    "gamepass": 1,
    "badge": 2,
    "bundle": 3
}

@InventoryAPI.route('/v1/users/<int:userId>/items/<itemType>/<int:itemTargetId>', methods=['GET'])
@limiter.limit("60/minute")
def get_user_item(userId : int , itemType : str , itemTargetId : int):
    userObject : User = User.query.filter_by(id=userId).first()
    if userObject is None:
        return jsonify( { "errors": [ { "code": 1, "message": "The specified user does not exist!" } ] } ), 400
    
    try:
        itemType = int(itemType)
        if itemType < 0 or itemType > 3:
            return jsonify( { "errors": [ { "code": 6, "message": "The specified item type does not exist." } ] } ), 400
    except ValueError:
        if itemType.lower() not in itemTypes:
            return jsonify( { "errors": [ { "code": 7, "message": "The specified Asset does not exist!" } ] } ), 400
        
        itemType = itemTypes[itemType.lower()]

    assetObj : Asset = Asset.query.filter_by(id=itemTargetId).first()
    if assetObj is None:
        return jsonify( { "errors": [ { "code": 3, "message": "The specified item does not exist!" } ] } ), 400

    dataList = []

    userAssetList : list[UserAsset] = UserAsset.query.filter_by(userid=userId, assetid=itemTargetId).all()
    for user_asset_obj in userAssetList:
        dataList.append({
            "type": "Asset",
            "id": user_asset_obj.assetid,
            "name": user_asset_obj.asset.name,
            "instanceId": user_asset_obj.id,
        })

    return jsonify({
        "previousPageCursor": None,
        "nextPageCursor": None,
        "data": dataList
    }), 200

@InventoryAPI.route('/v1/users/<int:userId>/items/<itemType>/<int:itemTargetId>/is-owned', methods=['GET'])
@limiter.limit("60/minute")
def lookup_user_ownership(userId : int , itemType , itemTargetId : int):
    userObject : User = User.query.filter_by(id=userId).first()
    if userObject is None:
        return jsonify( { "errors": [ { "code": 1, "message": "The specified user does not exist!" } ] } ), 400
    
    try:
        itemType = int(itemType)
        if itemType < 0 or itemType > 3:
            return jsonify( { "errors": [ { "code": 6, "message": "The specified item type does not exist." } ] } ), 400
    except ValueError:
        if itemType.lower() not in itemTypes:
            return jsonify( { "errors": [ { "code": 7, "message": "The specified Asset does not exist!" } ] } ), 400
        
        itemType = itemTypes[itemType.lower()]

    assetObj : Asset = Asset.query.filter_by(id=itemTargetId).first()
    if assetObj is None:
        return jsonify( { "errors": [ { "code": 3, "message": "The specified item does not exist!" } ] } ), 400
    
    userAssetObj : UserAsset = UserAsset.query.filter_by(userid=userId, assetid=itemTargetId).first()
    if userAssetObj is None:
        return "false", 200
    
    return "true", 200

#@InventoryAPI.route('/v2/users/<int:userId>/inventory', methods=['GET'])
@InventoryAPI.route('/v2/users/<int:userId>/inventory/<int:assetTypeId>/', methods=['GET'])
@InventoryAPI.route('/v2/users/<int:userId>/inventory/<int:assetTypeId>', methods=['GET'])
@limiter.limit("60/minute")
def get_user_inventory(userId : int, assetTypeId : int = None):
    userObject : User = User.query.filter_by(id=userId).first()
    if userObject is None:
        return jsonify( { "errors": [ { "code": 1, "message": "Invalid user Id." } ] } ), 400
    
    cursorPage : int = request.args.get("cursor", default = 1, type = int)
    if cursorPage < 1:
        return jsonify( { "errors": [ { "code": 4, "message": "The specified cursor is invalid!" } ] } ), 400
    
    pageLimit : int = request.args.get("limit", default = 10, type = int)
    if pageLimit not in [10, 25, 50, 100]:
        return jsonify( { "errors": [ { "code": 5, "message": "The specified limit is invalid!" } ] } ), 400
    
    sortOrder : str = request.args.get("sortOrder", default = "Asc", type = str)
    if sortOrder.lower() not in ["asc", "desc"]:
        return jsonify( { "errors": [ { "code": 6, "message": "The specified sort order is invalid!" } ] } ), 400
    
    try:
        AssetTypeEnum : AssetType = AssetType(assetTypeId)
    except ValueError:
        return jsonify( { "errors": [ { "code": 2, "message": "Invalid asset type Id." } ] } ), 400

    UserAssetList : list[UserAsset] = UserAsset.query.filter_by(userid=userId).outerjoin(
        Asset, UserAsset.assetid == Asset.id
    ).filter(
        Asset.asset_type == AssetTypeEnum
    ).order_by(
        UserAsset.updated.desc() if sortOrder.lower() == "desc" else UserAsset.updated.asc()
    ).paginate(
        page = cursorPage,
        per_page = pageLimit,
        error_out = False
    )

    UserMembershipType : int = membership.GetUserMembership( userObject ).value

    dataList = []
    for user_asset_obj in UserAssetList.items:
        user_asset_obj : UserAsset = user_asset_obj
        dataList.append({
            "userAssetId": user_asset_obj.id,
            "assetId": user_asset_obj.assetid,
            "assetName": user_asset_obj.asset.name,
            "collectibleItemId": None,
            "collectibleItemInstanceId": None,
            "serialNumber": user_asset_obj.serial,
            "owner": {
                "userId": user_asset_obj.userid,
                "username": userObject.username,
                "buildersClubMembershipType": UserMembershipType
            },
            "created": user_asset_obj.created.isoformat(),
            "updated": user_asset_obj.updated.isoformat(),
        })

    return jsonify({
        "previousPageCursor": str(UserAssetList.prev_num) if UserAssetList.has_prev else None,
        "nextPageCursor": str(UserAssetList.next_num) if UserAssetList.has_next else None,
        "data": dataList
    }), 200