# games.roblox.com

import math
from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort, after_this_request
from app.extensions import redis_controller, get_remote_address, csrf, limiter, db
from app.util import auth, websiteFeatures, placeinfo
from app.models.place import Place
from app.models.asset import Asset
from app.models.placeservers import PlaceServer
from app.models.user import User
from app.models.groups import Group
from app.models.asset_thumbnail import AssetThumbnail
from app.models.universe import Universe
from app.enums.PlaceYear import PlaceYear
from app.routes.rate import GetAssetLikesAndDislikes, GetAssetFavoriteCount, GetUserFavoriteStatus
from flask_wtf.csrf import CSRFError, generate_csrf
from sqlalchemy import func, and_
from flask_sqlalchemy import pagination

GamesAPIRoute = Blueprint('gamesapi', __name__, url_prefix='/')

csrf.exempt(GamesAPIRoute)
@GamesAPIRoute.errorhandler(CSRFError)
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

@GamesAPIRoute.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({
        "errors": [
            {
                "code": 9,
                "message": "The flood limit has been exceeded."
            }
        ]
    }), 429

@GamesAPIRoute.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        csrf.protect()


@GamesAPIRoute.route('/v1/games/sorts', methods=["GET"])
@auth.authenticated_required_api
def games_sorts():
    return jsonify({
        "sorts" : [
            {
                "token": "MostPopular",
                "name": "most_popular",
                "displayName": "Popular",
                "gameSetTypeId": 1,
                "gameSetTargetId": 90,
                "timeOptionsAvailable": False,
                "genreOptionsAvailable": False,
                "numberOfRows": 2,
                "numberOfGames": 0,
                "isDefaultSort": True,
                "contextUniverseId": None,
                "contextCountryRegionId": 1,
                "tokenExpiryInSeconds": 3600
            },
            {
                "token": "Featured",
                "name": "featured",
                "displayName": "Featured",
                "gameSetTypeId": 2,
                "gameSetTargetId": 91,
                "timeOptionsAvailable": False,
                "genreOptionsAvailable": False,
                "numberOfRows": 1,
                "numberOfGames": 0,
                "isDefaultSort": True,
                "contextUniverseId": None,
                "contextCountryRegionId": 1,
                "tokenExpiryInSeconds": 3600
            },
            {
                "token": "RecentlyUpdated",
                "name": "recently_updated",
                "displayName": "Recently Updated",
                "gameSetTypeId": 3,
                "gameSetTargetId": 93,
                "timeOptionsAvailable": False,
                "genreOptionsAvailable": False,
                "numberOfRows": 1,
                "numberOfGames": 0,
                "isDefaultSort": True,
                "contextUniverseId": None,
                "contextCountryRegionId": 1,
                "tokenExpiryInSeconds": 3600
            },
        ],
        "timeFilters": [
            {
                "token": "Now",
                "name": "Now",
                "tokenExpiryInSeconds": 3600
            },
            {
                "token": "PastDay",
                "name": "PastDay",
                "tokenExpiryInSeconds": 3600
            },
            {
                "token": "PastWeek",
                "name": "PastWeek",
                "tokenExpiryInSeconds": 3600
            },
            {
                "token": "PastMonth",
                "name": "PastMonth",
                "tokenExpiryInSeconds": 3600
            },
            {
                "token": "AllTime",
                "name": "AllTime",
                "tokenExpiryInSeconds": 3600
            }
        ],
        "genreFilters": [
            {
            "token": "T638364961735517991_1_89de",
            "name": "All",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518009_19_3d2",
            "name": "Building",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518045_11_3de6",
            "name": "Horror",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518062_7_558c",
            "name": "Town and City",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518076_17_c371",
            "name": "Military",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518094_15_2056",
            "name": "Comedy",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518107_8_6d4f",
            "name": "Medieval",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518120_13_c168",
            "name": "Adventure",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518134_9_e6aa",
            "name": "Sci-Fi",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518156_12_13fb",
            "name": "Naval",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518169_20_46a",
            "name": "FPS",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518183_21_4bbf",
            "name": "RPG",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518192_14_efc6",
            "name": "Sports",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518205_10_fa83",
            "name": "Fighting",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518223_16_5d38",
            "name": "Western",
            "tokenExpiryInSeconds": 3600
            }
        ],
        "gameFilters": [
            {
            "token": "T638364961735518263_Any_56d2",
            "name": "Any",
            "tokenExpiryInSeconds": 3600
            },
            {
            "token": "T638364961735518277_Classic_a1f4",
            "name": "Classic",
            "tokenExpiryInSeconds": 3600
            }
        ],
        "pageContext": {
            "pageId": "f5b1510e-3810-42ab-8135-8ffa5ef221ba",
            "isSeeAllPage": None
        },
        "gameSortStyle": None
    })

@GamesAPIRoute.route("/v1/games/list", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def games_list():
    sortToken = request.args.get("sortToken", default = "MostPopular", type = str)
    startRows = request.args.get("startRows", default = 0, type = int)
    maxRows = request.args.get("maxRows", default = 40, type = int)

    if sortToken not in ["MostPopular", "Featured", "RecentlyUpdated"]:
        return jsonify( { "errors": [ { "code": 0, "message": "Invalid sort token." } ] } ), 400
    
    if startRows < 0:
        return jsonify( { "errors": [ { "code": 0, "message": "Invalid start rows." } ] } ), 400
    
    if maxRows > 40 or maxRows < 0:
        return jsonify( { "errors": [ { "code": 0, "message": "Max rows must be between 0-40" } ] } ), 400
    
    pageNumber = math.floor(startRows / maxRows) + 1

    if sortToken == "MostPopular":
        PopularGames = Universe.query.filter( and_( Universe.is_public == True, Universe.place_year == PlaceYear.Twenty ) ).outerjoin( Place, Place.parent_universe_id == Universe.id ).outerjoin( PlaceServer, PlaceServer.serverPlaceId == Place.placeid ).group_by( Universe.id )
        PopularGames = PopularGames.order_by( func.coalesce( func.sum( PlaceServer.playerCount ), 0 ).desc() ).order_by( func.coalesce( func.sum( Place.visitcount ), 0 ).desc() )
        
        UniverseObjsList = PopularGames.paginate(
            page = pageNumber,
            per_page = maxRows,
            error_out = False
        )
    elif sortToken == "Featured":
        FeaturedGames = Universe.query.filter( and_( Universe.is_public == True, Universe.place_year == PlaceYear.Twenty, Universe.is_featured == True ) ).outerjoin( Place, Place.parent_universe_id == Universe.id ).outerjoin( PlaceServer, PlaceServer.serverPlaceId == Place.placeid ).group_by( Universe.id )
        FeaturedGames = FeaturedGames.order_by( func.coalesce( func.sum( PlaceServer.playerCount ), 0 ).desc() ).order_by( func.coalesce( func.sum( Place.visitcount ), 0 ).desc() )
        UniverseObjsList = FeaturedGames.paginate(
            page = pageNumber,
            per_page = maxRows,
            error_out = False
        )
    else: # Fallback to RecentlyUpdated #sortToken == "RecentlyUpdated":
        RecentlyUpdatedGames = Universe.query.filter( and_( Universe.is_public == True, Universe.place_year == PlaceYear.Twenty )).order_by( Universe.updated_at.desc() )
        UniverseObjsList = RecentlyUpdatedGames.paginate(
            page = pageNumber,
            per_page = maxRows,
            error_out = False
        )

    UniverseObjsList : pagination.Pagination = UniverseObjsList
    
    GameList = []
    for UniverseObj in UniverseObjsList.items:
        UniverseObj : Universe
        PlaceObj : Place = Place.query.filter_by( placeid = UniverseObj.root_place_id ).first()
        Upvotes, Downvotes = GetAssetLikesAndDislikes(PlaceObj.placeid)
        PlaceAssetObj : Asset = PlaceObj.assetObj
        CreatorObj : User | Group = User.query.filter_by(id=UniverseObj.creator_id).first() if UniverseObj.creator_type == 0 else Group.query.filter_by(id=UniverseObj.creator_id).first()
        GameList.append({
            "creatorId": UniverseObj.creator_id,
            "creatorName": CreatorObj.username if UniverseObj.creator_type == 0 else CreatorObj.name,
            "creatorType": "User" if UniverseObj.creator_type == 0 else "Group",
            "creatorHasVerifiedBadge": False,
            "totalUpVotes": Upvotes,
            "totalDownVotes": Downvotes,
            "universeId": UniverseObj.id,
            "name": PlaceAssetObj.name,
            "placeId": PlaceObj.placeid,
            "playerCount": placeinfo.GetUniversePlayingCount(UniverseObj),
            "imageToken": "",
            "isSponsored": False,
            "nativeAdData": "",
            "isShowSponsoredLabel": False,
            "price": 0,
            "analyticsIdentifier": "",
            "gameDescription": PlaceAssetObj.description,
            "genre": "All",
            "minimumAge": 0
        })
    
    return jsonify({
        "games": GameList,
        "suggestedKeyword": "",
        "correctedKeyword": "",
        "filteredKeyword": "",
        "hasMoreRows": UniverseObjsList.has_next,
        "nextPageExclusiveStartId": 0,
        "featuredSearchUniverseId": 0,
        "emphasis": False,
        "cutOffIndex": 0,
        "algorithm": "",
        "algorithmQueryType": "",
        "suggestionAlgorithm": "",
        "relatedGames": []
    })

@GamesAPIRoute.route("/v1/games/<int:placeId>/votes", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_place_votes( placeId : int ):
    PlaceObj : Place = Place.query.filter_by(placeid=placeId).first()
    if not PlaceObj:
        return jsonify( { "errors": [ { "code": 0, "message": "Invalid placeId." } ] } ), 400
    
    Upvotes, Downvotes = GetAssetLikesAndDislikes(PlaceObj.placeid)
    return jsonify({
        "id": PlaceObj.placeid,
        "upVotes": Upvotes,
        "downVotes": Downvotes
    })

@GamesAPIRoute.route("/v1/games/<int:placeId>/votes/user", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_place_user_votes( placeId : int ):
    PlaceObj : Place = Place.query.filter_by(placeid=placeId).first()
    if not PlaceObj:
        return jsonify( { "errors": [ { "code": 0, "message": "Invalid placeId." } ] } ), 400
    
    return jsonify({
        "canVote": False,
        "userVote": False,
        "reasonForNotVoteable": "Voting is disabled"
    })

@GamesAPIRoute.route("/v1/games/multiget-playability-status", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_playability_status():
    universeIdsList = request.args.get("universeIds", default = "", type = str)
    if universeIdsList == "":
        return jsonify( { "errors": [ { "code": 8, "message": "No universe IDs were specified." } ] } ), 400
    
    try:
        universeIdsList = universeIdsList.split(",")
        universeIdsList = [int(x) for x in universeIdsList]
        universeIdsList = list(set(universeIdsList))
    except:
        return jsonify( { "errors": [ { "code": 8, "message": "Invalid universe IDs were specified." } ] } ), 400
    
    if len(universeIdsList) > 100:
        return jsonify( { "errors": [ { "code": 9, "message": "Too many universe IDs were specified." } ] } ), 400
    
    RequestedData = []
    for universeId in universeIdsList:
        RequestedData.append({
            "playabilityStatus": 0,
            "isPlayable": True,
            "universeId": universeId
        })

    return jsonify(RequestedData), 200

@GamesAPIRoute.route("/v2/games/<int:universeId>/media", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_game_media( universeId : int ):
    UniverseObj : Universe = Universe.query.filter_by(id = universeId).first()
    if not UniverseObj:
        return jsonify( { "errors": [ { "code": 2, "message": "The requested universe does not exist." } ] } ), 404
    return jsonify({"data": []}), 200

@GamesAPIRoute.route("/v1/games", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def multi_get_game_info():
    universeIdsList = request.args.get("universeIds", default = "", type = str)
    if universeIdsList == "":
        return jsonify( { "errors": [ { "code": 8, "message": "No universe IDs were specified." } ] } ), 400
    
    try:
        universeIdsList = universeIdsList.split(",")
        universeIdsList = [int(x) for x in universeIdsList]
        universeIdsList = list(set(universeIdsList))
    except:
        return jsonify( { "errors": [ { "code": 8, "message": "Invalid universe IDs were specified." } ] } ), 400

    if len(universeIdsList) > 100:
        return jsonify( { "errors": [ { "code": 9, "message": "Too many universe IDs were specified." } ] } ), 400
    
    RequestedData = []
    for universeId in universeIdsList:
        UniverseObj : Universe = Universe.query.filter_by(id=universeId).first()
        if UniverseObj is None:
            continue
        PlaceObj : Place = Place.query.filter_by( placeid = UniverseObj.root_place_id ).first()
        if PlaceObj is None:
            continue

        PlaceAssetObj : Asset = PlaceObj.assetObj
        CreatorObj : User | Group = User.query.filter_by(id=UniverseObj.creator_id).first() if UniverseObj.creator_type == 0 else Group.query.filter_by(id=UniverseObj.creator_id).first()

        RequestedData.append({
            "id": UniverseObj.id,
            "rootPlaceId": UniverseObj.root_place_id,
            "name": PlaceAssetObj.name,
            "description": PlaceAssetObj.description,
            "sourceName": PlaceAssetObj.name,
            "sourceDescription": PlaceAssetObj.description,
            "creator": {
                "id": CreatorObj.id,
                "type": "User" if UniverseObj.creator_type == 0 else "Group",
                "name": CreatorObj.username if UniverseObj.creator_type == 0 else CreatorObj.name,
                "hasVerifiedBadge": False,
                "isRNVAccount": False
            },
            "price": 0,
            "allowedGearGenres": [],
            "allowedGearCategories": [],
            "isGenreEnforced": True,
            "copyingAllowed": False,
            "playing": placeinfo.GetUniversePlayingCount(UniverseObj),
            "visits": PlaceObj.visitcount,
            "maxPlayers": PlaceObj.maxplayers,
            "created": UniverseObj.created_at.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
            "updated": UniverseObj.updated_at.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
            "studioAccessToApisAllowed": False,
            "createVipServersAllowed": False,
            "universeAvatarType": 1,
            "genre": "All",
            "isAllGenre": True,
            "isFavoritedByUser": False,
            "favoritedCount": GetAssetFavoriteCount(PlaceObj.placeid)
        })

    return jsonify({
        "data": RequestedData
    }), 200

@GamesAPIRoute.route("/v1/games/<int:universeId>/favorites", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_game_favorites( universeId : int ):
    UniverseObj : Universe = Universe.query.filter_by(id = universeId).first()
    if not UniverseObj:
        return jsonify( { "errors": [ { "code": 2, "message": "The requested universe does not exist." } ] } ), 404
    
    AuthenticatedUser : User = auth.GetCurrentUser()

    return jsonify({
        "isFavorited": GetUserFavoriteStatus( universeId, AuthenticatedUser.id)
    }), 200

@GamesAPIRoute.route("/v1/games/<int:universeId>/social-links/list", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_universe_social_links_list( universeId : int ):
    UniverseObj : Universe = Universe.query.filter_by(id = universeId).first()
    if not UniverseObj:
        return jsonify( { "errors": [ { "code": 2, "message": "The requested universe does not exist." } ] } ), 404
    
    return jsonify({
        "data": []
    }), 200

@GamesAPIRoute.route("/v1/games/<int:universeId>/game-passes", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_universe_game_passes( universeId : int ):
    UniverseObj : Universe = Universe.query.filter_by(id = universeId).first()
    if not UniverseObj:
        return jsonify( { "errors": [ { "code": 2, "message": "The requested universe does not exist." } ] } ), 404
    
    return jsonify({
        "previousPageCursor": None,
        "nextPageCursor": None,
        "data": []
    }), 200

@GamesAPIRoute.route("/v1/games/recommendations/game/<int:universeId>", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_recommended_games_from_universeid( universeId : int ):
    UniverseObj : Universe = Universe.query.filter_by(id = universeId).first()
    if not UniverseObj:
        return jsonify( { "errors": [ { "code": 2, "message": "The requested universe does not exist." } ] } ), 404
    
    return jsonify({
        "games": [],
        "nextPaginationKey": None
    }), 200