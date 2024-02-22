from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort, after_this_request
from config import Config
from app.models.user import User
from app.models.gameservers import GameServer
from app.models.place import Place
from app.models.universe import Universe
from app.models.legacy_data_persistence import LegacyDataPersistence
from app.extensions import redis_controller, get_remote_address, csrf, limiter, db
from datetime import datetime
import logging
import gzip

LegacyDataPersistenceRoute = Blueprint('legacyDataPersistence', __name__, url_prefix='/persistence/legacy')

@LegacyDataPersistenceRoute.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        logging.info(f"LegacyDataPersistence - UserAgent {request.user_agent} - Not allowed")
        abort(404)
    RemoteAddress = get_remote_address()
    GameServerObj : GameServer = GameServer.query.filter_by( serverIP = RemoteAddress ).first()
    if GameServerObj is None:
        logging.info(f"LegacyDataPersistence - {RemoteAddress} - Not found")
        abort(404)
    
    if "Roblox-Place-Id" not in request.headers and "placeId" not in request.args:
        logging.info(f"LegacyDataPersistence - GameServer {RemoteAddress} - Roblox-Place-Id header and cookie not found")
        abort(404)
    
    PlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int ) or request.args.get( key = "placeId", default = None, type = int )
    if PlaceId is None:
        logging.info(f"LegacyDataPersistence - GameServer {RemoteAddress} - Roblox-Place-Id header or arg not expected type")
        abort(404)
    
    PlaceObj : Place = Place.query.filter_by( placeid = PlaceId ).first()
    if PlaceObj is None:
        logging.info(f"LegacyDataPersistence - Place {PlaceId} - Place not found")
        abort(404)

@LegacyDataPersistenceRoute.route('/load', methods=['POST', 'GET'])
@csrf.exempt
def LoadData():
    PlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int ) or request.args.get( key = "placeId", default = None, type = int )

    RequestedUserId = request.args.get(
        key = "userId",
        default = None,
        type = int
    )
    if RequestedUserId is None:
        return "Invalid request", 400
    
    UserObj : User = User.query.filter_by( id = RequestedUserId ).first()
    if UserObj is None:
        return "Invalid request", 400
    
    PlaceObj : Place = Place.query.filter_by( placeid = PlaceId ).first()
    if PlaceObj is None:
        return "Invalid request", 400
    UniverseObj : Universe = Universe.query.filter_by( id = PlaceObj.parent_universe_id ).first()
    if UniverseObj is None:
        return "Invalid request", 400
    
    LegacyDataPersistenceObj : LegacyDataPersistence = LegacyDataPersistence.query.filter_by(
        userid = RequestedUserId,
        universe_id = UniverseObj.id
    ).first()
    logging.info(f"LegacyDataPersistence - User {UserObj.id} - Place {PlaceId} - Universe {UniverseObj.id} - Data requested")
    if LegacyDataPersistenceObj is None:
        return "", 200
    
    return gzip.decompress(LegacyDataPersistenceObj.data), 200

@LegacyDataPersistenceRoute.route('/save', methods=['POST'])
@csrf.exempt
def SaveData():
    PlaceId = request.headers.get( key = "Roblox-Place-Id", default = None, type = int ) or request.args.get( key = "placeId", default = None, type = int )

    PayloadData = request.data
    if request.content_encoding != "gzip":
        PayloadData = gzip.compress( PayloadData )

    RequestedUserId = request.args.get(
        key = "userId",
        default = None,
        type = int
    )
    if RequestedUserId is None:
        return "Invalid request", 400
    
    UserObj : User = User.query.filter_by( id = RequestedUserId ).first()
    if UserObj is None:
        return "Invalid request", 400
    
    if len(PayloadData) > 1024 * 1024 * 2:
        logging.info(f"LegacyDataPersistence - User {UserObj.id} - Place {PlaceId} - Universe {UniverseObj.id} - Payload too large, {len(PayloadData)} bytes")
        return "Payload too large", 400
    
    PlaceObj : Place = Place.query.filter_by( placeid = PlaceId ).first()
    if PlaceObj is None:
        return "Invalid request", 400
    UniverseObj : Universe = Universe.query.filter_by( id = PlaceObj.parent_universe_id ).first()
    if UniverseObj is None:
        return "Invalid request", 400

    LegacyDataPersistenceObj : LegacyDataPersistence = LegacyDataPersistence.query.filter_by(
        userid = RequestedUserId,
        universe_id = UniverseObj.id
    ).first()

    if LegacyDataPersistenceObj is None:
        LegacyDataPersistenceObj = LegacyDataPersistence(
            placeid = PlaceId,
            userid = RequestedUserId,
            universe_id = UniverseObj.id
        )
        db.session.add( LegacyDataPersistenceObj )
    
    LegacyDataPersistenceObj.data = PayloadData
    LegacyDataPersistenceObj.last_updated = datetime.utcnow()
    db.session.commit()
    logging.info(f"LegacyDataPersistence - User {UserObj.id} - Place {PlaceId} - Universe {UniverseObj.id} - Saved {len(LegacyDataPersistenceObj.data)} bytes")
    return "OK", 200
    
    