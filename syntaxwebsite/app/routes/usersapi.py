# users.roblox.com

from flask import Blueprint, jsonify, request, make_response
from flask_wtf.csrf import CSRFError, generate_csrf
from app.extensions import db, redis_controller, limiter, csrf
from app.models.user import User
from app.models.userassets import UserAsset
from app.models.past_usernames import PastUsername
from app.models.asset import Asset
from app.util import membership, auth
from app.enums.AssetType import AssetType
from app.enums.MembershipType import MembershipType
from sqlalchemy import func

UsersAPI = Blueprint('UsersAPI', __name__, url_prefix='/')
csrf.exempt(UsersAPI)
@UsersAPI.errorhandler(CSRFError)
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

@UsersAPI.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({
        "errors": [
            {
                "code": 9,
                "message": "The flood limit has been exceeded."
            }
        ]
    }), 429

@UsersAPI.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        if request.path == "/v1/usernames/users" or request.path == "/v1/users":
            return
        csrf.protect()

@UsersAPI.route('/v1/users/<int:userId>', methods=['GET'])
@limiter.limit("60/minute")
def get_user( userId : int ):
    userObject : User = User.query.filter_by(id=userId).first()
    if userObject is None:
        return jsonify( { "errors": [ { "code": 3, "message": "The user id is invalid." } ] } ), 404
    
    return jsonify({
        "description": userObject.description,
        "created": userObject.created.isoformat(),
        "isBanned": userObject.accountstatus != 1,
        "externalAppDisplayName": userObject.username,
        "hasVerifiedBadge": False,
        "id": userObject.id,
        "name": userObject.username,
        "displayName": userObject.username,
    })

@UsersAPI.route('/v1/users/authenticated', methods=['GET'])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_authenticated_user():
    AuthenticatedUser : User = auth.GetCurrentUser()

    return jsonify({
        "id": AuthenticatedUser.id,
        "name": AuthenticatedUser.username,
        "displayName": AuthenticatedUser.username,
    })

@UsersAPI.route("/v1/users/authenticated/roles", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def get_authenticated_user_roles():
    return jsonify({
        "roles": []
    }), 200

@UsersAPI.route("/v1/usernames/users", methods=["POST"])
@limiter.limit("60/minute")
def multi_username_lookup():
    if not request.is_json:
        return jsonify( { "errors": [ { "code": 0, "message": "The request is invalid." } ] } ), 400
    
    if "usernames" not in request.json:
        return jsonify( { "errors": [ { "code": 0, "message": "The request is invalid." } ] } ), 400
    
    if not isinstance(request.json["usernames"], list):
        return jsonify( { "errors": [ { "code": 0, "message": "The request is invalid." } ] } ), 400

    usernames = request.json["usernames"]
    if len(usernames) > 100:
        return jsonify( { "errors": [ { "code": 2, "message": "Too many usernames." } ] } ), 400
    
    alreadySearchedUsernames = []
    data_result = []

    for username in usernames:
        username = str(username)
        if username.lower() in alreadySearchedUsernames:
            continue

        alreadySearchedUsernames.append(username.lower())

        userObject : User = User.query.filter(func.lower(User.username) == username.lower()).first()
        if userObject is not None:
            data_result.append({
                "requestedUsername": username,
                "hasVerifiedBadge": False,
                "id": userObject.id,
                "name": userObject.username,
                "displayName": userObject.username
            })

            continue

        pastusernameLookup : PastUsername = PastUsername.query.filter(func.lower(PastUsername.username) == username.lower()).first()
        if pastusernameLookup is not None:
            userObject : User = User.query.filter_by(id=pastusernameLookup.user_id).first()
            if userObject is not None:
                data_result.append({
                    "requestedUsername": username,
                    "hasVerifiedBadge": False,
                    "id": userObject.id,
                    "name": userObject.username,
                    "displayName": userObject.username
                })

                continue

    return jsonify({
        "data": data_result
    }), 200

@UsersAPI.route("/v1/users", methods=["POST"])
@limiter.limit("60/minute")
def multi_user_lookup():
    if not request.is_json:
        return jsonify( { "errors": [ { "code": 0, "message": "The request is invalid." } ] } ), 400
    
    if "userIds" not in request.json:
        return jsonify( { "errors": [ { "code": 0, "message": "The request is invalid." } ] } ), 400
    
    if not isinstance(request.json["userIds"], list):
        return jsonify( { "errors": [ { "code": 0, "message": "The request is invalid." } ] } ), 400

    userIds = request.json["userIds"]
    if len(userIds) > 100:
        return jsonify( { "errors": [ { "code": 2, "message": "Too many usernames." } ] } ), 400
    
    alreadySearchedUserIds = []
    data_result = []

    for userId in userIds:
        if type(userId) != int:
            return jsonify( { "errors": [ { "code": 0, "message": "The request is invalid." } ] } ), 400
        if userId in alreadySearchedUserIds:
            continue

        alreadySearchedUserIds.append(userId)

        userObject : User = User.query.filter_by(id=userId).first()
        if userObject is not None:
            data_result.append({
                "id": userObject.id,
                "name": userObject.username,
                "displayName": userObject.username,
                "hasVerifiedBadge": False
            })

            continue

    return jsonify({
        "data": data_result
    }), 200

@UsersAPI.route("/v1/users/<int:userId>/username-history", methods=["GET"])
@limiter.limit("60/minute")
def past_username_history_lookup( userId : int ):
    userObject : User = User.query.filter_by(id=userId).first()
    if userObject is None:
        return jsonify( { "errors": [ { "code": 3, "message": "The user id is invalid." } ] } ), 404
    
    cursorPage : int = request.args.get("cursor", default = 1, type = int)
    if cursorPage < 1:
        return jsonify( { "errors": [ { "code": 4, "message": "The specified cursor is invalid!" } ] } ), 400
    
    pageLimit : int = request.args.get("limit", default = 10, type = int)
    if pageLimit not in [10, 25, 50, 100]:
        return jsonify( { "errors": [ { "code": 5, "message": "The specified limit is invalid!" } ] } ), 400
    
    sortOrder : str = request.args.get("sortOrder", default = "Asc", type = str)
    if sortOrder.lower() not in ["asc", "desc"]:
        return jsonify( { "errors": [ { "code": 6, "message": "The specified sort order is invalid!" } ] } ), 400
    
    pastUsernames = PastUsername.query.filter_by(user_id=userId).order_by(
        PastUsername.id.desc() if sortOrder.lower() == "desc" else PastUsername.id.asc()
    ).paginate(page=cursorPage, per_page=pageLimit, error_out=False)

    data_result = []
    for pastUsername in pastUsernames.items:
        data_result.append({
            "name": pastUsername.username,
        })

    return jsonify({
        "previousPageCursor": str(pastUsernames.prev_num) if pastUsernames.has_prev else None,
        "nextPageCursor": str(pastUsernames.next_num) if pastUsernames.has_next else None,
        "data": data_result
    }),200