from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, after_this_request, Response
from app.util import auth, websiteFeatures
from app.extensions import db, redis_controller, csrf, get_remote_address
import uuid
import requests
import time
from config import Config
import json
from datetime import datetime, timedelta
import random
import string
import logging
import base64
import hashlib

from app.models.user import User
from app.models.gameservers import GameServer
from app.models.placeservers import PlaceServer
from app.models.placeserver_players import PlaceServerPlayer
from app.models.place import Place
from app.models.asset import Asset
from app.models.login_records import LoginRecord
from app.models.user_hwid_log import UserHWIDLog
from app.models.universe import Universe
from app.models.asset_version import AssetVersion
from app.enums.AssetType import AssetType
from app.enums.MembershipType import MembershipType
from app.enums.PlaceYear import PlaceYear
from app.services.gameserver_comm import perform_post
from app.util.membership import GetUserMembership
from app.util.signscript import signUTF8
from app.util.assetversion import GetLatestAssetVersion
from app.routes.jobreporthandler import EvictPlayer
from app.routes.asset import GenerateTempAuthToken

config = Config()

class PlaceServerCooldownStart( Exception ):
    pass
class NoAvailableGameServers( Exception ):
    pass
class MissingData( Exception ):
    pass
class UnsupportedPlaceYear( Exception ):
    pass
class UnexpectedStatusCode( Exception ):
    pass
class BadResponseData( Exception ):
    pass
def CreateNewPlaceServer( placeId : int, reserved_server_access_code : str = None ) -> PlaceServer:
    """
        Starts a new PlaceServer for the given placeId, raises appropriate exceptions if it fails

        :param placeId: The placeId to start a new PlaceServer for
        :reserved_server_access_code: The reserved server access code to use, if None it will be a public server

        :return: PlaceServer object if successful
    """
    CooldownKeyName : str = f"create_new_place_server:{placeId}:{reserved_server_access_code}"
    if redis_controller.get(CooldownKeyName) is not None:
        logging.debug(f"CreateNewPlaceServer -> Place {placeId} recently requested to create a new place server, skipping")
        raise PlaceServerCooldownStart("")
    redis_controller.setex(CooldownKeyName, 40, "1")

    SelectedGameServerObj : GameServer = GameServer.query.filter_by(
        allowGameServerHost = True
    ).filter(
        GameServer.lastHeartbeat > datetime.utcnow() - timedelta(seconds=30)
    ).order_by(
        GameServer.RCCmemoryUsage.asc()
    ).first()

    if SelectedGameServerObj is None:
        logging.error(f"CreateNewPlaceServer -> Failed to find a available Gameserver to host Place {placeId}")
        raise NoAvailableGameServers("")
    
    PlaceObj : Place = Place.query.filter_by( placeid = placeId ).first()
    AssetObj : Asset = Asset.query.filter_by( id = placeId ).first()
    
    if PlaceObj is None or AssetObj is None:
        logging.error(f"CreateNewPlaceServer -> Failed to find Place / Asset {placeId} in database")
        raise MissingData("")
    
    UniverseObj : Universe = Universe.query.filter_by( id = PlaceObj.parent_universe_id ).first()
    if UniverseObj is None:
        logging.error(f"CreateNewPlaceServer -> Failed to find Universe {PlaceObj.parent_universe_id} in database for Place {placeId}")
        raise MissingData("")
    
    logging.info(f"CreateNewPlaceServer -> Attempting to start new place server for Place {PlaceObj.placeid}, Universe {UniverseObj.id} on Gameserver {SelectedGameServerObj.serverName} ({SelectedGameServerObj.serverId}), reserved_server_access_code: {reserved_server_access_code}")

    RequestSession = requests.Session()
    RequestSession.headers.update({
        "Authorization": SelectedGameServerObj.accessKey
    })

    JSONOpenPayload = {}
    GameOpenRoute = "Game"
    JobId : str = str( uuid.uuid4() )
    CommApiKey : str = str( uuid.uuid4() )

    LatestPlaceVersion : AssetVersion = GetLatestAssetVersion( AssetObj )

    if UniverseObj.place_year == PlaceYear.Sixteen:
        TempPlaceAuthorizationToken : str = GenerateTempAuthToken( placeId, Expiration = 200, CreatorIP = None )
        JSONOpenPayload = {
            "placeid": placeId,
            "creatorId": AssetObj.creator_id,
            "creatorType": AssetObj.creator_type,
            "SpecialAccessToken": TempPlaceAuthorizationToken,
            "useNewLoadFile": False,
            "loadfile_location": f"{config.BaseURL}/game/gameserver2016.lua",
            "universeid": UniverseObj.id,
            "place_version": LatestPlaceVersion.version
        }
    elif UniverseObj.place_year == PlaceYear.Eighteen:
        GameOpenRoute = "Game2018"
        JSONOpenPayload = {
            "placeid": placeId,
            "creatorId": AssetObj.creator_id,
            "creatorType": "User" if AssetObj.creator_type == 0 else "Group",
            "jobid": JobId,
            "apikey": CommApiKey,
            "maxplayers": PlaceObj.maxplayers,
            "address": SelectedGameServerObj.serverIP,
            "universeid": UniverseObj.id,
            "place_version": LatestPlaceVersion.version
        }
    elif UniverseObj.place_year == PlaceYear.Twenty:
        GameOpenRoute = "Game2020"
        JSONOpenPayload = {
            "placeid": placeId,
            "creatorId": AssetObj.creator_id,
            "creatorType": "User" if AssetObj.creator_type == 0 else "Group",
            "jobid": JobId,
            "apikey": CommApiKey,
            "maxplayers": PlaceObj.maxplayers,
            "address": SelectedGameServerObj.serverIP,
            "universeid": UniverseObj.id,
            "place_version": LatestPlaceVersion.version
        }
    elif UniverseObj.place_year == PlaceYear.Fourteen:
        GameOpenRoute = "Game2014"
        JSONOpenPayload = {
            "placeid": placeId,
            "creatorId": AssetObj.creator_id,
            "creatorType": AssetObj.creator_type,
            "universeid": UniverseObj.id,
            "place_version": LatestPlaceVersion.version
        }
    elif UniverseObj.place_year == PlaceYear.TwentyOne:
        GameOpenRoute = "Game2021"
        JSONOpenPayload = {
            "placeid": placeId,
            "creatorId": AssetObj.creator_id,
            "creatorType": "User" if AssetObj.creator_type == 0 else "Group",
            "jobid": JobId,
            "apikey": CommApiKey,
            "maxplayers": PlaceObj.maxplayers,
            "address": SelectedGameServerObj.serverIP,
            "universeid": UniverseObj.id,
            "place_version": LatestPlaceVersion.version
        }
    else:
        logging.error(f"CreateNewPlaceServer -> Failed to start new place server for Place {placeId}, unsupported place year got {UniverseObj.place_year.name}")
        raise UnsupportedPlaceYear(f"Year {UniverseObj.place_year.name} is not supported")
    
    if UniverseObj.place_year in [ PlaceYear.Eighteen, PlaceYear.Twenty, PlaceYear.TwentyOne ]:
        redis_controller.set(f"GameServerAccessKey:{CommApiKey}:{JobId}", "1", ex=60*60*24*2)
    if UniverseObj.place_year in [ PlaceYear.Fourteen ]:
        redis_controller.set(f"gameserver2014lua:{PlaceObj.placeid}:{JobId}", "1", ex=120)

    try:
        OpenJobReq = perform_post(
            TargetGameserver = SelectedGameServerObj,
            Endpoint = GameOpenRoute,
            JSONData = JSONOpenPayload,
            RequestTimeout = 35
        )
    except requests.exceptions.Timeout:
        logging.error(f"CreateNewPlaceServer -> Failed to start new place server for Place {placeId} on Gameserver {SelectedGameServerObj.serverName} ({SelectedGameServerObj.serverId}), open request timed out")
        raise NoAvailableGameServers(f"Request timed out")
    
    if OpenJobReq.status_code != 200:
        logging.error(f"CreateNewPlaceServer -> Failed to start new place server for Place {placeId} on Gameserver {SelectedGameServerObj.serverName} ({SelectedGameServerObj.serverId}), response: {OpenJobReq.content}")
        raise UnexpectedStatusCode(f"Got status code {OpenJobReq.status_code} from Gameserver")
    
    OpenJobReqJSON = OpenJobReq.json()
    if "jobid" not in OpenJobReqJSON or "port" not in OpenJobReqJSON:
        logging.error(f"CreateNewPlaceServer -> Failed to start new place server for Place {placeId} on Gameserver {SelectedGameServerObj.serverName} ({SelectedGameServerObj.serverId}), missing 'port' or 'jobid' in JSON,response: {OpenJobReqJSON}")
        raise BadResponseData(f"Missing 'port' or 'jobid' in JSON response")
    redis_controller.set(f"place:{OpenJobReqJSON['jobid']}:origin", str(SelectedGameServerObj.serverId), ex=60*60*24*2)
    PlaceServerObject = PlaceServer(
        serveruuid = OpenJobReqJSON["jobid"],
        originServerId = SelectedGameServerObj.serverId,
        serverIP = SelectedGameServerObj.serverIP,
        serverPort = OpenJobReqJSON["port"],
        serverPlaceId = placeId,
        maxPlayerCount = PlaceObj.maxplayers,
        reservedServerAccessCode = reserved_server_access_code
    )

    db.session.add(PlaceServerObject)
    db.session.commit()
    logging.info(f"CreateNewPlaceServer -> Started new place server for Place {placeId}, Universe {UniverseObj.id} on Gameserver {SelectedGameServerObj.serverName} ({SelectedGameServerObj.serverId}), is_reserved: {reserved_server_access_code is not None}")

    return PlaceServerObject

def GetSuitablePlaceServer( placeId : int ) -> PlaceServer | bool:
    """
        Returns a suitable PlaceServer for the given placeId

        :param placeId: The placeId to find a suitable PlaceServer for

        :return: PlaceServer object if successful, returns False if no PlaceServer is found
    """
    PlaceObj : Place = Place.query.filter_by( placeid = placeId ).first()
    if PlaceObj is None:
        logging.error(f"GetSuitablePlaceServer -> Failed to find Place {placeId} in database")
        raise MissingData("")
    
    HasFoundSuitablePlaceServer : bool = False

    PlaceServers = PlaceServer.query.filter_by( serverPlaceId = placeId, reservedServerAccessCode = None ).all()
    if PlaceServers is None or ( type(PlaceServers) == list and len(PlaceServers) == 0 ):
        HasFoundSuitablePlaceServer = False
    
    if not HasFoundSuitablePlaceServer:
        for PlaceServerObject in PlaceServers:
            PlaceServerObject : PlaceServer
            if PlaceServerObject.maxPlayerCount <= PlaceServerObject.playerCount:
                continue
            if PlaceServerObject.serverRunningTime == 0:
                continue
            return PlaceServerObject

    if HasFoundSuitablePlaceServer is False:
        logging.info(f"GetSuitablePlaceServer -> Place {placeId} has no PlaceServers, attempting to start one")
        try:
            NewPlaceServerObj = CreateNewPlaceServer( placeId = placeId, reserved_server_access_code = None )
        except:
            return False
        
        return False

GameJoinRoute = Blueprint('gamejoin', __name__, url_prefix='/')

@GameJoinRoute.route('/universes/validate-place-join', methods=['GET'])
def validateplacejoin():
    return "true"

@GameJoinRoute.route('/Game/Join2012.ashx', methods=['GET'])
def Join2012():
    SignedFirstTicketRaw : str = signUTF8("print('hello')", formatAutomatically=True, addNewLine=True, twelveclient=True)
    Resposne = make_response(SignedFirstTicketRaw)

    return Resposne

@GameJoinRoute.route('/game/validate-machine', methods=['POST'])
@csrf.exempt
def validate_machine():
    try:
        if request.cookies.get("t") is None:
            raise Exception("Request has no 't' cookie")
        
        macAddressesList = request.form.getlist('macAddresses')
        if len(macAddressesList) > 0:
            combinedAddress = ""
            for macAddress in macAddressesList:
                combinedAddress += macAddress
            UserHWIDHash = hashlib.sha256(combinedAddress.encode("utf-8")).hexdigest()
            tracking_cookie = request.cookies.get("t")
            redis_controller.setex(f"hwid:{str(tracking_cookie)}", 60, UserHWIDHash)
    except Exception as e:
        logging.error(f"Failed during /game/validate-machine: {e}")
    return jsonify({
        "success": True,
        "message": ""
    })

@GameJoinRoute.route('/Game/MachineConfiguration.ashx', methods=['POST', 'GET'])
@csrf.exempt
def machine_configuration():
    return ""

def ReturnPlaceLauncher( message : str, status : int, authenticated_userid : int = None) -> Response:
    response = make_response(
        jsonify({
            "jobId": None,
            "status": status,
            "joinScriptUrl": None,
            "authenticationUrl": config.BaseURL + "/Login/Negotiate.ashx",
            "authenticationTicket": None,
            "message": message,
            "rand": random.randint(0, 100000000000)
        })
    )

    if authenticated_userid is not None and request.cookies.get(".ROBLOSECURITY") is None:
        response.set_cookie( 
            key = ".ROBLOSECURITY",
            value = auth.CreateToken( userid = authenticated_userid, expireIn = 60 * 60 * 24 * 3, ip = get_remote_address() ),
            expires = datetime.utcnow() + timedelta(days=3),
            domain = f".{config.BaseDomain}"
        )
    response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    return response

@GameJoinRoute.route('/game/PlaceLauncher.ashx', methods=['GET', 'POST'])
@GameJoinRoute.route('/Game/PlaceLauncher.ashx', methods=['GET', 'POST'])
@GameJoinRoute.route('/game/placelauncher.ashx', methods=['GET', 'POST'])
@GameJoinRoute.route('/Game/placelauncher.ashx', methods=['GET', 'POST'])
@csrf.exempt
def placelauncher():
    if not websiteFeatures.GetWebsiteFeature("GameJoinAPI"):
        return ReturnPlaceLauncher("GameJoinAPI is disabled", 12)
    
    AuthenticatdUser = None
    placeid = request.args.get( key = 'placeId', default = None, type = int) or request.args.get( key = 'placeid', default = None, type = int)
    ticket = request.args.get( key = 't', default = None, type = str)
    if ticket is None:
        AuthenticatdUser : User | None = auth.GetCurrentUser()
        if AuthenticatdUser is None:
            return ReturnPlaceLauncher("Invalid request", 12)
    if placeid is None:
        return ReturnPlaceLauncher("Invalid request", 12)
    
    requestedJobId = request.args.get( key = 'jobId', default = None, type = str) or request.args.get( key = 'jobid', default = None, type = str)
    isTeleport = request.args.get( key = 'isTeleport', default = None, type = str ) == "true"
    requestType = request.args.get( key = 'request', default = "RequestGame", type = str )

    if request.user_agent != "Roblox/WinInet":
        isTeleport = False
    
    authticketInfo = redis_controller.get(f"authticket:{ticket}")
    if authticketInfo is None and AuthenticatdUser is None:
        return ReturnPlaceLauncher("Invalid authentication ticket", 12)
    
    #UserIPHash = hashlib.md5(get_remote_address().encode("utf-8")).hexdigest()
    #LoginRecords : list[LoginRecord] = LoginRecord.query.filter(LoginRecord.ip == UserIPHash).distinct(LoginRecord.userid).all()
    #for record in LoginRecords:
    #    if record.User.accountstatus != 1:
    #        return ReturnPlaceLauncher("Invalid authentication ticket", 12)

    userId = int(authticketInfo) if authticketInfo is not None else AuthenticatdUser.id
    if PlaceServerPlayer.query.filter_by(userid=userId).first() is not None and not isTeleport:
        CurrentPlaceServerPlayerObj : PlaceServerPlayer = PlaceServerPlayer.query.filter_by(userid=userId).first()
        CurrentPlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serveruuid=CurrentPlaceServerPlayerObj.serveruuid).first()
        try:
            EvictPlayer(CurrentPlaceServerObj, userId)
        except:
            return ReturnPlaceLauncher("Invalid request", 12)

    AssetObj : Asset = Asset.query.filter_by(id=placeid).first()
    if AssetObj is None:
        return ReturnPlaceLauncher("Invalid place", 14)
    if AssetObj.asset_type != AssetType.Place or AssetObj.moderation_status == 2:
        return ReturnPlaceLauncher("Invalid place", 14)
    PlaceObj : Place = Place.query.filter_by(placeid=placeid).first()
    if PlaceObj is None:
        return ReturnPlaceLauncher("Invalid place", 14)
    UniverseObj : Universe = Universe.query.filter_by(id=PlaceObj.parent_universe_id).first()
    if UniverseObj.is_public == False and userId != 1:
        return ReturnPlaceLauncher("Invalid place", 14)
    
    UserObj : User = User.query.filter_by(id=userId).first()

    if request.cookies.get("t") is not None:
        Tracking_Cookie = request.cookies.get("t")
        UserHWIDHash = redis_controller.get(f"hwid:{str(Tracking_Cookie)}")
        if UserHWIDHash is not None:
            UserHWIDLogObject = UserHWIDLog(
                user_id = UserObj.id,
                hwid = UserHWIDHash
            )
            db.session.add(UserHWIDLogObject)
            db.session.commit()

            redis_controller.delete(f"hwid:{str(Tracking_Cookie)}")

    UserMembershipStatus : MembershipType = GetUserMembership(UserObj)
    if UniverseObj.bc_required and UserMembershipStatus == MembershipType.NonBuildersClub:
        return ReturnPlaceLauncher("Builders Club required", 12)
    if UniverseObj.minimum_account_age > (datetime.utcnow() - UserObj.created).days:
        return ReturnPlaceLauncher("Account is too new to join this place", 12)

    if requestedJobId is not None:
        PlaceServerObj : PlaceServer = PlaceServer.query.filter_by( serveruuid = requestedJobId, serverPlaceId = placeid, reservedServerAccessCode = None ).first()
        if PlaceServerObj is None:
            return ReturnPlaceLauncher("Invalid request", 12)
        if PlaceServerObj.maxPlayerCount <= PlaceServerObj.playerCount:
            return ReturnPlaceLauncher("Server is full", 6, authenticated_userid=userId)
    elif requestType == "RequestPrivateGame":
        server_accessCode = request.args.get( key = 'accessCode', default = None, type = str)
        if server_accessCode is None:
            return ReturnPlaceLauncher("Invalid request", 12)
        PlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serverPlaceId = placeid, reservedServerAccessCode = server_accessCode ).first()
        if PlaceServerObj is None:
            return ReturnPlaceLauncher("Invalid request", 12)
        if redis_controller.exists(f"reservedserveraccesscode:{str(PlaceServerObj.serveruuid)}:{UserObj.id}") is False:
            return ReturnPlaceLauncher("Invalid request", 12)
        if PlaceServerObj.maxPlayerCount <= PlaceServerObj.playerCount:
            return ReturnPlaceLauncher("Server is full", 6, authenticated_userid=userId)
        
        redis_controller.delete(f"reservedserveraccesscode:{str(PlaceServerObj.serveruuid)}:{UserObj.id}")
    else:
        PlaceServerObj : PlaceServer | bool = GetSuitablePlaceServer( placeId = placeid )

    if PlaceServerObj is False:
        logging.info(f"Placelauncher.ashx : {str(placeid)} : {UserObj.username} [{UserObj.id}] : No available place servers found yet")
        return ReturnPlaceLauncher(None, 1, authenticated_userid=userId)
    redis_controller.delete(f"authticket:{ticket}")
    authenticatedTicketUUID = str(uuid.uuid4())
    redis_controller.setex(f"place:{placeid}:ticket:{authenticatedTicketUUID}", 60, json.dumps({"id": userId, "jobid": str(PlaceServerObj.serveruuid)}))

    authticket = ''.join(random.choices(string.ascii_uppercase + string.digits, k=256))
    redis_controller.set(f"authticket:{authticket}", userId, 60*10)
    resp = make_response(jsonify({
        "jobId": PlaceServerObj.serveruuid,
        "status": 2,
        "joinScriptUrl": config.BaseURL + "/Game/Join.ashx?placeId=" + str(placeid) + "&jobId=" + str(PlaceServerObj.serveruuid) + "&ticket=" + authenticatedTicketUUID,
        "authenticationUrl": config.BaseURL + "/Login/Negotiate.ashx",
        "authenticationTicket": authticket,
        "message": None,
        "rand": random.randint(0, 100000000000)
    }))
    resp.set_cookie("ticket", authenticatedTicketUUID)
    if request.cookies.get(".ROBLOSECURITY") is None:
        resp.set_cookie( 
            key = ".ROBLOSECURITY",
            value = auth.CreateToken( userid = userId, expireIn = 60 * 60 * 24 * 3, ip = get_remote_address() ),
            expires = datetime.utcnow() + timedelta(days=3),
            domain = f".{config.BaseDomain}"
        )
    return resp

@GameJoinRoute.route("/v1/join-game", methods=["POST"]) # Meant for 2020 Android
@csrf.exempt
@auth.authenticated_required_api
def gamejoin_api_v1():
    if not websiteFeatures.GetWebsiteFeature("GameJoinAPI"):
        return ReturnPlaceLauncher("GameJoinAPI is disabled", 12)
    if not request.is_json:
        return ReturnPlaceLauncher("Invalid request", 12)
    if "placeId" not in request.json:
        return ReturnPlaceLauncher("Invalid request", 12)
    try:
        requestedPlaceId : int = int(request.json["placeId"])
        isTeleport : bool = request.json["isTeleport"] if "isTeleport" in request.json else False
    except:
        return ReturnPlaceLauncher("Invalid request", 12)

    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None: # Shouldnt happen but just in case
        return ReturnPlaceLauncher("Invalid request", 12)
    
    userId = AuthenticatedUser.id
    if PlaceServerPlayer.query.filter_by(userid=userId).first() is not None and not isTeleport:
        CurrentPlaceServerPlayerObj : PlaceServerPlayer = PlaceServerPlayer.query.filter_by(userid=userId).first()
        CurrentPlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serveruuid=CurrentPlaceServerPlayerObj.serveruuid).first()
        try:
            EvictPlayer(CurrentPlaceServerObj, userId)
        except:
            logging.error(f"/v1/join-game - Failed to evict player {userId} from place {CurrentPlaceServerObj.serverPlaceId}")
            return ReturnPlaceLauncher("Invalid request", 12)
    
    AssetObj : Asset = Asset.query.filter_by(id=requestedPlaceId).first()
    if AssetObj is None:
        return ReturnPlaceLauncher("Invalid place", 14)
    if AssetObj.asset_type != AssetType.Place or AssetObj.moderation_status == 2:
        return ReturnPlaceLauncher("Invalid place", 14)
    PlaceObj : Place = Place.query.filter_by(placeid=requestedPlaceId).first()
    if PlaceObj is None:
        return ReturnPlaceLauncher("Invalid place", 14)
    UniverseObj : Universe = Universe.query.filter_by(id=PlaceObj.parent_universe_id).first()
    if UniverseObj.is_public == False and userId != 1:
        return ReturnPlaceLauncher("Invalid place", 14)
    
    UserMembershipStatus : MembershipType = GetUserMembership(AuthenticatedUser)
    if UniverseObj.bc_required and UserMembershipStatus == MembershipType.NonBuildersClub:
        return ReturnPlaceLauncher("Builders Club required", 12)
    if UniverseObj.minimum_account_age > (datetime.utcnow() - AuthenticatedUser.created).days:
        return ReturnPlaceLauncher("Account is too new to join this place", 12)
    
    PlaceServerObj : PlaceServer | bool = GetSuitablePlaceServer( placeId = requestedPlaceId )

    if PlaceServerObj is False:
        logging.info(f"/v1/join-game : {str(requestedPlaceId)} : {AuthenticatedUser.username} [{AuthenticatedUser.id}] : No available place servers found yet")
        return ReturnPlaceLauncher(None, 1, authenticated_userid=userId)
    
    ClientTicket = GenerateClientTicket(AuthenticatedUser, PlaceServerObj.serveruuid, TicketVersion = 4, PlaceId = requestedPlaceId)
    SessionId : str = f"{str(uuid.uuid4())}|{str(PlaceServerObj.serveruuid)}|0|{str(PlaceServerObj.serverIP)}|8|{datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.000Z')}|0|null|AAAAA"

    resp = make_response(jsonify({
        "jobId": PlaceServerObj.serveruuid,
        "status": 2,
        "authenticationUrl": config.BaseURL + "/Login/Negotiate.ashx",
        "authenticationTicket": "",
        "message": None,
        "rand": random.randint(0, 100000000000),
        "joinScript": {
            "ClientPort" : 0,
            "MachineAddress" : PlaceServerObj.serverIP,
            "ServerConnections": [
                {
                    "Port": PlaceServerObj.serverPort,
                    "Address": PlaceServerObj.serverIP
                }
            ],
            "ServerPort" : PlaceServerObj.serverPort,
            "PingUrl": "",
            "PingInterval": 120,
            "UserName": AuthenticatedUser.username,
            "DisplayName": AuthenticatedUser.username,
            "SeleniumTestMode": False,
            "UserId": AuthenticatedUser.id,
            "ClientTicket": ClientTicket,
            "SuperSafeChat": False,
            "PlaceId": PlaceServerObj.serverPlaceId,
            "MeasurementUrl": "",
            "WaitingForCharacterGuid": str(uuid.uuid4()),
            "BaseUrl": config.BaseURL,
            "ChatStyle": PlaceObj.chat_style.name,
            "VendorId": 0,
            "ScreenShotInfo": "",
            "VideoInfo": "",
            "CreatorId": AssetObj.creator_id,
            "CreatorTypeEnum": "User" if AssetObj.creator_type == 0 else "Group",
            "MembershipType": GetUserMembership(AuthenticatedUser, changeToString=True),
            "AccountAge": (datetime.utcnow() - AuthenticatedUser.created).days,
            "CookieStoreFirstTimePlayKey": "rbx_evt_ftp",
            "CookieStoreFiveMinutePlayKey": "rbx_evt_fmp",
            "CookieStoreEnabled": True,
            "IsRobloxPlace": False,
            "UniverseId": PlaceObj.parent_universe_id,
            "GenerateTeleportJoin": False,
            "IsUnknownOrUnder13": False,
            "SessionId": SessionId,
            "DataCenterId": 0,
            "FollowUserId": 0,
            "BrowserTrackerId": 0,
            "UsePortraitMode": False,
            "CharacterAppearance": f"http://www.syntax.eco/v1/avatar-fetch?userId={str(AuthenticatedUser.id)}&placeId={str(requestedPlaceId)}",
            "GameId": PlaceServerObj.serverPlaceId,
            "RobloxLocale": "en_us",
            "GameLocale": "en_us",
            "characterAppearanceId": AuthenticatedUser.id
        }
    }))
    return resp

def GenerateClientTicket( UserObj : User, JobId : str, CharacterURL : str = None, CustomTimestamp : str = "", TicketVersion : int = 1, PlaceId : int = 1) -> str:
    """
        Generates a client ticket so that RCC can verify the user is authenticated
        If CharacterURL is not None, it will be used as the character URL instead of the default
        If CustomTimestamp is not 0, it will be used as the timestamp instead of the current time
    """
    if CustomTimestamp == "":
        CustomTimestamp = datetime.utcnow().strftime("%m/%d/%Y %I:%M:%S %p")
    if CharacterURL is None:
        if TicketVersion == 2:
            CharacterURL = str(UserObj.id)
        elif TicketVersion == 1:
            CharacterURL = Config.BaseURL + "/Asset/CharacterFetch.ashx?userId=" + str(UserObj.id) # f"http://www.syntax.eco/v1.1/avatar-fetch?userId={str(UserObj.id)}&placeId={str(PlaceId)}"
        elif TicketVersion == 4:
            CharacterURL = f"http://www.syntax.eco/v1/avatar-fetch?userId={str(UserObj.id)}&placeId={str(PlaceId)}"
    
    FirstTicketUnsigned = f"{str(UserObj.id)}\n{UserObj.username}\n{CharacterURL}\n{JobId}\n{str(CustomTimestamp)}"
    SignedFirstTicketRaw : bytes = signUTF8(FirstTicketUnsigned, formatAutomatically=False, addNewLine=False, useNewKey=(TicketVersion > 1))
    SignedFirstTicket = base64.b64encode(SignedFirstTicketRaw).decode("utf-8")

    AccountAge = (datetime.utcnow() - UserObj.created).days
    UserMembershipType = GetUserMembership(UserObj, changeToString=True)

    if TicketVersion <= 3:
        SecondTicketUnsigned = f"{str(UserObj.id)}\n{str(JobId)}\n{str(CustomTimestamp)}"
    elif TicketVersion == 4:
        SecondTicketUnsigned = f"{CustomTimestamp}\n{JobId}\n{UserObj.id}\n{UserObj.id}\n0\n{AccountAge}\nf\n{len(UserObj.username)}\n{UserObj.username}\n{len(UserMembershipType)}\n{UserMembershipType}\n0\n\n0\n\n{len(UserObj.username)}\n{UserObj.username}"

    SignedSecondTicketRaw : bytes = signUTF8(SecondTicketUnsigned, formatAutomatically=False, addNewLine=False, useNewKey=(TicketVersion > 1))
    SignedSecondTicket = base64.b64encode(SignedSecondTicketRaw).decode("utf-8")

    return f"{str(CustomTimestamp)};{SignedFirstTicket};{SignedSecondTicket}{f';{TicketVersion}' if TicketVersion > 1 else ''}"

@GameJoinRoute.route('/Game/Join.ashx', methods=['GET', 'POST'])
@csrf.exempt
def join():
    placeid = request.args.get('placeId', default = None, type = int)
    jobid = request.args.get('jobId', default = None, type = str)
    ticket = request.args.get('ticket', default = None, type = str)
    if placeid is None or jobid is None or ticket is None:
        return 'Invalid request ( 0 )',400

    ticketInfo = redis_controller.get(f"place:{placeid}:ticket:{ticket}")
    if ticketInfo is None:
        return 'Invalid request ( 1 )',400
    ticketInfo = json.loads(ticketInfo)
    if ticketInfo['jobid'] != jobid:
        return 'Invalid request ( 2 )',400

    PlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serveruuid=jobid).first()
    if PlaceServerObj is None:
        return 'Invalid request ( 3 )',400
    if PlaceServerObj.serverPlaceId != placeid:
        return 'Invalid request ( 4 )',400
    if PlaceServerObj.serverRunningTime == 0:
        return 'Invalid request ( 5 )',400
    if PlaceServerObj.maxPlayerCount <= PlaceServerObj.playerCount:
        return 'Invalid request ( 6 )',400
    UserObj : User = User.query.filter_by(id=ticketInfo['id']).first()
    if UserObj is None:
        return 'Invalid request ( 7 )',400
    PlaceObj : Place = Place.query.filter_by(placeid=placeid).first()
    AssetObj : Asset = Asset.query.filter_by(id=placeid).first()
    UniverseObj : Universe = Universe.query.filter_by(id=PlaceObj.parent_universe_id).first()

    ClientTicket = GenerateClientTicket(UserObj, jobid, TicketVersion = 1 if UniverseObj.place_year in [PlaceYear.Sixteen, PlaceYear.Fourteen] else ( 2 if UniverseObj.place_year == PlaceYear.Eighteen else 4), PlaceId = placeid)

    AuthenticationTicket = auth.CreateToken(UserObj.id, get_remote_address() , (60*60*24) )
    SessionId : str = f"{str(uuid.uuid4())}|{str(PlaceServerObj.serveruuid)}|0|{str(PlaceServerObj.serverIP)}|8|{datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.000Z')}|0|null|{AuthenticationTicket}"
    
    UserMembershipStatus : str = GetUserMembership(UserObj, changeToString=True)
    JoinData : str = json.dumps({
        "ClientPort" : 0,
        "MachineAddress" : PlaceServerObj.serverIP,
        "ServerConnections": [
            {
                "Port": PlaceServerObj.serverPort,
                "Address": PlaceServerObj.serverIP
            }
        ],
        "ServerPort" : PlaceServerObj.serverPort,
        "PingUrl": "",
        "PingInterval": 120,
        "UserName": UserObj.username,
        "DisplayName": UserObj.username,
        "SeleniumTestMode": False,
        "UserId": UserObj.id,
        "ClientTicket": ClientTicket,
        "SuperSafeChat": False,
        "PlaceId": PlaceServerObj.serverPlaceId,
        "MeasurementUrl": "",
        "WaitingForCharacterGuid": str(uuid.uuid4()),
        "BaseUrl": config.BaseURL,
        "ChatStyle": PlaceObj.chat_style.name,
        "VendorId": 0,
        "ScreenShotInfo": "",
        "VideoInfo": "",
        "CreatorId": AssetObj.creator_id,
        "CreatorTypeEnum": "User" if AssetObj.creator_type == 0 else "Group",
        "MembershipType": UserMembershipStatus,
        "AccountAge": (datetime.utcnow() - UserObj.created).days,
        "CookieStoreFirstTimePlayKey": "rbx_evt_ftp",
        "CookieStoreFiveMinutePlayKey": "rbx_evt_fmp",
        "CookieStoreEnabled": True,
        "IsRobloxPlace": False,
        "UniverseId": PlaceObj.parent_universe_id,
        "GenerateTeleportJoin": False,
        "IsUnknownOrUnder13": False,
        "SessionId": SessionId,
        "DataCenterId": 0,
        "FollowUserId": 0,
        "BrowserTrackerId": 0,
        "UsePortraitMode": False,
        "CharacterAppearance": config.BaseURL + "/Asset/CharacterFetch.ashx?userId=" + str(UserObj.id) if PlaceObj.placeyear in [PlaceYear.Fourteen, PlaceYear.Sixteen] else ( f"http://www.syntax.eco/v1.1/avatar-fetch?userId={str(UserObj.id)}&placeId={str(placeid)}" if PlaceObj.placeyear in [PlaceYear.Eighteen] else f"http://www.syntax.eco/v1/avatar-fetch?userId={str(UserObj.id)}&placeId={str(placeid)}" ),
        "GameId": PlaceServerObj.serverPlaceId,
        "RobloxLocale": "en_us",
        "GameLocale": "en_us",
        "characterAppearanceId": UserObj.id
    })
    if UniverseObj.place_year == PlaceYear.Sixteen:
        SignedJoinData : str = signUTF8("\r\n"+JoinData, addNewLine=False)
    elif UniverseObj.place_year == PlaceYear.Eighteen:
        SignedJoinData : str = signUTF8("\r\n"+JoinData, addNewLine=False, useNewKey=True)
    elif UniverseObj.place_year == PlaceYear.Twenty:
        SignedJoinData : str = signUTF8("\r\n"+JoinData, addNewLine=False, useNewKey=True)
    elif UniverseObj.place_year == PlaceYear.Fourteen:
        JoinData = json.loads(JoinData)
        VerificationTicket = str(uuid.uuid4())
        JoinData["CharacterAppearance"] = f"{config.BaseURL}/Asset/CharacterFetch.ashx?userId={str(UserObj.id)}&t={VerificationTicket}&legacy=1"
        redis_controller.set(
            f"joinashx-auth:{str(jobid)}:{str(UserObj.id)}:{placeid}:{VerificationTicket}",
            json.dumps({
                "CharacterAppearance": JoinData["CharacterAppearance"],
                "Username": JoinData["UserName"]
            }),
            ex = 60
        )
        JoinData = json.dumps(JoinData)

        SignedJoinData : str = signUTF8("\r\n"+JoinData, addNewLine=False)
    elif UniverseObj.place_year == PlaceYear.TwentyOne:
        SignedJoinData : str = signUTF8("\r\n"+JoinData, addNewLine=False, useNewKey=True)
    else:
        return 'Invalid request ( 8 )',400
    
    if UniverseObj.place_year in [ PlaceYear.Fourteen, PlaceYear.Sixteen ]:
        redis_controller.set(f"allow_join:{str(UserObj.id)}:{str(placeid)}:{str(jobid)}", "1", ex=120)

    joinResposne = make_response(SignedJoinData)
    joinResposne.headers['Content-Type'] = 'text/plain'
    joinResposne.set_cookie(
        key = "Syntax-Session-Id",
        value = SessionId,
        expires = datetime.utcnow() + timedelta(days=1),
        domain = f".{config.BaseDomain}"
    )
    if request.cookies.get(".ROBLOSECURITY") is None: # 2018 and 2020 doesen't want to authenticate properly with negotiate.ashx :(, so this is my hack till i can figure out why
        joinResposne.set_cookie( 
            key = ".ROBLOSECURITY",
            value = auth.CreateToken( userid = UserObj.id, expireIn = 60 * 60 * 24 * 3, ip = get_remote_address() ),
            expires = datetime.utcnow() + timedelta(days=3),
            domain = f".{config.BaseDomain}"
        )
    return joinResposne