# friends.roblox.com

from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort, after_this_request
from app.util import auth, websiteFeatures, friends
from app.models.user import User
from app.models.friend_relationship import FriendRelationship
from app.models.friend_request import FriendRequest
from app.models.follow_relationship import FollowRelationship
from app.extensions import limiter, db, redis_controller, get_remote_address, csrf, user_limiter
from flask_wtf.csrf import CSRFError, generate_csrf
from sqlalchemy import or_
from datetime import datetime, timedelta

from app.services.user_relationships import followings

FriendsAPIRoute = Blueprint('friendsapi', __name__, url_prefix="/")
csrf.exempt(FriendsAPIRoute)
@FriendsAPIRoute.errorhandler(CSRFError)
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

@FriendsAPIRoute.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({
        "errors": [
            {
                "code": 9,
                "message": "The flood limit has been exceeded."
            }
        ]
    }), 429

@FriendsAPIRoute.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        csrf.protect()

@FriendsAPIRoute.route('/v1/my/friends/count', methods=['GET'])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def GetFriendCount():
    AuthenticatedUser : User = auth.GetCurrentUser()
    return jsonify( { "count": friends.GetFriendCount( AuthenticatedUser.id ) } ), 200

@FriendsAPIRoute.route('/v1/users/<int:userId>/friends/count', methods=['GET'])
@limiter.limit("60/minute")
def GetFriendCountByUserId( userId : int ):
    UserObj : User = User.query.filter_by( id = userId ).first()
    if UserObj is None:
        return jsonify( { "errors": [ { "code": 1, "message": "User not found" } ] } ), 404
    return jsonify( { "count": friends.GetFriendCount( userId ) } ), 200

@FriendsAPIRoute.route("/v1/user/friend-requests/count", methods=["GET"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def GetMyFriendRequestsCount():
    AuthenticatedUser : User = auth.GetCurrentUser()
    FriendRequestCount : int = max(FriendRequest.query.filter_by( requestee_id = AuthenticatedUser.id ).count(), 500)
    return jsonify( { "count": FriendRequestCount } ), 200

@FriendsAPIRoute.route("/v1/users/<int:userid>/friends", methods=["GET"])
@limiter.limit("60/minute")
def get_user_friends( userid : int ):
    UserObj : User = User.query.filter_by(id=userid).first()
    if UserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    FriendRelationshipList : list[FriendRelationship] = FriendRelationship.query.filter(or_(FriendRelationship.user_id == userid, FriendRelationship.friend_id == userid)).all()
    FriendList = []
    for FriendRelationshipObj in FriendRelationshipList:
        FriendObj : User = User.query.filter_by(id=FriendRelationshipObj.user_id if FriendRelationshipObj.user_id != userid else FriendRelationshipObj.friend_id).first()
        if FriendObj is None:
            continue
        FriendList.append({
            "isOnline": FriendObj.lastonline > datetime.utcnow() - timedelta(minutes=1),
            "isDeleted": False,
            "friendFrequentScore": 0,
            "friendFrequentRank": 1,
            "hasVerifiedBadge": False,
            "description": FriendObj.description,
            "created": FriendObj.created.isoformat(),
            "isBanned": False,
            "externalAppDisplayName": None,
            "id": FriendObj.id,
            "name": FriendObj.username,
            "displayName": FriendObj.username
        })

    return jsonify({
        "data": FriendList
    })

@FriendsAPIRoute.route("/v1/user/friend-requests/decline-all", methods=["POST"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def decline_all_friend_requests():
    AuthenticatedUser : User = auth.GetCurrentUser()
    FriendRequestList : list[FriendRequest] = FriendRequest.query.filter_by( requestee_id = AuthenticatedUser.id ).all()
    for FriendRequestObj in FriendRequestList:
        db.session.delete( FriendRequestObj )
    db.session.commit()
    return jsonify({}), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/unfriend", methods=["POST"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
@user_limiter.limit("60/minute")
def unfriend_user( userId : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({ "errors": [{ "code": 1, "message": "The target user is invalid or does not exist"}] }), 400
    FriendRelationshipObj : FriendRelationship = friends.GetFriendRelationship( AuthenticatedUser.id, UserObj.id )
    if FriendRelationshipObj is not None:
        db.session.delete( FriendRelationshipObj )
        db.session.commit()

    return jsonify({}), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/request-friendship", methods=["POST"])
@limiter.limit("15/minute")
@auth.authenticated_required_api
@user_limiter.limit("15/minute")
def request_friendship( userId : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({ "errors": [{ "code": 1, "message": "The target user is invalid or does not exist"}] }), 400
    if userId == AuthenticatedUser.id:
        return jsonify({ "errors": [{ "code": 7, "message": "The user cannot be friends with itself."}] }), 400
    if friends.GetFriendCount( AuthenticatedUser.id ) >= 200:
        return jsonify({ "errors": [{ "code": 31, "message": "User with max friends sent friend request."}] }), 400
    if friends.IsFriends( AuthenticatedUser.id, UserObj.id ):
        return jsonify({ "errors": [{ "code": 5, "message": "The target user is already a friend."}] }), 400
    
    OtherFriendRequestObj : FriendRequest = FriendRequest.query.filter_by( requestee_id = AuthenticatedUser.id, requester_id = UserObj.id ).first()
    if OtherFriendRequestObj is not None:
        if friends.GetFriendCount( UserObj.id ) >= 200:
            return jsonify({ "errors": [{ "code": 12, "message": "The target users friends limit has been exceeded."}] }), 400

        db.session.delete( OtherFriendRequestObj )
        NewFriendRelationshipObj : FriendRelationship = FriendRelationship( user_id = AuthenticatedUser.id, friend_id = UserObj.id )
        db.session.add( NewFriendRelationshipObj )
        db.session.commit()

        return jsonify({ "success": True }), 200
    
    FriendRequestObj : FriendRequest = FriendRequest.query.filter_by( requestee_id = UserObj.id, requester_id = AuthenticatedUser.id ).first()
    if FriendRequestObj is None:
        FriendRequestObj = FriendRequest( requestee_id = UserObj.id, requester_id = AuthenticatedUser.id )
        db.session.add( FriendRequestObj )
        db.session.commit()

    return jsonify({ "success": True }), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/accept-friend-request", methods=["POST"])
@limiter.limit("30/minute")
@auth.authenticated_required_api
@user_limiter.limit("30/minute")
def accept_friend_request( userId : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({ "errors": [{ "code": 1, "message": "The target user is invalid or does not exist"}] }), 400
    
    FriendRequestObj : FriendRequest = FriendRequest.query.filter_by( requestee_id = AuthenticatedUser.id, requester_id = UserObj.id ).first()
    if FriendRequestObj is None:
        return jsonify({ "errors": [{ "code": 10, "message": "The friend request does not exist."}] }), 400
    
    if friends.GetFriendCount( AuthenticatedUser.id ) >= 200:
        return jsonify({ "errors": [{ "code": 11, "message": "The current users friends limit has been exceeded."}] }), 400
    if friends.GetFriendCount( UserObj.id ) >= 200:
        return jsonify({ "errors": [{ "code": 12, "message": "The target users friends limit has been exceeded."}] }), 400
    
    db.session.delete( FriendRequestObj )
    NewFriendRelationshipObj : FriendRelationship = FriendRelationship( user_id = AuthenticatedUser.id, friend_id = UserObj.id )
    db.session.add( NewFriendRelationshipObj )
    db.session.commit()

    return jsonify({}), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/decline-friend-request", methods=["POST"])
@limiter.limit("30/minute")
@auth.authenticated_required_api
@user_limiter.limit("30/minute")
def decline_friend_request( userId : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({ "errors": [{ "code": 1, "message": "The target user is invalid or does not exist"}] }), 400
    
    FriendRequestObj : FriendRequest = FriendRequest.query.filter_by( requestee_id = AuthenticatedUser.id, requester_id = UserObj.id ).first()
    if FriendRequestObj is None:
        return jsonify({ "errors": [{ "code": 10, "message": "The friend request does not exist."}] }), 400
    
    db.session.delete( FriendRequestObj )
    db.session.commit()

    return jsonify({}), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/followers/count", methods=["GET"])
@limiter.limit("60/minute")
def get_user_followers_count( userId : int ):
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    return jsonify( { "count": followings.get_follower_count( requested_user = UserObj ) } ), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/followings/count", methods=["GET"])
@limiter.limit("60/minute")
def get_user_followings_count( userId : int ):
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    return jsonify( { "count": followings.get_following_count( requested_user = UserObj ) } ), 200

@FriendsAPIRoute.route("/v1/user/following-exists", methods=["POST"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
def following_exists():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if not request.is_json:
        return jsonify({ "errors": [{ "code": 0, "message": "An invalid userId was passed in."}] }), 400
    if "targetUserIds" not in request.json:
        return jsonify({ "errors": [{ "code": 0, "message": "An invalid userId was passed in."}] }), 400
    
    TargetUserIds : list[int] = request.json["targetUserIds"]
    ResponseList = []

    if len(TargetUserIds) > 100:
        return jsonify({ "errors": [{ "code": 0, "message": "An invalid userId was passed in."}] }), 400

    for TargetUserId in TargetUserIds:
        if TargetUserId < 1:
            return jsonify({ "errors": [{ "code": 0, "message": "An invalid userId was passed in."}] }), 400
        TargetUser : User = User.query.filter_by( id = TargetUserId ).first()
        if TargetUser is None:
            return jsonify({ "errors": [{ "code": 0, "message": "An invalid userId was passed in."}] }), 400
        
        ResponseList.append({
            "isFollowing": followings.is_following( follower_user = AuthenticatedUser, followed_user = TargetUser ),
            "isFollowed": followings.is_following( follower_user = TargetUser, followed_user = AuthenticatedUser ),
            "userId": TargetUserId
        })

    return jsonify({
        "followings": ResponseList
    }), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/unfollow", methods=["POST"])
@limiter.limit("60/minute")
@auth.authenticated_required_api
@user_limiter.limit("60/minute")
def unfollow_user( userId : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({ "errors": [{ "code": 1, "message": "The target user is invalid or does not exist"}] }), 400
    
    try:
        followings.unfollow_user(
            current_follower = AuthenticatedUser,
            followed_user = UserObj
        )
    except followings.FollowingExceptions.UserNotFollowing:
        return jsonify({}), 200
    except followings.FollowingExceptions.UserRateLimited:
        return jsonify({ "errors": [{ "code": 9, "message": "The flood limit has been exceeded."}] }), 429
    except followings.FollowingExceptions.FollowingIsDisabled:
        return jsonify({ "errors": [{ "code": 0, "message": "Following is disabled."}] }), 500

    return jsonify({}), 200

@FriendsAPIRoute.route("/v1/users/<int:userId>/follow", methods=["POST"])
@limiter.limit("10/minute")
@auth.authenticated_required_api
@user_limiter.limit("10/minute")
def follow_user( userId : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({ "errors": [{ "code": 1, "message": "The target user is invalid or does not exist"}] }), 400
    if userId == AuthenticatedUser.id:
        return jsonify({ "errors": [{ "code": 8, "message": "The user cannot follow itself."}] }), 400
    
    try:
        followings.follow_user(
            follow_user = AuthenticatedUser,
            followed_user = UserObj
        )
    except followings.FollowingExceptions.AlreadyFollowing:
        return jsonify({ "success": True }), 200
    except followings.FollowingExceptions.UserRateLimited:
        return jsonify({ "errors": [{ "code": 9, "message": "The flood limit has been exceeded."}] }), 429
    except followings.FollowingExceptions.FollowingIsDisabled:
        return jsonify({ "errors": [{ "code": 0, "message": "Following is disabled."}] }), 500

    return jsonify({ "success": True }), 200
