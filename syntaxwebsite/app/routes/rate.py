from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, abort
from app.models.asset_votes import AssetVote
from app.models.asset_favorite import AssetFavorite
from app.models.asset import Asset
from app.enums.AssetType import AssetType
from app.models.user import User
from app.models.userassets import UserAsset
from app.models.previously_played import PreviouslyPlayed
from app.extensions import limiter, db, redis_controller
from app.util import auth
import json

AssetRateRoute = Blueprint("assetrate", __name__, template_folder="pages")

def ClearAssetVotesCache( assetId : int ):
    redis_controller.delete(f"asset:{str(assetId)}:votes")

def GetAssetLikesAndDislikes( assetId : int ) -> tuple[int, int]:
    """
        Returns 2 int values the first being the likes count and the second being the dislikes count.
    """
    # See if we have the likes and dislikes in redis
    CachedVoteData = redis_controller.get(f"asset:{str(assetId)}:votes")
    if CachedVoteData is not None:
        CachedVoteData = json.loads(CachedVoteData)
        return CachedVoteData["likes"], CachedVoteData["dislikes"]

    LikesCount = AssetVote.query.filter_by(assetid=assetId, vote=True).count()
    DislikesCount = AssetVote.query.filter_by(assetid=assetId, vote=False).count()
    redis_controller.set(f"asset:{str(assetId)}:votes", json.dumps({"likes":LikesCount, "dislikes":DislikesCount}), ex=600)

    return LikesCount, DislikesCount

def GetUserVoteStatus( assetId : int, userId : int ) -> int: # 2 = dislike, 0 = no vote, 1 = like
    """
        Returns an int value which is 2 if the user disliked the asset, 0 if the user didn't vote and 1 if the user liked the asset.
    """
    UserVoteObj : AssetVote = AssetVote.query.filter_by(assetid=assetId, userid=userId).first()
    if UserVoteObj is None:
        return 0
    if UserVoteObj.vote == True:
        return 1
    return 2

def GetAssetVotePercentage( assetId : int ) -> int:
    """
        Returns an int value which is the percentage of likes the asset has.
    """
    LikesCount, DislikesCount = GetAssetLikesAndDislikes(assetId)
    if LikesCount == 0 and DislikesCount == 0:
        return 50
    return int((LikesCount / (LikesCount + DislikesCount)) * 100)

@AssetRateRoute.route("/vote/<int:assetid>/<int:status>", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("5/minute")
def vote_asset(assetid : int, status : int):
    if status > 2 or status < 0:
        return abort(400)
    AuthenticatedUser = auth.GetCurrentUser()
    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        return abort(404)
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AssetObj.asset_type == AssetType.Place:
        if PreviouslyPlayed.query.filter_by(userid=AuthenticatedUser.id, placeid=AssetObj.id).first() is None:
            return abort(400)
    elif AssetObj.asset_type in [AssetType.GamePass, AssetType.Shirt, AssetType.TShirt, AssetType.Pants, AssetType.Hat, AssetType.Gear, AssetType.Plugin, AssetType.HairAccessory, AssetType.FaceAccessory, AssetType.NeckAccessory, AssetType.ShoulderAccessory, AssetType.FrontAccessory, AssetType.BackAccessory, AssetType.WaistAccessory, AssetType.EarAccessory, AssetType.EyeAccessory, AssetType.TShirtAccessory, AssetType.ShirtAccessory, AssetType.PantsAccessory, AssetType.JacketAccessory, AssetType.Package]:
        if UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=AssetObj.id).first() is None:
            return abort(400)

    AssetVoteObj : AssetVote = AssetVote.query.filter_by(assetid=assetid, userid=AuthenticatedUser.id).first()
    if AssetVoteObj is None and status != 0:
        AssetVoteObj = AssetVote(assetid=assetid, userid=AuthenticatedUser.id, vote=True)
        db.session.add(AssetVoteObj)
    
    if AssetVoteObj is not None and status == 0:
        db.session.delete(AssetVoteObj)
    
    if AssetVoteObj is not None and status != 0:
        AssetVoteObj.vote = status == 1
    
    db.session.commit()
    ClearAssetVotesCache(assetid)
    LikesCount, DislikesCount = GetAssetLikesAndDislikes(assetid)

    return jsonify({"success":True}), 200

def GetAssetFavoriteCount( assetId : int ) -> int:
    """
        Returns an int value which is the amount of users who favorited the asset.
    """
    if redis_controller.exists(f"asset:{str(assetId)}:favorites"):
        return int(redis_controller.get(f"asset:{str(assetId)}:favorites"))
    favoriteCount = AssetFavorite.query.filter_by(assetid=assetId).count()
    redis_controller.set(f"asset:{str(assetId)}:favorites", str(favoriteCount))
    return favoriteCount

def GetUserFavoriteStatus( assetId : int, userId : int ) -> bool:
    """
        Returns a bool value which is True if the user favorited the asset and False if the user didn't favorite the asset.
    """
    UserFavoriteObj : AssetFavorite = AssetFavorite.query.filter_by(assetid=assetId, userid=userId).first()
    if UserFavoriteObj is None:
        return False
    return True

@AssetRateRoute.route("/favorite/<int:assetid>", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("5/minute")
def favorite_asset(assetid : int):
    AuthenticatedUser = auth.GetCurrentUser()
    AssetFavoriteObj : AssetFavorite = AssetFavorite.query.filter_by(assetid=assetid, userid=AuthenticatedUser.id).first()
    if AssetFavoriteObj is None:
        AssetFavoriteObj = AssetFavorite(assetid=assetid, userid=AuthenticatedUser.id)
        db.session.add(AssetFavoriteObj)
        db.session.commit()
    return jsonify({"success":True}), 200

@AssetRateRoute.route("/favorite/<int:assetid>", methods=["DELETE"])
@auth.authenticated_required_api
@limiter.limit("5/minute")
def unfavorite_asset(assetid : int):
    AuthenticatedUser = auth.GetCurrentUser()
    AssetFavoriteObj : AssetFavorite = AssetFavorite.query.filter_by(assetid=assetid, userid=AuthenticatedUser.id).first()
    if AssetFavoriteObj is not None:
        db.session.delete(AssetFavoriteObj)
        db.session.commit()
        redis_controller.delete(f"asset:{str(assetid)}:favorites")
    return jsonify({"success":True}), 200