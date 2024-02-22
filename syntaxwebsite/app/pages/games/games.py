from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, abort, flash
from app.util import auth, placeinfo
from app.models.asset import Asset
from app.models.placeservers import PlaceServer
from app.models.placeserver_players import PlaceServerPlayer
from app.models.gameservers import GameServer
from app.models.place import Place
from app.models.gamepass_link import GamepassLink
from app.models.userassets import UserAsset
from app.models.groups import Group, GroupRole, GroupRolePermission
from app.models.place_badge import PlaceBadge, UserBadge
from app.models.universe import Universe
from slugify import slugify
from app.pages.develop.develop import ShutdownServer
from app.enums.AssetType import AssetType
from app.models.user import User
from app.util.membership import GetUserMembership
from app.enums.MembershipType import MembershipType
from app.routes.rate import GetAssetLikesAndDislikes, GetUserVoteStatus, GetAssetVotePercentage, GetAssetFavoriteCount, GetUserFavoriteStatus
from app.routes.badgesapi import CalculateBadgeRarity, GetBadgeAwardedPastDay
from app.services import groups
from sqlalchemy import and_, func
from datetime import datetime, timedelta
import logging

GamePagesRoute = Blueprint("games", __name__, template_folder="pages")

def DoesUserownGamepass( gamepass_id, userid ):
    GamepassObj : Asset = Asset.query.filter_by(id=gamepass_id, asset_type = AssetType.GamePass).first()
    if GamepassObj is None:
        return False
    UserGamepass : UserAsset = UserAsset.query.filter_by(userid=userid, assetid=GamepassObj.id).first()
    if UserGamepass is None:
        return False
    return True
def DoesUserOwnBadge( badge_id, userid ):
    BadgeObj : PlaceBadge = PlaceBadge.query.filter_by(id=badge_id).first()
    if BadgeObj is None:
        return False
    UserBadgeObj : UserBadge = UserBadge.query.filter_by(badge_id=badge_id, user_id=userid).first()
    if UserBadgeObj is None:
        return False
    return True

def GetTotalBadgeAwardedCount( badge_id ) -> int:
    return UserBadge.query.filter_by( badge_id = badge_id ).count()

@GamePagesRoute.route("/games/<int:placeid>/", methods=["GET"])
@GamePagesRoute.route("/games/<int:placeid>/<string:slug>", methods=["GET"])
@auth.authenticated_required
def game_page(placeid : int, slug=None):
    AssetObject : Asset = Asset.query.filter_by(id=placeid).first()
    if AssetObject is None:
        return abort(404)
    if AssetObject.asset_type != AssetType.Place:
        # Let catalog handle the redirect
        return redirect(f"/catalog/{str(placeid)}/")
    SlugName = slugify(AssetObject.name, lowercase=False)
    if SlugName is None or SlugName == "":
        SlugName = "unnamed"
    if slug is None:
        return redirect(f"/games/{str(placeid)}/{SlugName}")
    if slug != SlugName:
        return redirect(f"/games/{str(placeid)}/{SlugName}")
    if AssetObject.creator_type == 0:
        CreatorObject : User = User.query.filter_by(id=AssetObject.creator_id).first()
    else:
        CreatorObject : Group = Group.query.filter_by(id=AssetObject.creator_id).first()
    PlaceObj : Place = Place.query.filter_by(placeid=placeid).first()
    if PlaceObj is None:
        return abort(404)
    UniverseObj : Universe = Universe.query.filter_by(id=PlaceObj.parent_universe_id).first()
    ActualRootPlace : Asset = Asset.query.filter_by(id=UniverseObj.root_place_id).first()
    
    try:
        SplittedDescription = AssetObject.description.split("\n")
        LikeCount, DislikeCount = GetAssetLikesAndDislikes(AssetObject.id)
        AuthenticatedUser : User = auth.GetCurrentUser()

        PlaceServerObjs : list[PlaceServer] = PlaceServer.query.filter_by(serverPlaceId=placeid).all()
        ActiveServers = []
        for PlaceServerObj in PlaceServerObjs:
            PlayersInServer : list[PlaceServerPlayer] = PlaceServerPlayer.query.filter_by(serveruuid=PlaceServerObj.serveruuid).all()
            GameServerObj : GameServer = GameServer.query.filter_by(serverId=PlaceServerObj.originServerId).first()
            if GameServerObj is None:
                continue
            ActiveServers.append({
                "id": PlaceServerObj.serveruuid,
                "playercount": PlaceServerObj.playerCount,
                "maxplayercount": PlaceServerObj.maxPlayerCount,
                "players": PlayersInServer,
                "host": GameServerObj.serverName,
                "is_reserved_server": PlaceServerObj.reservedServerAccessCode is not None
            })

        Gamepasses : list[GamepassLink] = GamepassLink.query.filter_by(universe_id = PlaceObj.parent_universe_id).all()
        UserDoesNotHaveBC : bool = UniverseObj.bc_required and GetUserMembership(AuthenticatedUser) == MembershipType.NonBuildersClub
        CanShutdownServer = False if AuthenticatedUser.id != 1 else True
        if AssetObject.creator_type == 0:
            if AuthenticatedUser.id == AssetObject.creator_id:
                CanShutdownServer = True
        else:
            GroupObj : Group = groups.GetGroupFromId( AssetObject.creator_id )
            UserGroupRole : GroupRole = groups.GetUserRolesetInGroup( AuthenticatedUser, GroupObj )
            if UserGroupRole is None:
                CanShutdownServer = False
            UserGroupRolePermission : GroupRolePermission = groups.GetRolesetPermission( UserGroupRole )
            if UserGroupRolePermission.manage_group_games:
                CanShutdownServer = True    
        
        GameBadges : list[PlaceBadge] = PlaceBadge.query.filter_by( universe_id = PlaceObj.parent_universe_id ).all()

        return render_template("games/view.html", PlaceAssetObj=AssetObject, 
                                CreatorObj=CreatorObject, 
                                PlaceObj=PlaceObj, 
                                SplittedDescription=SplittedDescription, 
                                PlayerCount=placeinfo.GetPlayingCount(PlaceObj), 
                                LikeCount=LikeCount, 
                                DislikeCount=DislikeCount, 
                                UserVoteStatus=GetUserVoteStatus(AssetObject.id, AuthenticatedUser.id),
                                UserFavoriteStatus=GetUserFavoriteStatus(AssetObject.id, AuthenticatedUser.id),
                                FavoriteCount=GetAssetFavoriteCount(AssetObject.id),
                                ActiveServers=ActiveServers,
                                ActiveServerCount=len(ActiveServers),
                                Gamepasses=Gamepasses,
                                DoesUserownGamepass=DoesUserownGamepass,
                                UserDoesNotHaveBC=UserDoesNotHaveBC,
                                IsTooYoung = (datetime.utcnow() - AuthenticatedUser.created).days < UniverseObj.minimum_account_age,
                                MinAccountAge = UniverseObj.minimum_account_age,
                                CanShutdownServer = CanShutdownServer,
                                GameBadges = GameBadges,
                                CalculateBadgeRarity = CalculateBadgeRarity,
                                DoesUserOwnBadge = DoesUserOwnBadge,
                                GetTotalBadgeAwardedCount = GetTotalBadgeAwardedCount,
                                GetBadgeAwardedPastDay = GetBadgeAwardedPastDay,
                                UniverseObj = UniverseObj,
                                UniverseRootPlace = ActualRootPlace
        )

    except Exception as e:
        logging.error(f"Error during rendering game page [{placeid}]: {str(e)}")
        return redirect(f"/games/{str(placeid)}/{SlugName}")

@GamePagesRoute.route("/games/<int:placeid>/shutdown-server/<jobid>", methods=["POST"])
@auth.authenticated_required
def game_shutdown_server(placeid : int, jobid : str):
    AuthenticatedUser : User = auth.GetCurrentUser()
    AssetObject : Asset = Asset.query.filter_by(id=placeid).first()
    if AssetObject is None:
        return abort(404)
    if AssetObject.asset_type != AssetType.Place:
        return abort(404)
    TargetPlaceServer : PlaceServer = PlaceServer.query.filter_by(serveruuid=jobid).first()
    if TargetPlaceServer is None:
        return abort(404)
    if (AssetObject.creator_id != AuthenticatedUser.id and AssetObject.creator_type != 1) and AuthenticatedUser.id != 1:
        return abort(403)
    if AssetObject.creator_type == 1:
        GroupObj : Group = groups.GetGroupFromId( AssetObject.creator_id )
        UserGroupRole : GroupRole = groups.GetUserRolesetInGroup( AuthenticatedUser, GroupObj )
        if UserGroupRole is None:
            return abort(403)
        UserGroupRolePermission : GroupRolePermission = groups.GetRolesetPermission( UserGroupRole )
        if not UserGroupRolePermission.manage_group_games:
            return abort(403)
    ShutdownServer(TargetPlaceServer.serveruuid)
    flash("Requested server shutdown", "success")
    return redirect(f"/games/{str(placeid)}/")

@GamePagesRoute.route("/games", methods=["GET"])
@auth.authenticated_required
def games_page():
    TopPlacesInfo = []
    PageNumber = max( request.args.get('page', default = 1, type = int ), 1 )
    SearchQuery = request.args.get('q', default = None, type = str)
    GameLookupResultsBackendResult = None
    GameLookupResults = []
    if SearchQuery:
        SearchQuery = SearchQuery.strip().replace('%', '')
        if len(SearchQuery) > 0 and len(SearchQuery) <= 32:
            GameLookupResultsBackendResult = Universe.query.filter( and_( Universe.is_public == True, Universe.moderation_status == 0) ).outerjoin( Place, Place.parent_universe_id == Universe.id ).join( Asset, Asset.id == Place.placeid ).filter( Asset.name.ilike(f"%{SearchQuery}%") ).filter_by( moderation_status = 0 ).order_by( Universe.visit_count.desc() ).paginate(page=PageNumber, per_page=36, error_out=False)
        else:
            flash('Invalid search query.', 'danger')

    if GameLookupResultsBackendResult:
        for UniverseObj in GameLookupResultsBackendResult:
            UniverseObj : Universe
            AssetObj : Asset = Asset.query.filter_by(id=UniverseObj.root_place_id).first()
            if AssetObj is None:
                continue
    
            PlaceObjData = {
                "id": UniverseObj.root_place_id,
                "name": AssetObj.name,
                "playingcount": placeinfo.GetUniversePlayingCount(UniverseObj),
                "slug": slugify(AssetObj.name, lowercase=False) if AssetObj.name is not None else "",
                "likePercentage": GetAssetVotePercentage(AssetObj.id),
                "placeyear": UniverseObj.place_year
            }
            GameLookupResults.append(PlaceObjData)

    PopularGames = Universe.query.filter( and_( Universe.is_public == True, Universe.moderation_status == 0) ).outerjoin( Place, Place.parent_universe_id == Universe.id ).join( Asset, Asset.id == Place.placeid ).filter_by( moderation_status = 0 ).outerjoin( PlaceServer, PlaceServer.serverPlaceId == Place.placeid ).group_by( Universe.id )
    PopularGames = PopularGames.order_by( func.coalesce( func.sum( PlaceServer.playerCount ), 0 ).desc() ).order_by( Universe.visit_count.desc() )

    UniverseObjsList = PopularGames.limit(24).all()
    for UniverseObj in UniverseObjsList:
        UniverseObj : Universe
        AssetObj : Asset = Asset.query.filter_by(id=UniverseObj.root_place_id).first()
        if AssetObj is None:
            continue
        PlaceObjData = {
            "id": UniverseObj.root_place_id,
            "name": AssetObj.name,
            "playingcount": placeinfo.GetUniversePlayingCount( UniverseObj ),
            "slug": slugify(AssetObj.name, lowercase=False) if AssetObj.name is not None else "",
            "likePercentage": GetAssetVotePercentage(UniverseObj.root_place_id),
            "placeyear": UniverseObj.place_year
        }
        TopPlacesInfo.append(PlaceObjData)
    
    RecentlyUpdatedUniverses : list[Universe] = Universe.query.filter( and_( Universe.is_public == True, Universe.moderation_status == 0) ).join( Asset, Asset.id == Universe.root_place_id ).filter_by( moderation_status = 0 ).order_by(Universe.updated_at.desc()).limit(24).all()
    RecentlyUpdatedUniversesInfo = []
    for UniverseObj in RecentlyUpdatedUniverses:
        PlaceObj : Place = Place.query.filter_by(placeid=UniverseObj.root_place_id).first()
        if PlaceObj is None:
            continue
        AssetObj : Asset = Asset.query.filter_by(id=PlaceObj.placeid).first()
        if len(RecentlyUpdatedUniversesInfo) >= 24:
            break
        PlaceObjData = {
            "id": AssetObj.id,
            "name": AssetObj.name,
            "playingcount": placeinfo.GetUniversePlayingCount( UniverseObj ),
            "slug": slugify(AssetObj.name, lowercase=False) if AssetObj.name is not None else "",
            "likePercentage": GetAssetVotePercentage(AssetObj.id),
            "placeyear": UniverseObj.place_year
        }
        RecentlyUpdatedUniversesInfo.append(PlaceObjData)
    
    FeaturedGames = Universe.query.filter( and_( Universe.is_public == True, Universe.moderation_status == 0, Universe.is_featured == True ) ).outerjoin( Place, Place.parent_universe_id == Universe.id ).join( Asset, Asset.id == Place.placeid ).filter_by( moderation_status = 0 ).outerjoin( PlaceServer, PlaceServer.serverPlaceId == Place.placeid ).group_by( Universe.id )
    FeaturedGames = FeaturedGames.order_by( func.coalesce( func.sum( PlaceServer.playerCount ), 0 ).desc() ).order_by( Universe.visit_count.desc() )
    FeaturedPlaceObjs = FeaturedGames.limit(24).all()
    FeaturedPlacesInfo = []
    for UniverseObj in FeaturedPlaceObjs:
        UniverseObj : Universe
        AssetObj : Asset = Asset.query.filter_by(id=UniverseObj.root_place_id).first()
        if AssetObj is None:
            continue
        PlaceObjData = {
            "id": UniverseObj.root_place_id,
            "name": AssetObj.name,
            "playingcount": placeinfo.GetUniversePlayingCount( UniverseObj ),
            "slug": slugify(AssetObj.name, lowercase=False) if AssetObj.name is not None else "",
            "likePercentage": GetAssetVotePercentage(AssetObj.id),
            "placeyear": UniverseObj.place_year
        }
        FeaturedPlacesInfo.append(PlaceObjData)

    return render_template("games/index.html", PopularPlaces=TopPlacesInfo, RecentlyUpdatedPlaces=RecentlyUpdatedUniversesInfo, FeaturedPlacesInfo=FeaturedPlacesInfo, GameLookupResults = GameLookupResults, PageNumber=PageNumber, SearchQuery = SearchQuery, GameLookupResultsBackendResult = GameLookupResultsBackendResult)

from sqlalchemy import func
@GamePagesRoute.route("/games/<genre>/view", methods=["GET"])
@auth.authenticated_required
def games_genre_page(genre : str):
    pageNumber = max( request.args.get("page", default=1, type=int), 1 )
    if genre == "popular":
        PopularGames = Universe.query.filter( and_( Universe.is_public == True, Universe.moderation_status == 0) ).outerjoin( Place, Place.parent_universe_id == Universe.id ).join(Asset, Asset.id == Place.placeid).outerjoin(PlaceServer, PlaceServer.serverPlaceId == Place.placeid).group_by(Universe.id)
        PopularGames = PopularGames.filter( Asset.moderation_status == 0).order_by(func.coalesce(func.sum(PlaceServer.playerCount), 0).desc()).order_by( Universe.visit_count.desc() )
        PopularGames = PopularGames.paginate(page=pageNumber, per_page=30, error_out=False)
        ViewerFacingGenre = "Popular Games"
        pageResults = PopularGames
    elif genre == "updated":
        UpdatedGames = Universe.query.filter( and_( Universe.is_public == True, Universe.moderation_status == 0) ).join( Asset, Asset.id == Universe.root_place_id ).filter( Asset.moderation_status == 0 ).order_by(Universe.updated_at.desc())
        UpdatedGames = UpdatedGames.paginate(page=pageNumber, per_page=30, error_out=False)
        ViewerFacingGenre = "Recently Updated"
        pageResults = UpdatedGames
    elif genre == "featured":
        FeaturedGames = Universe.query.filter( and_( Universe.is_public == True, Universe.moderation_status == 0, Universe.is_featured == True ) ).outerjoin( Place, Place.parent_universe_id == Universe.id ).join(Asset, Asset.id == Place.placeid).outerjoin(PlaceServer, PlaceServer.serverPlaceId == Place.placeid).group_by(Universe.id)
        FeaturedGames = FeaturedGames.filter( Asset.moderation_status == 0).order_by(func.coalesce(func.sum(PlaceServer.playerCount), 0).desc()).order_by( Universe.visit_count.desc() )
        FeaturedGames = FeaturedGames.paginate(page=pageNumber, per_page=30, error_out=False)
        ViewerFacingGenre = "Featured Games"
        pageResults = FeaturedGames
    else:
        return abort(404)
    
    if pageResults is None:
        return abort(404)
    
    def getRootPlace( UniverseObj : Universe ) -> Place :
        try:
            return UniverseObj.root_place_obj
        except:
            UniverseObj.root_place_obj = Place.query.filter_by(placeid=UniverseObj.root_place_id).first()
            return UniverseObj.root_place_obj
    
    return render_template("games/genre.html", Games=pageResults, Genre=genre, getPlayerCount = placeinfo.GetUniversePlayingCount, getAssetVotePercentage = GetAssetVotePercentage, ViewerFacingGenre=ViewerFacingGenre, getRootPlace=getRootPlace)