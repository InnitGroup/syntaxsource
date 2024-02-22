from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort, after_this_request
from app.models.placeservers import PlaceServer
from app.models.gameservers import GameServer
from app.models.place import Place
from app.models.universe import Universe
from app.models.user import User
from app.extensions import redis_controller, get_remote_address, csrf, limiter, db
from app.enums.PlaceYear import PlaceYear
from app.routes.gamejoin import CreateNewPlaceServer
import logging
import random
import string

TeleportServiceRoute = Blueprint('teleportServiceinternal', __name__, url_prefix='/reservedservers')

@TeleportServiceRoute.before_request
def before_request_hook():
    if "Roblox/" not in request.user_agent.string:
        logging.info(f"TeleportServiceInternal - UserAgent {request.user_agent} - Not allowed")
        abort(404)
    RemoteAddress = get_remote_address()
    GameServerObj : GameServer = GameServer.query.filter_by( serverIP = RemoteAddress ).first()
    if GameServerObj is None:
        logging.info(f"TeleportServiceInternal - {RemoteAddress} - Not found")
        abort(404)
    
    if "Roblox-Place-Id" not in request.headers:
        logging.info(f"TeleportServiceInternal - GameServer {RemoteAddress} - Roblox-Place-Id header not found")
        abort(404)

    accessKeyRequest = request.headers.get( key = "accesskey", default = "" )
    if "UserRequest" in accessKeyRequest:
        logging.warning(f"TeleportServiceInternal - GameServer {RemoteAddress} - UserRequest access key used")
        abort(404)
    
    PlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int )
    if PlaceId is None:
        logging.info(f"TeleportServiceInternal - GameServer {RemoteAddress} - Roblox-Place-Id header not expected type")
        abort(404)
    
    PlaceObj : Place = Place.query.filter_by( placeid = PlaceId ).first()
    if PlaceObj is None:
        logging.info(f"TeleportServiceInternal - Place {PlaceId} - Place not found")
        abort(404)

@TeleportServiceRoute.route('/create', methods=['POST'])
@csrf.exempt
def create_reserved_server():
    OriginPlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int )
    TargetPlaceId = request.args.get( key = "placeId", default = None, type = int )

    if OriginPlaceId is None or TargetPlaceId is None:
        logging.error(f"TeleportServiceInternal - create_reserved_server - Bad Request - OriginPlaceId {OriginPlaceId} TargetPlaceId {TargetPlaceId} - Both has to be not none")
        return "Invalid request", 400
    
    OriginPlaceObj : Place = Place.query.filter_by( placeid = OriginPlaceId ).first()
    TargetPlaceObj : Place = Place.query.filter_by( placeid = TargetPlaceId ).first()
    if OriginPlaceObj is None or TargetPlaceObj is None:
        logging.error(f"TeleportServiceInternal - create_reserved_server - Bad Request - Place {OriginPlaceId} or {TargetPlaceId} not found")
        return "Invalid request", 400

    if OriginPlaceObj.parent_universe_id != TargetPlaceObj.parent_universe_id:
        logging.error(f"TeleportServiceInternal - create_reserved_server - Bad Request - OriginPlace {OriginPlaceId} and TargetPlace {TargetPlaceId} are not in the same universe")
        return "Invalid request", 400
    
    UniverseObj : Universe = Universe.query.filter_by( id = OriginPlaceObj.parent_universe_id ).first()
    if UniverseObj is None:
        return "Invalid request", 400
    
    if UniverseObj.place_year not in [ PlaceYear.Sixteen, PlaceYear.Eighteen, PlaceYear.Twenty, PlaceYear.TwentyOne]:
        logging.error(f"TeleportServiceInternal - create_reserved_server - Bad Request - Universe {UniverseObj.id} - PlaceYear {UniverseObj.place_year} is not supported")
        return "Invalid request", 400

    CooldownKeyName = f"reserved_server_creation_cooldown:{OriginPlaceObj.parent_universe_id}"
    ReservedServerAccessCode = ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(64))
    
    if not redis_controller.exists( CooldownKeyName ):
        redis_controller.setex( name = CooldownKeyName, time = 10, value = "1" )
        try:
            NewPlaceServerObj : PlaceServer = CreateNewPlaceServer(
                placeId = TargetPlaceId,
                reserved_server_access_code = ReservedServerAccessCode
            )
        except Exception as e:
            logging.error(f"TeleportServiceInternal - create_reserved_server - Place {TargetPlaceId} - Universe {UniverseObj.id} - {e}")
            return "Failed to start new server", 400
    
    redis_controller.set( f"reservedserveraccesscode_server:{ReservedServerAccessCode}", TargetPlaceObj.placeid, ex = 60 * 60 * 24 )
    
    return jsonify({
        "ReservedServerAccessCode": ReservedServerAccessCode,
        "ReservedServerGameCode": ReservedServerAccessCode
    })

@TeleportServiceRoute.route('/grantaccess', methods=['POST'])
@csrf.exempt
def grant_access_to_reserved():
    given_reservedServerAccessCode = request.args.get( key = 'reservedServerAccessCode', default = None, type = str )
    OriginPlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int )
    if given_reservedServerAccessCode is None or OriginPlaceId is None:
        return "Invalid request", 400
    
    OriginPlaceObj : Place = Place.query.filter_by( placeid = OriginPlaceId ).first()
    if OriginPlaceObj is None:
        return "Invalid request", 400
    
    TargetPlaceServerObj : PlaceServer = PlaceServer.query.filter_by( reservedServerAccessCode = given_reservedServerAccessCode ).first()
    if TargetPlaceServerObj is None:
        accessCodePlaceIdOrigin = redis_controller.get( f"reservedserveraccesscode_server:{given_reservedServerAccessCode}" )
        if accessCodePlaceIdOrigin is None:
            return "Invalid request", 400
        TargetPlaceObj : Place = Place.query.filter_by( placeid = int( accessCodePlaceIdOrigin ) ).first()
        if TargetPlaceObj is None:
            return "Invalid request", 400
        
        if TargetPlaceObj.parent_universe_id != OriginPlaceObj.parent_universe_id:
            return "Invalid request", 400
        
        try:
            TargetPlaceServerObj : PlaceServer = CreateNewPlaceServer(
                placeId = TargetPlaceObj.placeid,
                reserved_server_access_code = given_reservedServerAccessCode
            )
        except Exception as e:
            logging.error(f"TeleportServiceInternal - grant_access_to_reserved - Place {TargetPlaceObj.placeid} - Universe {TargetPlaceObj.parent_universe_id} - {e}")
            return "Failed to start new server", 400
        redis_controller.set( f"reservedserveraccesscode_server:{given_reservedServerAccessCode}", TargetPlaceObj.placeid, ex = 60 * 60 * 24 )
    
    AllowedUserIds = request.form.getlist( key = "playerIds", type = int )
    if len( AllowedUserIds ) == 0:
        return "Invalid request", 400
    
    for UserId in AllowedUserIds:
        UserObj : User = User.query.filter_by( id = UserId ).first()
        if UserObj is None:
            return "Invalid request", 400
        redis_controller.set( f"reservedserveraccesscode:{TargetPlaceServerObj.serveruuid}:{UserObj.id}", "1", ex = 60 * 8)
    
    return "", 200