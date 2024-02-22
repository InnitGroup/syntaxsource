from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response
from app.extensions import db
from app.util import auth, friends, placeinfo, membership
from app.models.user import User
from app.models.asset import Asset
from app.models.place import Place
from app.models.previously_played import PreviouslyPlayed
from app.models.placeserver_players import PlaceServerPlayer
from app.models.linked_discord import LinkedDiscord
from app.models.user_email import UserEmail
from datetime import datetime
from app.routes.rate import GetAssetVotePercentage

home = Blueprint("home", __name__, template_folder="pages")

def InsertRecentlyPlayed( UserObj : User, PlaceId : int ):
    """
        Updates the recently played table for the user
    """
    # Check if the user has played this place before
    PreviouslyPlayedObj : PreviouslyPlayed = PreviouslyPlayed.query.filter_by(userid=UserObj.id, placeid=PlaceId).first()
    if PreviouslyPlayedObj is None:
        # User has not played this place before
        PreviouslyPlayedObj = PreviouslyPlayed(UserObj.id, PlaceId)
        db.session.add(PreviouslyPlayedObj)
        db.session.commit()

        # If the user has more than 25 recently played places, remove the oldest one
        PreviouslyPlayedObjs : list[PreviouslyPlayed] = PreviouslyPlayed.query.filter_by(userid=UserObj.id).all()
        if len(PreviouslyPlayedObjs) > 25:
            PreviouslyPlayedObjs.sort(key=lambda x: x.lastplayed)
            db.session.delete(PreviouslyPlayedObjs[0])
            db.session.commit()

        return
    # User has played this place before, update the lastplayed timestamp
    PreviouslyPlayedObj.lastplayed = datetime.utcnow()
    db.session.commit()

@home.route("/home", methods=["GET"])
@auth.authenticated_required
def home_page():
    Authuser : User = auth.GetCurrentUser()
    Friends = friends.GetFriends(Authuser.id)
    FriendCount = len(Friends)
    FriendsData = []
    for friend in Friends:
        # Get the friend's thumbnail
        friendObjData = {
            "id": friend.id,
            "username": friend.username,
            "isonline": True if (datetime.utcnow() - friend.lastonline).total_seconds() < 60 else False,
            "ingame": True if PlaceServerPlayer.query.filter_by(userid=friend.id).first() is not None else False
        }
        FriendsData.append(friendObjData)
    # Sort the friends by online status
    FriendsData.sort(key=lambda x: x["isonline"], reverse=True)
    # Sort the friends by ingame status
    FriendsData.sort(key=lambda x: x["ingame"], reverse=True)
    # Limit the friends to 12
    FriendsData = FriendsData[:12]

    RecentlyPlayedData = []
    RecentlyPlayedObjs : list[PreviouslyPlayed] = PreviouslyPlayed.query.filter_by(userid=Authuser.id).order_by(PreviouslyPlayed.lastplayed.desc()).limit(12).all()
    for RecentlyPlayedObj in RecentlyPlayedObjs:
        PlaceAssetObj : Asset = Asset.query.filter_by(id=RecentlyPlayedObj.placeid).first()
        if PlaceAssetObj is None:
            continue
        PlaceObj : Place = Place.query.filter_by(placeid=PlaceAssetObj.id).first()
        if PlaceObj is None:
            continue
        RecentlyPlayedData.append({
            "id": PlaceObj.placeid,
            "name": PlaceAssetObj.name,
            "playercount": placeinfo.GetPlayingCount(PlaceObj),
            "likePercentage": GetAssetVotePercentage(PlaceObj.placeid),
            "placeyear": PlaceObj.placeyear
        })
    membershipValue : int = membership.GetUserMembership(Authuser).value
    isDiscordLinked : bool = LinkedDiscord.query.filter_by(user_id=Authuser.id).first() is not None
    isEmailVerified : bool = UserEmail.query.filter_by(user_id=Authuser.id).first() is not None

    return render_template(
        "home/home.html", 
        friends=FriendsData, 
        friendcount=FriendCount, 
        recentlyplayed=RecentlyPlayedData, 
        recentlyplayedcount=len(RecentlyPlayedData), 
        membershipValue=membershipValue,
        isDiscordLinked=isDiscordLinked,
        isEmailVerified=isEmailVerified
    )