#badges.roblox.com
import logging
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, abort, jsonify, make_response, after_this_request, Response
from app.util import auth
from app.extensions import db, csrf, limiter, redis_controller
from flask_wtf.csrf import CSRFError, generate_csrf

from app.models.user import User
from app.models.groups import Group
from app.models.place import Place
from app.models.userassets import UserAsset
from app.models.place_badge import PlaceBadge, UserBadge
from app.models.asset import Asset
from app.models.game_session_log import GameSessionLog
from app.models.placeserver_players import PlaceServerPlayer
from app.models.placeservers import PlaceServer
from app.models.universe import Universe

from datetime import datetime, timedelta
from sqlalchemy import and_

BadgesAPIRoute = Blueprint( 'BadgesAPIRoute', __name__, url_prefix='/')

def CalculateBadgeRarity( badge_id : int, bypass_cache : bool = False ) -> float:
    """ 
        Badges have a rarity value that is influenced by the ratio of the number of users in the past 24 hours
        to achieve the badge to the total number of players that have joined the experience within the same timespan; 
        for example, if 99,900 of 100,000 daily visitors receive a badge, its difficulty will likely be Freebie (99.9%), 
        while if only 100 players get a badge in the same experience, its difficulty will appear as Impossible (0.1%).
        
        https://roblox.fandom.com/wiki/Player_badge 
    """

    def _calculate_rarity() -> float:
        BadgeObj : PlaceBadge = PlaceBadge.query.filter_by( id = badge_id ).first()
        if BadgeObj is None:
            return 0.0
        PlaceObj : Place = Place.query.filter_by( placeid = BadgeObj.associated_place_id ).first()
        UniverseObj : Universe = Universe.query.filter_by( id = PlaceObj.parent_universe_id ).first()
        AwardedRecentlyCount : int = UserBadge.query.filter_by( badge_id = badge_id ).filter( UserBadge.awarded_at > datetime.utcnow() - timedelta( hours = 24 ) ).count()
        TotalPlayedRecentlyCount : int = GameSessionLog.query.filter_by( place_id = UniverseObj.root_place_id ).filter( GameSessionLog.joined_at > datetime.utcnow() - timedelta( hours = 24 ) ).distinct( GameSessionLog.user_id ).count()

        if TotalPlayedRecentlyCount == 0 or AwardedRecentlyCount == 0:
            return 0.0
        
        return round( AwardedRecentlyCount / TotalPlayedRecentlyCount, 3 )

    CacheRedisKey = f"badge_rarity_{badge_id}"

    if not bypass_cache:
        CachedValue = redis_controller.get( CacheRedisKey )
        if CachedValue is not None:
            return float( CachedValue )

    RarityValue = _calculate_rarity()
    redis_controller.set( CacheRedisKey, str(RarityValue), ex = 60 )

    return RarityValue

def GetBadgeAwardedPastDay( badge_id ) -> int:
    timenow = datetime.utcnow()
    start_of_yesterday = datetime(timenow.year, timenow.month, timenow.day) - timedelta(days=1)
    end_of_yesterday = datetime(timenow.year, timenow.month, timenow.day) - timedelta(seconds=1)
    return UserBadge.query.filter_by( badge_id = badge_id ).filter( and_( UserBadge.awarded_at > start_of_yesterday, UserBadge.awarded_at < end_of_yesterday ) ).count()

class UserAlreadyHasBadgeException( Exception ):
    pass

def AwardBadgeToUser( badge_id : int, user_obj : User ) -> UserBadge:
    """ Award a badge to a user. """
    BadgeObj : PlaceBadge | None = PlaceBadge.query.filter_by( id = badge_id ).first()
    if BadgeObj is None:
        raise ValueError("Badge does not exist.")

    if UserBadge.query.filter_by( badge_id = badge_id, user_id = user_obj.id ).first() is not None:
        raise UserAlreadyHasBadgeException("User already has badge.")

    BadgeAwarded = UserBadge( badge_id = badge_id, user_id = user_obj.id )
    db.session.add( BadgeAwarded )

    try:
        if BadgeObj.asset_reward is not None:
            UserAssetObj : UserAsset | None = UserAsset.query.filter_by( userid = user_obj.id, assetid = BadgeObj.asset_reward ).first()
            if UserAssetObj is None:
                AssetObj : Asset | None = Asset.query.filter_by( id = BadgeObj.asset_reward ).first()
                if AssetObj is None:
                    raise ValueError(f"Asset [{BadgeObj.asset_reward}] does not exist for badge {BadgeObj.id}")

                UserAssetObj = UserAsset( userid = user_obj.id, assetid = BadgeObj.asset_reward )
                db.session.add( UserAssetObj )
    except Exception as e:
        logging.error(f"Error attempting to give user [{user_obj.id}] badge award [{badge_id}]: {e}")

    db.session.commit()

    return BadgeAwarded

def GetAssetCreator( asset_obj : Asset ) -> User | Group | None:
    if asset_obj.creator_type == 0:
        return User.query.filter_by( id = asset_obj.creator_id ).first()
    elif asset_obj.creator_type == 1:
        return Group.query.filter_by( id = asset_obj.creator_id ).first()

    return None

csrf.exempt(BadgesAPIRoute)
@BadgesAPIRoute.errorhandler(CSRFError)
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

@BadgesAPIRoute.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({"errors": [{"code": 9,"message": "The flood limit has been exceeded."}]}), 429
@BadgesAPIRoute.errorhandler(405)
def handle_method_not_allowed(e):
    return jsonify({"errors": [{"code": 0,"message": "MethodNotAllowed"}]}), 405

@BadgesAPIRoute.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        csrf.protect()

@BadgesAPIRoute.route('/v1/badges/<int:badge_id>', methods=['GET'])
@limiter.limit("60/minute")
def get_badge_info( badge_id : int ):
    BadgeObj : PlaceBadge = PlaceBadge.query.filter_by( id = badge_id ).first()
    if BadgeObj is None:
        return jsonify({"errors": [{"code": 1,"message": "Badge is invalid or does not exist."}]}), 404
    
    UniverseObj : Universe = Universe.query.filter_by( id = BadgeObj.universe_id ).first()

    BadgeAwardedCount : int = UserBadge.query.filter_by( badge_id = badge_id ).count()
    PastAwardedCount : int = UserBadge.query.filter_by( badge_id = badge_id ).filter( UserBadge.awarded_at > datetime.utcnow() - timedelta( hours = 24 ) ).count()
    AssociatedPlaceAsset : Asset = Asset.query.filter_by( id = UniverseObj.root_place_id ).first()
    BadgeWinRatePercentage : float = CalculateBadgeRarity( badge_id = badge_id )

    return jsonify({
        "id": BadgeObj.id,
        "name": BadgeObj.name,
        "description": BadgeObj.description,
        "displayName": BadgeObj.name,
        "displayDescription": BadgeObj.description,
        "enabled": BadgeObj.enabled,
        "iconImageId": BadgeObj.icon_image_id,
        "displayIconImageId": BadgeObj.icon_image_id,
        "created": BadgeObj.created_at.isoformat(),
        "updated": BadgeObj.updated_at.isoformat(),
        "statistics": {
            "pastAwardCount": PastAwardedCount,
            "awardCount": BadgeAwardedCount,
            "winRatePercentage": BadgeWinRatePercentage
        },
        "awardingUniverse": {
            "id": UniverseObj.id,
            "name": AssociatedPlaceAsset.name,
            "rootPlaceId": UniverseObj.root_place_id
        }
    })

# This endpoint should only be used by 2020 games, which should always have "AccessKey" in the request headers unlike 2014
@BadgesAPIRoute.route('/v1/users/<int:user_id>/badges/<int:badge_id>/award-badge', methods=["POST"])
@auth.gameserver_accesskey_required
def server_award_badge_route( user_id : int, badge_id : int ):
    BadgeObj : PlaceBadge = PlaceBadge.query.filter_by( id = badge_id ).first()
    if BadgeObj is None:
        return jsonify({"errors": [{"code": 1,"message": "Badge is invalid or does not exist."}]}), 404

    UserObj : User | None = User.query.filter_by( id = user_id ).first()
    if UserObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is invalid or does not exist."}]}), 404

    PlaceServerPlayerObj : PlaceServerPlayer | None = PlaceServerPlayer.query.filter_by( userid = user_id ).first()
    if PlaceServerPlayerObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400

    PlaceServerObj : PlaceServer = PlaceServer.query.filter_by( serveruuid = PlaceServerPlayerObj.serveruuid ).first()
    # This should never happen, but just in case
    if PlaceServerObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400
    ServerPlaceObj : Place = Place.query.filter_by( placeid = PlaceServerObj.serverPlaceId ).first()
    if ServerPlaceObj.parent_universe_id != BadgeObj.universe_id:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400

    RequestPlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int )
    if RequestPlaceId is None:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404
    PlaceObj : Place = Place.query.filter_by( placeid = RequestPlaceId ).first()
    if PlaceObj is None:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404
    if PlaceObj.parent_universe_id != BadgeObj.universe_id:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404
    
    try:
        AwardBadgeToUser( badge_id = badge_id, user_obj = UserObj )
    except UserAlreadyHasBadgeException:
        return jsonify({"errors": [{"code": 1,"message": "User already has badge."}]}), 400
    except ValueError:
        return jsonify({"errors": [{"code": 1,"message": "Badge is invalid or does not exist."}]}), 404
    except Exception as e:
        logging.error(f"Error awarding badge to user: {e}")
        return jsonify({"errors": [{"code": 1,"message": "Internal Server error."}]}), 500
    
    return jsonify({ "success": True })

# 2018 RCC
@BadgesAPIRoute.route('/assets/award-badge', methods=["POST"])
@auth.gameserver_accesskey_required
def server_award_badge_route_legacy():
    reqUserId = request.args.get("userId", type=int, default=None)
    reqBadgeId = request.args.get("badgeId", type=int, default=None)
    reqPlaceId = request.args.get("placeId", type=int, default=None)

    if reqUserId is None or reqBadgeId is None or reqPlaceId is None:
        return jsonify({"errors": [{"code": 1,"message": "Invalid request."}]}), 400

    BadgeObj : PlaceBadge = PlaceBadge.query.filter_by( id = reqBadgeId ).first()
    if BadgeObj is None:
        return jsonify({"errors": [{"code": 1,"message": "Badge is invalid or does not exist."}]}), 404

    UserObj : User | None = User.query.filter_by( id = reqUserId ).first()
    if UserObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is invalid or does not exist."}]}), 404

    PlaceServerPlayerObj : PlaceServerPlayer | None = PlaceServerPlayer.query.filter_by( userid = reqUserId ).first()
    if PlaceServerPlayerObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400

    PlaceServerObj : PlaceServer = PlaceServer.query.filter_by( serveruuid = PlaceServerPlayerObj.serveruuid ).first()
    # This should never happen, but just in case
    if PlaceServerObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400
    ServerPlaceObj : Place = Place.query.filter_by( placeid = PlaceServerObj.serverPlaceId ).first()
    if ServerPlaceObj.parent_universe_id != BadgeObj.universe_id:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400

    RequestPlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int )
    if RequestPlaceId is None:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404
    if RequestPlaceId != reqPlaceId:
        return jsonify({"errors": [{"code": 1,"message": f"Roblox-Place-Id [{RequestPlaceId}] Header does not match placeId argument [{reqPlaceId}]"}]}), 400
    PlaceObj : Place = Place.query.filter_by( placeid = RequestPlaceId ).first()
    if PlaceObj is None:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404
    if PlaceObj.parent_universe_id != BadgeObj.universe_id:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404

    try:
        AwardBadgeToUser( badge_id = reqBadgeId, user_obj = UserObj )
    except UserAlreadyHasBadgeException:
        return jsonify({"errors": [{"code": 1,"message": "User already has badge."}]}), 400
    except ValueError:
        return jsonify({"errors": [{"code": 1,"message": "Badge is invalid or does not exist."}]}), 404
    except Exception as e:
        logging.error(f"Error awarding badge to user: {e}")
        return jsonify({"errors": [{"code": 1,"message": "Internal Server error."}]}), 500
    PlaceAssetObj : Asset = Asset.query.filter_by( id = PlaceObj.placeid ).first()
    PlaceCreator : User | Group = GetAssetCreator( PlaceAssetObj )

    return f"{UserObj.username} won {PlaceCreator.username if PlaceAssetObj.creator_type == 0 else PlaceCreator.name}'s \"{BadgeObj.name}\" award!" # This message is sent to client to be shown as a badge awarded notification

@BadgesAPIRoute.route("/Game/Badge/HasBadge.ashx", methods=["GET"])
@auth.gameserver_authenticated_required # Only IP address is checked
def query_user_has_badge():
    reqUserId = request.args.get("UserID", type=int, default=None)
    reqBadgeId = request.args.get("BadgeID", type=int, default=None)

    if reqUserId is None or reqBadgeId is None:
        return "0"

    BadgeObj : PlaceBadge | None = PlaceBadge.query.filter_by( id = reqBadgeId ).first()
    if BadgeObj is None:
        return "0"

    UserObj : User | None = User.query.filter_by( id = reqUserId ).first()
    if UserObj is None:
        return "0"

    if UserBadge.query.filter_by( badge_id = reqBadgeId, user_id = reqUserId ).first() is None:
        return "0"

    return "1"

@BadgesAPIRoute.route("/Game/Badge/AwardBadge.ashx", methods=["POST"])
@auth.gameserver_authenticated_required
def award_badge_to_user():
    reqUserId = request.args.get("UserID", type=int, default=None)
    reqBadgeId = request.args.get("BadgeID", type=int, default=None)
    reqPlaceId = request.args.get("PlaceID", type=int, default=None)

    if reqUserId is None or reqBadgeId is None or reqPlaceId is None:
        return jsonify({"errors": [{"code": 1,"message": "Invalid request."}]}), 400
    
    BadgeObj : PlaceBadge = PlaceBadge.query.filter_by( id = reqBadgeId ).first()
    if BadgeObj is None:
        return jsonify({"errors": [{"code": 1,"message": "Badge is invalid or does not exist."}]}), 404
    
    UserObj : User | None = User.query.filter_by( id = reqUserId ).first()
    if UserObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is invalid or does not exist."}]}), 404
    
    PlaceServerPlayerObj : PlaceServerPlayer | None = PlaceServerPlayer.query.filter_by( userid = reqUserId ).first()
    if PlaceServerPlayerObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400
    
    PlaceServerObj : PlaceServer = PlaceServer.query.filter_by( serveruuid = PlaceServerPlayerObj.serveruuid ).first()
    # This should never happen, but just in case
    if PlaceServerObj is None:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400
    ServerPlaceObj : Place = Place.query.filter_by( placeid = PlaceServerObj.serverPlaceId ).first()
    if ServerPlaceObj.parent_universe_id != BadgeObj.universe_id:
        return jsonify({"errors": [{"code": 1,"message": "User is not in the game."}]}), 400
    
    PlaceObj : Place = Place.query.filter_by( placeid = reqPlaceId ).first()
    if PlaceObj is None:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404
    if PlaceObj.parent_universe_id != BadgeObj.universe_id:
        return jsonify({"errors": [{"code": 1,"message": "Place ID is invalid or does not exist."}]}), 404
    
    try:
        AwardBadgeToUser( badge_id = reqBadgeId, user_obj = UserObj )
    except UserAlreadyHasBadgeException:
        return jsonify({"errors": [{"code": 1,"message": "User already has badge."}]}), 400
    except ValueError:
        return jsonify({"errors": [{"code": 1,"message": "Badge is invalid or does not exist."}]}), 404
    except Exception as e:
        logging.error(f"Error awarding badge to user: {e}")
        return jsonify({"errors": [{"code": 1,"message": "Internal Server error."}]}), 500
    PlaceAssetObj : Asset = Asset.query.filter_by( id = PlaceObj.placeid ).first()
    PlaceCreator : User | Group = GetAssetCreator( PlaceAssetObj )

    return f"{UserObj.username} won {PlaceCreator.username if PlaceAssetObj.creator_type == 0 else PlaceCreator.name}'s \"{BadgeObj.name}\" award!" # This message is sent to client to be shown as a badge awarded notification

