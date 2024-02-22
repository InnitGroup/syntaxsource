import json
from flask import Blueprint, request, jsonify, abort, make_response, Response
from datetime import datetime, timedelta

from app.models.asset import Asset
from app.models.user import User
from app.models.userassets import UserAsset
from app.models.placeserver_players import PlaceServerPlayer
from app.models.limited_item_transfers import LimitedItemTransfer

from app.enums.LimitedItemTransferMethod import LimitedItemTransferMethod

from app.services import economy

from app.extensions import csrf, redis_controller
from config import Config

config = Config()

RolimonsAPI = Blueprint('RolimonsAPI', __name__, url_prefix='/api/internal_rolimons')

@RolimonsAPI.before_request
def before_request_authentication():
    if config.ROLIMONS_API_ENABLED != True:
        abort(404)
    
    rolimonAccessKey = request.headers.get(
        key = "X-Rolimons-Access-Key",
        default = None,
        type = str
    )

    if rolimonAccessKey is None or rolimonAccessKey != config.ROLIMONS_API_KEY:
        abort(404)

@RolimonsAPI.errorhandler( 500 )
def internal_error( error ):
    return make_response(jsonify({
        "error": "Internal Server Error",
        "success": False
    }), 500)

@RolimonsAPI.route('/get_item_owners/<int:assetid>', methods=['GET'])
def get_item_owners( assetid : int ):
    AssetObj : Asset = Asset.query.filter_by( id = assetid ).first()
    if AssetObj is None:
        return make_response(jsonify({
            "error": "Asset not found",
            "success": False
        }), 404)

    if not AssetObj.is_limited:
        return make_response(jsonify({
            "error": "Asset is not a limited",
            "success": False
        }), 400)
    
    UserAssets : list[UserAsset] = UserAsset.query.filter_by( assetid = assetid ).order_by( UserAsset.serial ).all()
    AllItemOwners : list[dict] = []    

    for UserAssetObj in UserAssets:
        OwnerUserObj : User = User.query.filter_by( id = UserAssetObj.userid ).first()
        if OwnerUserObj is None:
            continue

        AllItemOwners.append({
            "uaid": UserAssetObj.id,
            "item_id": assetid,
            "owner_id": OwnerUserObj.id if OwnerUserObj.accountstatus not in [3,4] else None,
            "owner_name": OwnerUserObj.username if OwnerUserObj.accountstatus not in [3,4] else None,
            "serial_number": UserAssetObj.serial,
            "owned_since": f"{UserAssetObj.updated.isoformat()}Z"
        })

    return make_response(jsonify({
        "success": True,
        "data": AllItemOwners
    }))

@RolimonsAPI.route('/get_player_inventory/<int:userid>', methods=['GET'])
def get_user_collectibles( userid : int ):
    UserObj : User = User.query.filter_by( id = userid ).first()
    if UserObj is None or UserObj.accountstatus == 4:
        return make_response(jsonify({
            "error": "User not found",
            "success": False
        }), 404)

    PageNumber = max(
        request.args.get(
            key = "cursor",
            default = 1,
            type = int
        ),
        1
    )

    UserAssets = UserAsset.query.filter_by( userid = userid ).join( Asset, UserAsset.assetid == Asset.id ).filter( Asset.is_limited == True ).order_by( UserAsset.id.desc() ).paginate(
        page = PageNumber,
        per_page = 50,
        error_out = False
    )

    AllUserCollectibleAssets : list[dict] = []
    for UserAssetObj in UserAssets.items:
        UserAssetObj : UserAsset
        AssetObj : Asset = UserAssetObj.asset
        
        AllUserCollectibleAssets.append({
            "assetId": UserAssetObj.assetid,
            "userAssetId": UserAssetObj.id,
            "serialNumber": UserAssetObj.serial,
            "name": AssetObj.name
        })

    return jsonify({
        "data": AllUserCollectibleAssets,
        "nextPageCursor": str(UserAssets.next_num if UserAssets.has_next else None),
        "previousPageCursor": str(UserAssets.prev_num if UserAssets.has_prev else None),
        "success": True
    })

@RolimonsAPI.route("/user_by_username/<username>", methods=['GET'])
def get_user_by_username( username : str ):
    if len(username) < 3 or len(username) > 32:
        return make_response(jsonify({
            "error": "Username length must be between 3 and 32 characters",
            "success": False
        }), 400)
    SearchQuery = username.strip().replace('%', '')

    UserSearchResults = User.query.filter( User.username.ilike( '%' + SearchQuery + '%' ) ).filter( User.accountstatus != 4 ).order_by( User.id ).all()

    UserSearchResultsData = []
    for UserObj in UserSearchResults:
        UserSearchResultsData.append({
            "Name": UserObj.username,
            "UserID": UserObj.id,
            "Description": UserObj.description
        })

    return jsonify({
        "UserSearchResults": UserSearchResultsData,
        "success": True
    })

@RolimonsAPI.route("/multi_get_user_presence", methods=['POST'])
@csrf.exempt
def multi_get_user_presence():
    if not request.is_json:
        return make_response(jsonify({
            "error": "Invalid JSON",
            "success": False
        }), 400)
    
    if "userIds" not in request.json:
        return make_response(jsonify({
            "error": "userIds not found in JSON Payload",
            "success": False
        }), 400)
    
    UserIds = request.json["userIds"]
    if not isinstance(UserIds, list):
        return make_response(jsonify({
            "error": "userIds must be a list",
            "success": False
        }), 400)
    
    if len(UserIds) > 100:
        return make_response(jsonify({
            "error": "userIds list must not exceed 100 items",
            "success": False
        }), 400)

    UserPresenceData : list[dict] = []
    for UserId in UserIds:
        if not isinstance(UserId, int):
            continue

        UserObj : User = User.query.filter_by( id = UserId ).first()
        if UserObj is None or UserObj.accountstatus == 4:
            continue

        UserObjPresenceData = {
            "userId": UserObj.id,
            "lastOnline": f"{UserObj.lastonline.isoformat()}Z",
            "userPresenceType": "InGame" if PlaceServerPlayer.query.filter_by( userid = UserObj.id ).first() is not None else ( "Online" if UserObj.lastonline > datetime.utcnow() - timedelta( minutes = 1 ) else "Offline" )
        }

        UserObjPresenceData["lastLocation"] = "Playing" if UserObjPresenceData["userPresenceType"] == "InGame" else "Website"
        UserPresenceData.append(UserObjPresenceData)

    return jsonify({
        "userPresences": UserPresenceData,
        "success": True
    })

@RolimonsAPI.route("/get_user_by_id/<int:userid>", methods=['GET'])
def get_user_by_id( userid : int ):
    UserObj : User = User.query.filter_by( id = userid ).first()
    if UserObj is None or UserObj.accountstatus == 4:
        return make_response(jsonify({
            "error": "User not found",
            "success": False
        }), 404)

    return jsonify({
        "id": UserObj.id,
        "name": UserObj.username,
        "description": UserObj.description,
        "isBanned": UserObj.accountstatus in [ 3, 4 ],
    })

@RolimonsAPI.route("/get_all_limiteds", methods=["GET"])
def get_all_limiteds():
    def _generate_response() -> list:
        AllLimiteds = []
        LimitedsListAssetObj : list[Asset] = Asset.query.filter(
            Asset.is_limited == True
        ).order_by( Asset.id.desc() ).all()

        for LimitedAsset in LimitedsListAssetObj:
            LimitedAsset : Asset
            LowestAvailablePrice : UserAsset | None = UserAsset.query.filter_by( assetid = LimitedAsset.id, is_for_sale = True ).order_by( UserAsset.price ).first()

            AllLimiteds.append({
                "name": LimitedAsset.name,
                "id": LimitedAsset.id,
                "description": LimitedAsset.description,
                "rap": economy.GetAssetRap( LimitedAsset ),
                "price": LowestAvailablePrice.price if LowestAvailablePrice is not None else None,
                "original_price": LimitedAsset.price_robux if LimitedAsset.price_robux != 0 else LimitedAsset.price_tix,
                "original_price_type": "Robux" if LimitedAsset.price_robux != 0 else "Tickets",
                "type": LimitedAsset.asset_type.name,
                "is_limited_unique": LimitedAsset.is_limited_unique,
                "updated_at": f"{LimitedAsset.updated_at.isoformat()}Z"
            })

        return AllLimiteds
    
    if redis_controller.exists("rolimons_all_limiteds"):
        return jsonify({
            "data": json.loads( redis_controller.get("rolimons_all_limiteds") ),
            "success": True
        })
    
    AllLimiteds = _generate_response()
    redis_controller.set( "rolimons_all_limiteds", json.dumps(AllLimiteds), ex = 5 )
    return jsonify({
        "data": AllLimiteds,
        "success": True
    })

@RolimonsAPI.route("/get_item_sales/<int:assetid>", methods=["GET"])
def get_item_sales( assetid : int ):
    AssetObj : Asset = Asset.query.filter_by( id = assetid ).first()
    if AssetObj is None:
        return make_response(jsonify({
            "error": "Asset not found",
            "success": False
        }), 404)

    if not AssetObj.is_limited:
        return make_response(jsonify({
            "error": "Asset is not a limited",
            "success": False
        }), 400)

    PageNumber = max(
        request.args.get(
            key = "cursor",
            default = 1,
            type = int
        ),
        1
    )

    AllItemTransfers : list[LimitedItemTransfer] = LimitedItemTransfer.query.filter_by( asset_id = assetid, transfer_method = LimitedItemTransferMethod.Purchase ).order_by( LimitedItemTransfer.transferred_at.desc() ).paginate(
        page = 1,
        per_page = 15,
        error_out = False
    )

    AllItemSalesData : list[dict] = []
    for ItemTransfer in AllItemTransfers.items:
        ItemTransfer : LimitedItemTransfer
        OriginalOwnerObj : User = User.query.filter_by( id = ItemTransfer.original_owner_id ).first()
        NewOwnerObj : User = User.query.filter_by( id = ItemTransfer.new_owner_id ).first()

        AllItemSalesData.append({
            "userAssetId": ItemTransfer.user_asset_id,

            "sellerId": OriginalOwnerObj.id,
            "sellerName": OriginalOwnerObj.username,

            "buyerId": NewOwnerObj.id,
            "buyerName": NewOwnerObj.username,

            "price": ItemTransfer.purchased_price
        })

    return jsonify({
        "sales": AllItemSalesData,
        "success": True,
        "nextPageCursor": str(AllItemTransfers.next_num) if AllItemTransfers.has_next else None,
        "previousPageCursor": str(AllItemTransfers.prev_num) if AllItemTransfers.has_prev else None
    })