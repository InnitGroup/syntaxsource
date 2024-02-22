from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, flash, abort
from app.util import auth, friends, membership, websiteFeatures, placeinfo
from app.extensions import db, limiter, csrf, user_limiter
from app.models.user import User
from app.models.friend_request import FriendRequest
from app.models.friend_relationship import FriendRelationship
from datetime import datetime
from app.models.asset import Asset
from app.models.place import Place
from app.models.placeserver_players import PlaceServerPlayer
from app.models.follow_relationship import FollowRelationship
from app.models.user_avatar_asset import UserAvatarAsset
from app.models.userassets import UserAsset
from app.models.universe import Universe
from app.models.place_badge import PlaceBadge, UserBadge
from app.enums.AssetType import AssetType
from sqlalchemy import or_
from app.enums.MembershipType import MembershipType
from slugify import slugify
from app.routes.rate import GetAssetLikesAndDislikes, GetUserVoteStatus, GetAssetVotePercentage, GetAssetFavoriteCount, GetUserFavoriteStatus
from app.services import economy

from app.services.user_relationships import followings

Profile = Blueprint("profile", __name__, template_folder="pages")

@Profile.route("/users/<int:userid>/profile", methods=["GET"])
@auth.authenticated_required
def profile_page(userid):
    user : User = User.query.filter_by(id=userid).first()
    if user is None:
        abort(404)
    if user.accountstatus == 4 or user.accountstatus == 3:
        abort(404)

    Friends = friends.GetFriends(user.id)
    FriendCount = len(Friends)
    DescriptionLines = user.description.split("\n")
    FriendsData = []
    for friend in Friends:
        friendObjData = {}
        friendObjData = {
            "id": friend.id,
            "username": friend.username,
            "isonline": True if (datetime.utcnow() - friend.lastonline).total_seconds() < 60 else False,
            "ingame": True if PlaceServerPlayer.query.filter_by(userid=friend.id).first() is not None else False
        }
        FriendsData.append(friendObjData)
    FriendsData.sort(key=lambda x: x["isonline"], reverse=True)
    FriendsData.sort(key=lambda x: x["ingame"], reverse=True)
    FriendsData = FriendsData[:8]

    AuthenticatedUser = auth.GetCurrentUser()
    if AuthenticatedUser.id != user.id:
        isFriends = friends.IsFriends(AuthenticatedUser.id, user.id)
        FriendRequestPending = FriendRequest.query.filter_by(requester_id=AuthenticatedUser.id, requestee_id=user.id).first() is not None
        FriendRequestToAuthenticatedUser = FriendRequest.query.filter_by(requester_id=user.id, requestee_id=AuthenticatedUser.id).first() is not None
        isViewerFollowing = FollowRelationship.query.filter_by(followerUserId=AuthenticatedUser.id, followeeUserId=user.id).first() is not None
        doesTargetUserFollowViewer = FollowRelationship.query.filter_by(followerUserId=user.id, followeeUserId=AuthenticatedUser.id).first() is not None
    else:
        isFriends = False
        FriendRequestPending = False
        FriendRequestToAuthenticatedUser = False
        isViewerFollowing = False
        doesTargetUserFollowViewer = False
    joindate = user.created.strftime("%d/%m/%Y")
    TotalVisits = 0
    UniverseList : list[Universe] = Universe.query.filter_by( creator_id = user.id, creator_type = 0 ).all()
    for UniverseObj in UniverseList:
        TotalVisits += UniverseObj.visit_count

    FollowerCount = followings.get_follower_count( user )
    FollowingCount = followings.get_following_count( user )
    WearingAssets = UserAvatarAsset.query.filter_by(user_id=user.id).all()
    membershipValue : int = membership.GetUserMembership(user.id).value

    UserGames : list[Asset] = Asset.query.filter_by(creator_id = user.id, creator_type = 0, asset_type = AssetType.Place).all()
    UserGamesInfo : list[dict] = []
    for UserGame in UserGames:
        PlaceObj : Place = Place.query.filter_by(placeid=UserGame.id).first()
        if PlaceObj is None:
            continue
        if PlaceObj.is_public == False:
            continue

        PlaceObjData = {
            "id": UserGame.id,
            "name": UserGame.name,
            "playingcount": placeinfo.GetPlayingCount( PlaceObj ),
            "slug": slugify(UserGame.name, lowercase=False) if UserGame.name is not None else "",
            "likePercentage": GetAssetVotePercentage(UserGame.id),
            "placeyear": PlaceObj.placeyear
        }
        UserGamesInfo.append(PlaceObjData)

    ProfileData = {
        "username": user.username,
        "id": user.id,
        "friendcount": FriendCount,
        "isonline": True if (datetime.utcnow() - user.lastonline).total_seconds() < 60 else False,
        "ingame": True if PlaceServerPlayer.query.filter_by(userid=user.id).first() is not None else False,
        "isfriends": isFriends,
        "friendrequestpending": FriendRequestPending,
        "friendrequesttoauthenticateduser": FriendRequestToAuthenticatedUser,
        "friendsdata": FriendsData,
        "joindate": joindate,
        "TotalVisits": TotalVisits,
        "FollowerCount": FollowerCount,
        "FollowingCount": FollowingCount,
        "wearing": WearingAssets,
        "isviewerfollowing": isViewerFollowing,
        "doestargetuserfollowviewer": doesTargetUserFollowViewer,
        "membershipValue": membershipValue,
        "UserGames": UserGamesInfo,
        "UserRAP": economy.CalculateUserRAP( user )
    }

    return render_template("profiles/profile.html", profile=ProfileData, descriptionlines=DescriptionLines)

@Profile.route("/users/<int:userid>/addfriend", methods=["POST"])
@limiter.limit("5/minute")
@auth.authenticated_required
@user_limiter.limit("5/minute")
def add_friend(userid):
    user = User.query.filter_by(id=userid).first()
    if user is None:
        abort(404)
    if user.accountstatus == 4 or user.accountstatus == 3:
        abort(404)
    if not websiteFeatures.GetWebsiteFeature("SendFriendRequest"):
        flash("Adding friends is temporarily disabled.", "error")
        return redirect(f"/users/{user.id}/profile")
    AuthenticatedUser = auth.GetCurrentUser()

    if userid == AuthenticatedUser.id:
        flash("You cannot add yourself as a friend.", "error")
        return redirect(f"/users/{user.id}/profile")
    
    if FriendRequest.query.filter_by(requester_id=AuthenticatedUser.id, requestee_id=user.id).first() is not None:
        flash("You have already sent a friend request to this user.", "error")
        return redirect(f"/users/{user.id}/profile")
    
    if friends.IsFriends(AuthenticatedUser.id, user.id):
        flash("You are already friends with this user.", "error")
        return redirect(f"/users/{user.id}/profile")
    
    friendRequest = FriendRequest(requester_id=AuthenticatedUser.id, requestee_id=user.id)
    db.session.add(friendRequest)
    db.session.commit()

    return redirect(f"/users/{user.id}/profile")

@Profile.route("/users/<int:userid>/unfriend", methods=["POST"])
@limiter.limit("5/minute")
@auth.authenticated_required
@user_limiter.limit("5/minute")
def unfriend(userid):
    user = User.query.filter_by(id=userid).first()
    if user is None:
        abort(404)
    AuthenticatedUser = auth.GetCurrentUser()

    if not friends.IsFriends(AuthenticatedUser.id, user.id):
        flash("You are not friends with this user.", "error")
        return handle_redirect(user)
    
    Friendrelationship : FriendRelationship = friends.GetFriendRelationship(AuthenticatedUser.id, user.id)
    db.session.delete(Friendrelationship)
    db.session.commit()

    return handle_redirect(user)

def handle_redirect(user):
    wantRedirect = request.args.get("redirect", type=int, default=1)
    if wantRedirect == 1:
        return redirect(f"/users/{user.id}/profile")
    else:
        return redirect(request.referrer)


@Profile.route("/users/<int:userid>/acceptfriend", methods=["POST"])
@limiter.limit("30/minute")
@auth.authenticated_required
@user_limiter.limit("30/minute")
def accept_friend(userid):
    user = User.query.filter_by(id=userid).first()
    if user is None:
        abort(404)
    if user.accountstatus == 4 or user.accountstatus == 3:
        abort(404)
    if not websiteFeatures.GetWebsiteFeature("SendFriendRequest"):
        flash("Adding friends is temporarily disabled.", "error")
        return handle_redirect(user)
    AuthenticatedUser = auth.GetCurrentUser()
    if userid == AuthenticatedUser.id:
        flash("You cannot add yourself as a friend.", "error")
        return handle_redirect(user)
    
    friendRequest = FriendRequest.query.filter_by(requester_id=user.id, requestee_id=AuthenticatedUser.id).first()
    if friendRequest is None:
        flash("Friend request not found.", "error")
        return handle_redirect(user)
    
    FriendCount = len(friends.GetFriends(user.id))
    if FriendCount >= 200:
        flash("This user has reached their friend limit.", "error")
        return handle_redirect(user)
    
    AuthenticatedUserFriendCount = len(friends.GetFriends(AuthenticatedUser.id))
    if AuthenticatedUserFriendCount >= 200:
        flash("You have reached your friend limit.", "error")
        return handle_redirect(user)
    
    Friendrelationship = FriendRelationship(user_id=user.id, friend_id=AuthenticatedUser.id)
    db.session.add(Friendrelationship)
    db.session.delete(friendRequest)
    db.session.commit()

    return handle_redirect(user)

@Profile.route("/users/<int:userid>/declinefriend", methods=["POST"])
@limiter.limit("30/minute")
@auth.authenticated_required
@user_limiter.limit("30/minute")
def decline_friend(userid):
    TargetUser = User.query.filter_by(id=userid).first()
    if TargetUser is None:
        abort(404)
    
    if not websiteFeatures.GetWebsiteFeature("SendFriendRequest"):
        flash("Declining friend requests is temporarily disabled.", "error")
        return handle_redirect(TargetUser)
    AuthenticatedUser = auth.GetCurrentUser()
    if userid == AuthenticatedUser.id:
        abort(404)
    friendRequest = FriendRequest.query.filter_by(requester_id=TargetUser.id, requestee_id=AuthenticatedUser.id).first()
    if friendRequest is None:
        return handle_redirect(TargetUser)
    db.session.delete(friendRequest)
    db.session.commit()
    return handle_redirect(TargetUser)
    

@Profile.route("/users/<int:userid>/unfollowuser", methods=["POST"])
@limiter.limit("5/minute")
@auth.authenticated_required
def unfollow_user(userid):
    UserObj : User = User.query.filter_by(id=userid).first()
    if UserObj is None:
        abort(404)
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    try:
        followings.unfollow_user(
            current_follower = AuthenticatedUser, followed_user = UserObj
        )
    except followings.FollowingExceptions.UserNotFollowing:
        flash("You are not following this user.", "error")
        return redirect(f"/users/{UserObj.id}/profile")
    except followings.FollowingExceptions.UserRateLimited:
        flash("You are being rate limited from unfollowing users, please slow down.", "error")
        return redirect(f"/users/{UserObj.id}/profile")

    return redirect(f"/users/{UserObj.id}/profile")

@Profile.route("/users/<int:userid>/followuser", methods=["POST"])
@limiter.limit("5/minute")
@auth.authenticated_required
def follow_user(userid):
    UserObj : User = User.query.filter_by( id = userid ).first()
    if UserObj is None:
        abort(404)
    if UserObj.accountstatus == 4 or UserObj.accountstatus == 3:
        abort(404)

    AuthenticatedUser : User = auth.GetCurrentUser()
    try:
        followings.follow_user(
            follower_user = AuthenticatedUser, followed_user = UserObj
        )
    except followings.FollowingExceptions.AlreadyFollowing:
        flash("You are already following this user.", "error")
        return redirect(f"/users/{UserObj.id}/profile")
    except followings.FollowingExceptions.UserRateLimited:
        flash("You are being rate limited from following users, please slow down.", "error")
        return redirect(f"/users/{UserObj.id}/profile")
    except followings.FollowingExceptions.CannotFollowSelf:
        flash("You cannot follow yourself.", "error")
        return redirect(f"/users/{UserObj.id}/profile")
    except followings.FollowingExceptions.FollowingIsDisabled:
        flash("Following users is disabled.", "error")
        return redirect(f"/users/{UserObj.id}/profile")

    return redirect(f"/users/{UserObj.id}/profile")

@Profile.route("/users/<int:userid>/friends", methods=["GET"])
@auth.authenticated_required
def FriendsPage( userid : int ):
    user = User.query.filter_by(id=userid).first()
    if user is None:
        abort(404)
    if user.accountstatus == 4 or user.accountstatus == 3:
        abort(404)
    PageNumber = request.args.get("page", 1, type=int)

    from app.models.friend_relationship import FriendRelationship
    FriendRelationships : list[FriendRelationship] = FriendRelationship.query.filter(
        or_(
            FriendRelationship.user_id == user.id,
            FriendRelationship.friend_id == user.id
        )
    ).join(
        User,
        or_(
            FriendRelationship.user_id == User.id,
            FriendRelationship.friend_id == User.id
        )
    ).filter(
        User.id != user.id
    ).order_by(
        User.username
    ).paginate(
        page=PageNumber,
        per_page=18,
        error_out=False
    )
    FriendUsers : list[User] = []
    for FriendRelationshipObj in FriendRelationships:
        if FriendRelationshipObj.user_id == user.id:
            TargetUserId : int = FriendRelationshipObj.friend_id
        else:
            TargetUserId : int = FriendRelationshipObj.user_id
        FriendUser : User = User.query.filter_by(id=TargetUserId).first()
        if FriendUser is not None:
            FriendUsers.append({
                "id": FriendUser.id,
                "username": FriendUser.username,
                "isonline": True if (datetime.utcnow() - FriendUser.lastonline).total_seconds() < 60 else False,
                "ingame": True if PlaceServerPlayer.query.filter_by(userid=FriendUser.id).first() is not None else False
            })
    FriendCount = FriendRelationship.query.filter((FriendRelationship.user_id == user.id) | (FriendRelationship.friend_id == user.id)).count()
    if FriendRelationships.pages < PageNumber:
        redirect(f"/users/{user.id}/friends")

    return render_template("profiles/friends.html", 
                           profile=user, 
                           FriendUsers=FriendUsers,
                           PageNumber=PageNumber,
                           isThereNextPage=FriendRelationships.has_next,
                           isTherePreviousPage=FriendRelationships.has_prev,
                           FriendCount=FriendCount,
                           TotalPages=FriendRelationships.pages)

@Profile.route("/users/<int:userid>/following", methods=["GET"])
@auth.authenticated_required
def FollowingPage( userid : int ):
    user = User.query.filter_by(id=userid).first()
    if user is None:
        abort(404)
    if user.accountstatus == 4 or user.accountstatus == 3:
        abort(404)
    PageNumber = request.args.get("page", 1, type=int)

    from app.models.follow_relationship import FollowRelationship
    FollowRelationships : list[FollowRelationship] = FollowRelationship.query.filter_by(followerUserId=user.id).join(
        User,
        FollowRelationship.followeeUserId == User.id
    ).order_by(
        User.username
    ).paginate(
        page=PageNumber,
        per_page=18,
        error_out=False
    )
    FollowUsers : list[User] = []
    for FollowRelationship in FollowRelationships:
        FollowUser : User = User.query.filter_by(id=FollowRelationship.followeeUserId).first()
        if FollowUser is not None:
            FollowUsers.append({
                "id": FollowUser.id,
                "username": FollowUser.username,
                "isonline": True if (datetime.utcnow() - FollowUser.lastonline).total_seconds() < 60 else False,
                "ingame": True if PlaceServerPlayer.query.filter_by(userid=FollowUser.id).first() is not None else False
            })
    FollowCount = FollowRelationship.query.filter_by(followerUserId=user.id).count()
    if FollowRelationships.pages < PageNumber:
        redirect(f"/users/{user.id}/following")

    return render_template("profiles/following.html", 
                           profile=user, 
                           FollowUsers=FollowUsers,
                           PageNumber=PageNumber,
                           isThereNextPage=FollowRelationships.has_next,
                           isTherePreviousPage=FollowRelationships.has_prev,
                           FollowCount=FollowCount,
                           TotalPages=FollowRelationships.pages)

@Profile.route("/users/<int:userid>/followers", methods=["GET"])
@auth.authenticated_required
def FollowersPage( userid : int ):
    user = User.query.filter_by(id=userid).first()
    if user is None:
        abort(404)
    if user.accountstatus == 4 or user.accountstatus == 3:
        abort(404)
    PageNumber = request.args.get("page", 1, type=int)
    
    from app.models.follow_relationship import FollowRelationship
    FollowRelationships : list[FollowRelationship] = FollowRelationship.query.filter_by(followeeUserId=user.id).join(
        User,
        FollowRelationship.followerUserId == User.id
    ).order_by(
        User.username
    ).paginate(
        page=PageNumber,
        per_page=18,
        error_out=False
    )
    FollowUsers : list[User] = []
    for FollowRelationship in FollowRelationships:
        FollowUser : User = User.query.filter_by(id=FollowRelationship.followerUserId).first()
        if FollowUser is not None:
            FollowUsers.append({
                "id": FollowUser.id,
                "username": FollowUser.username,
                "isonline": True if (datetime.utcnow() - FollowUser.lastonline).total_seconds() < 60 else False,
                "ingame": True if PlaceServerPlayer.query.filter_by(userid=FollowUser.id).first() is not None else False
            })
    FollowCount = FollowRelationship.query.filter_by(followeeUserId=user.id).count()
    if FollowRelationships.pages < PageNumber:
        redirect(f"/users/{user.id}/followers")

    return render_template("profiles/followers.html", 
                           profile=user, 
                           FollowUsers=FollowUsers,
                           PageNumber=PageNumber,
                           isThereNextPage=FollowRelationships.has_next,
                           isTherePreviousPage=FollowRelationships.has_prev,
                           FollowCount=FollowCount,
                           TotalPages=FollowRelationships.pages)

@Profile.route("/users/<int:userid>/requests", methods=["GET"])
@auth.authenticated_required
def FriendRequestsPage( userid : int ):
    AuthenticatedUser = auth.GetCurrentUser()
    if AuthenticatedUser.id != userid:
        abort(404)
    PageNumber = request.args.get("page", 1, type=int)
    FriendRequests : list[FriendRequest] = FriendRequest.query.filter_by(requestee_id=userid).order_by(FriendRequest.created_at.desc()).paginate(page=PageNumber, per_page=18, error_out=False)
    return render_template("profiles/requests.html",
                            profile=AuthenticatedUser,
                            FriendRequests=FriendRequests)

@Profile.route("/users/<int:userid>/requests/clear", methods=["POST"])
@auth.authenticated_required
def ClearFriendRequests(userid : int):
    AuthenticatedUser = auth.GetCurrentUser()
    if AuthenticatedUser.id != userid:
        abort(404)
    FriendRequests : list[FriendRequest] = FriendRequest.query.filter_by(requestee_id=userid).all()
    for FriendRequestObj in FriendRequests:
        db.session.delete(FriendRequestObj)
    db.session.commit()
    return redirect(f"/users/{userid}/requests")

@Profile.route("/users/<int:userid>/inventory", methods=["GET"])
@auth.authenticated_required
def UserInventoryPage( userid : int ):
    UserObj : User = User.query.filter_by( id = userid ).first()
    if UserObj is None:
        return abort(404)
    
    InventoryTypesDict = {
        0: lambda queryObj: queryObj.filter(Asset.asset_type.in_((
            AssetType.HairAccessory,
            AssetType.FaceAccessory,
            AssetType.NeckAccessory,
            AssetType.ShoulderAccessory,
            AssetType.FrontAccessory,
            AssetType.BackAccessory,
            AssetType.WaistAccessory,
        ))),
        1: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Audio ),
        2: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Package ),
        3: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Face ),
        4: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Head ),
        5: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Hat ),
        6: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.GamePass ),
        7: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.TShirt ),
        8: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Shirt ),
        9: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Pants ),
        10: lambda queryObj: queryObj.filter( Asset.asset_type == AssetType.Gear )
    }
    InventoryTypeToFriendlyName = {
        0: "Accessories",
        1: "Audio",
        2: "Packages",
        3: "Faces",
        4: "Heads",
        5: "Hats",
        6: "Passes",
        7: "T-Shirts",
        8: "Shirts",
        9: "Pants",
        10: "Gears",
        11: "Badges"
    }

    CategoryType = request.args.get( key = "category", default = 0, type = int )
    if CategoryType not in InventoryTypeToFriendlyName:
        return redirect(f"/users/{userid}/inventory")
    PageNumber = request.args.get( key = "page", default = 1, type = int )
    if PageNumber < 1:
        PageNumber = 1

    if CategoryType not in [11]:
        SearchQuery = UserAsset.query.filter_by( userid = userid ).outerjoin( Asset, Asset.id == UserAsset.assetid )
        SearchQuery = InventoryTypesDict[CategoryType](SearchQuery).order_by( UserAsset.updated.desc() ).paginate( page = PageNumber, per_page = 24, error_out = False )

        for UserAssetObj in SearchQuery.items:
            if UserAssetObj.asset.is_limited and not UserAssetObj.asset.is_for_sale:
                BestPriceResult : UserAsset = UserAsset.query.filter_by(assetid=UserAssetObj.assetid, is_for_sale=True).order_by(UserAsset.price.asc()).first()
                if BestPriceResult is not None:
                    UserAssetObj.best_price = str(BestPriceResult.price)
                else:
                    UserAssetObj.best_price = "--"
    elif CategoryType == 11:
        SearchQuery = UserBadge.query.filter_by( user_id = userid ).order_by( UserBadge.awarded_at.desc() ).paginate( page = PageNumber, per_page = 24, error_out = False )

    return render_template(
        "profiles/inventory.html",
        profile = UserObj,
        SearchQuery = SearchQuery,
        CategoryName = InventoryTypeToFriendlyName[CategoryType],
        CategoryIndex = CategoryType
    )