from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify
from config import Config
from app.models.asset import Asset
from app.models.userassets import UserAsset
from app.enums.AssetType import AssetType
from app.models.follow_relationship import FollowRelationship
from app.models.friend_relationship import FriendRelationship
from app.models.friend_request import FriendRequest
from app.models.package_asset import PackageAsset
from app.models.placeserver_players import PlaceServerPlayer
from app.util import auth, friends, websiteFeatures, membership
from app.services import economy
from app.enums.MembershipType import MembershipType
from app.models.user import User
from app.models.user_email import UserEmail
from sqlalchemy import or_, func
from app.extensions import limiter, db, csrf
import logging
from datetime import datetime, timedelta
from app.models.groups import GroupRole, GroupMember
from app.services.groups import GetGroupMemberCount
from app.services.groups import GetUserRankInGroup, GroupExceptions, GetUserRolesetInGroup
from app.services.user_relationships import followings
config = Config()

LuaWebServiceRoute = Blueprint('luawebservice', __name__, url_prefix='/')

def MakeReturnFalseResponse():
    Resposne = make_response("""<Value Type="boolean">false</Value>""")
    Resposne.headers["Content-Type"] = "application/xml; charset=utf-8"
    return Resposne

def MakeReturnTrueResponse():
    Resposne = make_response("""<Value Type="boolean">true</Value>""")
    Resposne.headers["Content-Type"] = "application/xml; charset=utf-8"
    return Resposne

def MakeReturnIntResponse(Value : int):
    Resposne = make_response(f"""<Value Type="integer">{str(Value)}</Value>""")
    Resposne.headers["Content-Type"] = "application/xml; charset=utf-8"
    return Resposne

def MakeReturnStringResponse(Value : str):
    Resposne = make_response(Value)
    #Resposne = make_response(f"""<Value Type="string">{Value}</Value>""")
    Resposne.headers["Content-Type"] = "application/xml; charset=utf-8"
    return Resposne

@LuaWebServiceRoute.route('/Game/LuaWebService/HandleSocialRequest.ashx', methods=['GET'])
def HandleSocialRequest():
    playerid = request.args.get("playerid", None, int)
    groupid = request.args.get("groupid", None, int)
    userid = request.args.get("userid", None, int)
    method = request.args.get("method", None, str)
    if method is None:
        return MakeReturnFalseResponse()
    if groupid == 1200769:
        groupid = config.ADMIN_GROUP_ID
    if method == "GetGroupRank":
        try:
            if playerid is None or groupid is None:
                return MakeReturnIntResponse(0)
            if playerid < 1 or groupid < 1:
                return MakeReturnIntResponse(0)
            return MakeReturnIntResponse(GetUserRankInGroup(playerid, groupid))
        except GroupExceptions.GroupDoesNotExist:
            return MakeReturnIntResponse(0)
        except GroupExceptions.UserDoesNotExist:
            return MakeReturnIntResponse(0)
    elif method == "IsInGroup":
        try:
            if playerid is None or groupid is None:
                return MakeReturnFalseResponse()
            if playerid < 1 or groupid < 1:
                return MakeReturnFalseResponse()
            if GetUserRankInGroup(playerid, groupid) == 0:
                return MakeReturnFalseResponse()
            return MakeReturnTrueResponse()
        except GroupExceptions.GroupDoesNotExist:
            return MakeReturnFalseResponse()
        except GroupExceptions.UserDoesNotExist:
            return MakeReturnFalseResponse()
    elif method == "GetGroupRole":
        try:
            if playerid is None or groupid is None:
                return MakeReturnStringResponse("Guest")
            if playerid < 1 or groupid < 1:
                return MakeReturnStringResponse("Guest")
            if GetUserRankInGroup(playerid, groupid) == 0:
                return MakeReturnStringResponse("Guest")
            Roleset : GroupRole = GetUserRolesetInGroup(playerid, groupid)
            return MakeReturnStringResponse(Roleset.name)
        except GroupExceptions.GroupDoesNotExist:
            return MakeReturnStringResponse("Guest")
        except GroupExceptions.UserDoesNotExist:
            return MakeReturnStringResponse("Guest")
    elif method == "IsFriendsWith":
        try:
            if playerid is None or userid is None:
                return MakeReturnFalseResponse()
            if playerid < 1 or userid < 1:
                return MakeReturnFalseResponse()
            FriendRelationshipObj : FriendRelationship = friends.GetFriendRelationship(playerid, userid)
            if FriendRelationshipObj is None:
                return MakeReturnFalseResponse()
            return MakeReturnTrueResponse()
        except Exception as e:
            logging.error(f"IsFriendsWith: {e}")
            return MakeReturnFalseResponse()

    return MakeReturnFalseResponse()

@LuaWebServiceRoute.route("/Game/GamePass/GamePassHandler.ashx", methods=['GET'])
def GamePassHandler():
    Action = request.args.get("Action", None, str)
    UserID = request.args.get("UserID", None, int)
    PassID = request.args.get("PassID", None, int)
    if Action is None or UserID is None or PassID is None:
        return MakeReturnFalseResponse()
    if Action == "HasPass":
        AssetObj : Asset = Asset.query.filter_by(id=PassID).first()
        if AssetObj is None:
            return MakeReturnFalseResponse()
        if AssetObj.asset_type != AssetType.GamePass:
            return MakeReturnFalseResponse()
        
        UserAssetObj : UserAsset = UserAsset.query.filter_by(userid=UserID, assetid=PassID).first()
        if UserAssetObj is None:
            return MakeReturnFalseResponse()
        return MakeReturnTrueResponse()
    return MakeReturnFalseResponse()

@LuaWebServiceRoute.route("/user/request-friendship", methods=['POST'])
@auth.authenticated_client_endpoint
@csrf.exempt
@limiter.limit("1/second")
def RequestFriendship():
    UserID = request.args.get("recipientUserId", None, int)
    if UserID is None:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id == UserID:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    TargetUserObj : User = User.query.filter_by(id=UserID).first()
    if TargetUserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    
    TargetPlaceServerPlayerObj : PlaceServerPlayer | None = PlaceServerPlayer.query.filter_by(userid=UserID).first()
    if TargetPlaceServerPlayerObj is None:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    AuthenticatedPlaceServerPlayerObj : PlaceServerPlayer | None = PlaceServerPlayer.query.filter_by(userid=AuthenticatedUser.id).first()
    if AuthenticatedPlaceServerPlayerObj is None:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    if TargetPlaceServerPlayerObj.serveruuid != AuthenticatedPlaceServerPlayerObj.serveruuid:
        return jsonify({"success": False, "message": "Invalid request"}), 400
    
    FriendRelationshipObj : FriendRelationship | None = friends.GetFriendRelationship(AuthenticatedUser.id, UserID)
    if FriendRelationshipObj is not None:
        return jsonify({"success": True }),200
    FriendRequestObj : FriendRequest | None = FriendRequest.query.filter_by(requester_id=AuthenticatedUser.id, requestee_id=UserID).first()
    if FriendRequestObj is not None:
        return jsonify({"success": True }),200
    FriendRequestObj : FriendRequest | None = FriendRequest.query.filter_by(requester_id=UserID, requestee_id=AuthenticatedUser.id).first()
    if FriendRequestObj is not None:
        FriendRelationshipObj : FriendRelationship = FriendRelationship(
            user_id=AuthenticatedUser.id,
            friend_id=UserID
        )
        db.session.add(FriendRelationshipObj)
        db.session.delete(FriendRequestObj)
        db.session.commit()
        return jsonify({"success": True }),200
    FriendRequestObj : FriendRequest = FriendRequest(
        requester_id=AuthenticatedUser.id,
        requestee_id=UserID
    )
    db.session.add(FriendRequestObj)
    db.session.commit()
    return jsonify({"success": True }),200

@LuaWebServiceRoute.route("/user/decline-friend-request", methods=['POST'])
@auth.authenticated_client_endpoint
@csrf.exempt
@limiter.limit("1/second")
def DeclineFriendRequest():
    UserID = request.args.get("requesterUserId", None, int)
    if UserID is None:
        jsonify({"success": False, "message": "Invalid request"}), 400
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id == UserID:
        jsonify({"success": False, "message": "Invalid request"}), 400
    TargetUserObj : User = User.query.filter_by(id=UserID).first()
    if TargetUserObj is None:
        jsonify({"success": False, "message": "Invalid request"}), 400
    FriendRequestObj : FriendRequest | None = FriendRequest.query.filter_by(requester_id=UserID, requestee_id=AuthenticatedUser.id).first()
    if FriendRequestObj is None:
        FriendRelationshipObj : FriendRelationship | None = friends.GetFriendRelationship(AuthenticatedUser.id, UserID)
        if FriendRelationshipObj is None:
            jsonify({"success": False, "message": "Invalid request"}), 400
        db.session.delete(FriendRelationshipObj)
        db.session.commit()
        return jsonify({"success": True }),200
    db.session.delete(FriendRequestObj)
    db.session.commit()
    return jsonify({"success": True }),200

@LuaWebServiceRoute.route("/user/following-exists", methods=["GET"])
@limiter.limit("60/minute")
def FollowingExists():
    UserID = request.args.get("userId", None, int)
    FollowerUserID = request.args.get("followerUserId", None, int)
    if UserID is None or FollowerUserID is None:
        return jsonify({"success": False, "isFollowing": False})
    
    FollowedUserObj : User = User.query.filter_by(id=UserID).first()
    FollowerUserObj : User = User.query.filter_by(id=FollowerUserID).first()
    if FollowedUserObj is None or FollowerUserObj is None:
        return jsonify({"success": False, "isFollowing": False})
    
    return jsonify({"success": True, "isFollowing": followings.is_following( follower_user = FollowerUserObj, followed_user = FollowedUserObj)})

@LuaWebServiceRoute.route("/user/get-friendship-count", methods=["GET"])
@limiter.limit("60/minute")
def GetFriendshipCount():
    UserID = request.args.get("userId", None, int)
    if UserID is None:
        AuthenticatedUser = auth.GetCurrentUser()
        if AuthenticatedUser is None:
            return jsonify({"success": False, "count": 0})
        UserID = AuthenticatedUser.id
    
    FriendRelationshipCount : int = FriendRelationship.query.filter(or_( FriendRelationship.user_id == UserID, FriendRelationship.friend_id == UserID)).count()

    return jsonify({"success": True, "count": FriendRelationshipCount})

@LuaWebServiceRoute.route("/user/follow", methods=["POST"])
@csrf.exempt
@auth.authenticated_client_endpoint
@limiter.limit("20/minute")
def FollowUser():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    TargetUserId = request.form.get("followedUserId", None, int)
    if TargetUserId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    if TargetUserId == AuthenticatedUser.id:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    TargetUserObj : User = User.query.filter_by(id=TargetUserId).first()
    if TargetUserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400

    try:
        followings.follow_user(
            follower_user = AuthenticatedUser,
            followed_user = TargetUserObj
        )
    except followings.FollowingExceptions.AlreadyFollowing:
        return jsonify({"success": True}),200
    except followings.FollowingExceptions.UserRateLimited:
        return jsonify({"success": False, "message": "Rate limited"}),429
    except followings.FollowingExceptions.FollowingIsDisabled:
        return jsonify({"success": False, "message": "Following is disabled"}),400

    return jsonify({"success": True}),200

@LuaWebServiceRoute.route("/user/unfollow", methods=["POST"])
@csrf.exempt
@auth.authenticated_client_endpoint
@limiter.limit("20/minute")
def UnfollowUser():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    TargetUserId = request.form.get("followedUserId", None, int)
    if TargetUserId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    if TargetUserId == AuthenticatedUser.id:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    TargetUserObj : User = User.query.filter_by(id=TargetUserId).first()
    if TargetUserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    try:
        followings.unfollow_user(
            current_follower = AuthenticatedUser,
            followed_user = TargetUserObj
        )
    except followings.FollowingExceptions.UserNotFollowing:
        return jsonify({"success": True}),200
    except followings.FollowingExceptions.UserRateLimited:
        return jsonify({"success": False, "message": "Rate limited"}),429

    return jsonify({"success": True}),200

@LuaWebServiceRoute.route("/my/economy-status", methods=["GET"])
@auth.authenticated_client_endpoint
def EconomyStatus():
    return jsonify({
        "success": True,
        "isMarketplaceEnabled": websiteFeatures.GetWebsiteFeature("EconomyPurchase")
    })

@LuaWebServiceRoute.route("/currency/balance", methods=["GET"])
@auth.authenticated_client_endpoint
def EconomyBalance():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    RobuxBal, TixBal = economy.GetUserBalance(AuthenticatedUser)
    return jsonify({
        "success": True,
        "robux": RobuxBal,
        "tickets": TixBal
    })

@LuaWebServiceRoute.route("/ownership/hasasset", methods=["GET"])
@LuaWebServiceRoute.route("/ownership/hasAsset", methods=["GET"])
@auth.gameserver_authenticated_required
def HasAsset():
    AssetID = request.args.get("assetId", None, int)
    if AssetID is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    UserId = request.args.get("userId", None, int)
    if UserId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    AssetObj : Asset = Asset.query.filter_by(id=AssetID).first()
    if AssetObj is None:
        return "false",200
    UserAssetObj : UserAsset = UserAsset.query.filter_by(userid=UserId, assetid=AssetID).first()
    if UserAssetObj is None:
        return "false",200
    return "true",200

@LuaWebServiceRoute.route("/Friend/AreFriends", methods=["GET"])
@auth.gameserver_authenticated_required
def AreFriends():
    userId = request.args.get("userId", None, int)
    otherUserId = request.args.get("otherUserId", None, int)
    otherUserIdList = request.args.getlist("otherUserIds")
    if userId is None or ( otherUserId is None and len(otherUserIdList) == 0):
        return jsonify({"success": False, "message": "Invalid request"}),400
    if otherUserId is not None:
        FriendRelationshipObj : FriendRelationship = friends.GetFriendRelationship(userId, otherUserId)
        if FriendRelationshipObj is not None:
            return jsonify({"success": True, "friendStatus": 2})
        FriendRequestObj : FriendRequest = FriendRequest.query.filter_by(requester_id = userId, requestee_id=otherUserId).first()
        if FriendRequestObj is not None:
            return jsonify({"success": True, "friendStatus": 3})
        FriendRequestObj : FriendRequest = FriendRequest.query.filter_by(requester_id = otherUserId, requestee_id=userId).first()
        if FriendRequestObj is not None:
            return jsonify({"success": True, "friendStatus": 4})
        return jsonify({"success": True, "friendStatus": 1})
    else:
        if len(otherUserIdList) > 100:
            return jsonify({"success": False, "message": "Invalid request"}),400

        RequestResult = ""
        for TargetUserId in otherUserIdList:
            try:
                TargetUserId = int(TargetUserId)
            except:
                continue
            FriendRelationshipObj : FriendRelationship = friends.GetFriendRelationship(userId, TargetUserId)
            if FriendRelationshipObj is not None:
                RequestResult += f"{str(TargetUserId)},"
                continue
        return RequestResult,200

@LuaWebServiceRoute.route("/Friend/CreateFriend", methods=["POST"])
@csrf.exempt
@auth.gameserver_authenticated_required
def CreateFriend():
    firstUserId = request.args.get( "firstUserId", default = None, type = int )
    secondUserId = request.args.get( "secondUserId", default = None, type = int )

    if firstUserId is None or secondUserId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    firstUserObj : User = User.query.filter_by(id=firstUserId).first()
    secondUserObj : User = User.query.filter_by(id=secondUserId).first()
    if firstUserObj is None or secondUserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    FriendRelationshipObj : FriendRelationship = friends.GetFriendRelationship(firstUserId, secondUserId)
    if FriendRelationshipObj is not None:
        return jsonify({"success": True}),200
    
    FriendRequestObj : FriendRequest = FriendRequest.query.filter_by(requester_id=firstUserId, requestee_id=secondUserId).first()
    if FriendRequestObj is not None:
        db.session.delete(FriendRequestObj)
    SecondFriendRequestObj : FriendRequest = FriendRequest.query.filter_by(requester_id=secondUserId, requestee_id=firstUserId).first()
    if SecondFriendRequestObj is not None:
        db.session.delete(SecondFriendRequestObj)

    FriendRelationshipObj = FriendRelationship(
        user_id=firstUserId,
        friend_id=secondUserId
    )
    db.session.add(FriendRelationshipObj)
    db.session.commit()

    return jsonify({"success": True}),200

@LuaWebServiceRoute.route("/Friend/BreakFriend", methods=["POST"])
@csrf.exempt
@auth.gameserver_authenticated_required
def BreakFriend():
    firstUserId = request.args.get( "firstUserId", default = None, type = int )
    secondUserId = request.args.get( "secondUserId", default = None, type = int )

    if firstUserId is None or secondUserId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    firstUserObj : User = User.query.filter_by(id=firstUserId).first()
    secondUserObj : User = User.query.filter_by(id=secondUserId).first()
    if firstUserObj is None or secondUserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    FriendRelationshipObj : FriendRelationship = friends.GetFriendRelationship(firstUserId, secondUserId)
    if FriendRelationshipObj is not None:
        db.session.delete(FriendRelationshipObj)
        db.session.commit()
    
    return jsonify({"success": True}),200

@LuaWebServiceRoute.route("/Friend/CreateFriendRequest", methods=["POST"])
@csrf.exempt
@auth.gameserver_authenticated_required
def CreateFriendRequest():
    requesterUserId = request.args.get( "requesterUserId", default = None, type = int )
    requestedUserId = request.args.get( "requestedUserId", default = None, type = int )

    if requesterUserId is None or requestedUserId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    requesterUserObj : User = User.query.filter_by(id=requesterUserId).first()
    requestedUserObj : User = User.query.filter_by(id=requestedUserId).first()

    if requesterUserObj is None or requestedUserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    FriendRelationshipObj : FriendRelationship = friends.GetFriendRelationship(requesterUserId, requestedUserId)
    if FriendRelationshipObj is not None:
        return jsonify({"success": True}),200
    
    FriendRequestObj : FriendRequest = FriendRequest.query.filter_by(requester_id=requesterUserId, requestee_id=requestedUserId).first()
    OtherFriendRequestObj : FriendRequest = FriendRequest.query.filter_by(requester_id=requestedUserId, requestee_id=requesterUserId).first()
    if FriendRequestObj is not None and OtherFriendRequestObj is None:
        return jsonify({"success": True}),200
    
    if OtherFriendRequestObj is not None:
        if FriendRequestObj is not None:
            db.session.delete(FriendRequestObj)
        
        db.session.delete(OtherFriendRequestObj)
        FriendRelationshipObj = FriendRelationship(
            user_id=requesterUserId,
            friend_id=requestedUserId
        )
        db.session.add(FriendRelationshipObj)
        db.session.commit()

        return jsonify({"success": True}),200

    FriendRequestObj = FriendRequest(
        requester_id=requesterUserId,
        requestee_id=requestedUserId
    )
    db.session.add(FriendRequestObj)
    db.session.commit()

    return jsonify({"success": True}),200

@LuaWebServiceRoute.route("/Friend/DeleteFriendRequest", methods=["POST"])
@csrf.exempt
@auth.gameserver_authenticated_required
def DeleteFriendRequest():
    requesterUserId = request.args.get( "requesterUserId", default = None, type = int )
    requestedUserId = request.args.get( "requestedUserId", default = None, type = int )

    if requesterUserId is None or requestedUserId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    requesterUserObj : User = User.query.filter_by(id=requesterUserId).first()
    requestedUserObj : User = User.query.filter_by(id=requestedUserId).first()

    if requesterUserObj is None or requestedUserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    FriendRequestObj : FriendRequest = FriendRequest.query.filter_by(requester_id=requesterUserId, requestee_id=requestedUserId).first()
    if FriendRequestObj is not None:
        db.session.delete(FriendRequestObj)
        db.session.commit()

    return jsonify({"success": True}),200

@LuaWebServiceRoute.route("/v2/users/<int:userId>/groups/roles", methods=["GET"])
def GetUserGroupRoles( userId : int ):
    if userId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    UserObj : User = User.query.filter_by(id=userId).first()
    if UserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400

    GroupRoles = []
    UserGroupMemberList : list[GroupMember] = GroupMember.query.filter_by(user_id = userId).all()
    for GroupMemberObj in UserGroupMemberList:
        GroupRoles.append({
            "group": {
                "id": GroupMemberObj.group_id,
                "name": GroupMemberObj.group.name,
                "memberCount": GetGroupMemberCount(GroupMemberObj.group)
            },
            "role" : {
                "id": GroupMemberObj.group_role_id,
                "name": GroupMemberObj.group_role.name,
                "rank": GroupMemberObj.group_role.rank
            }
        })

        if GroupMemberObj.group_id == config.ADMIN_GROUP_ID:
            GroupRoles.append({
                "group": {
                    "id": 1200769,
                    "name": GroupMemberObj.group.name,
                    "memberCount": GetGroupMemberCount(GroupMemberObj.group)
                },
                "role" : {
                    "id": GroupMemberObj.group_role_id,
                    "name": GroupMemberObj.group_role.name,
                    "rank": GroupMemberObj.group_role.rank
                }
            })

    return jsonify({
        "data": GroupRoles
    })

@LuaWebServiceRoute.route("/users/get-by-username/", methods=["GET"])
def GetUserByUsername():
    RequestedUsername = request.args.get(
        key = "username",
        default = None,
        type = str
    )
    if RequestedUsername is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    UserObj : User = User.query.filter(func.lower(User.username) == func.lower(RequestedUsername)).first()
    if UserObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    return jsonify({
        "Id": UserObj.id,
        "Username": UserObj.username
    }), 200