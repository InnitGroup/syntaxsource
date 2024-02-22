from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify
from app.models.gameservers import GameServer
from app.models.place_ordered_datastore import PlaceOrderedDatastore
from app.models.place_datastore import PlaceDatastore
from app.models.asset import Asset
from app.models.universe import Universe
from app.models.place import Place
from app.enums.AssetType import AssetType
from app.extensions import get_remote_address, db, redis_controller, csrf
from functools import wraps

DataStoreRoute = Blueprint('datastore', __name__)

def GameServerRequired(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        RequestIP = get_remote_address()
        if RequestIP is None:
            return jsonify({"success": False, "message": "Unauthorized"}),401    
        
        server : GameServer = GameServer.query.filter_by(serverIP=RequestIP).first()
        if server is None:
            return jsonify({"success": False, "message": "Unauthorized"}),401
        
        ServerAccessKey = request.headers.get("AccessKey", default = None, type = str)
        if ServerAccessKey is None or ServerAccessKey != server.accessKey:
            return jsonify({"success": False, "message": "Unauthorized"}),401

        return f(*args, **kwargs)
    return decorated_function

@DataStoreRoute.route("/persistence/getSortedValues", methods=["POST"])
@csrf.exempt
@GameServerRequired
def getSortedValues():
    placeId : int = request.args.get("placeId", default=None, type=int)
    dataType : str = request.args.get("type", default=None, type=str)
    scope : str = request.args.get("scope", default="global", type=str)
    pageSize : int = request.args.get("pageSize", default=50, type=int)
    exclusiveStartKey : str = request.args.get("exclusiveStartKey", default=None, type=int) # I have no idea how Roblox uses this, but I am going to use it as a page number with pagination
    key : str = request.args.get("key", default=None, type=str)
    ascending : bool = request.args.get("ascending", default="False", type=str) == "True"
    inclusiveMinValue : int = request.args.get("inclusiveMinValue", default=None, type=int)
    exclusiveMaxValue : int = request.args.get("inclusiveMaxValue", default=None, type=int)

    PlaceObj : Place = Place.query.filter_by(placeid = placeId).first()
    if PlaceObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200
    UniverseObj : Universe = Universe.query.filter_by(id = PlaceObj.parent_universe_id).first()
    if UniverseObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200
    
    if pageSize == 0 or pageSize > 100:
        return jsonify({"data":[], "message": "Page size is too large"}), 200
    if dataType != "sorted":
        return jsonify({"data":[], "message": "Invalid data type"}), 200
    
    if exclusiveStartKey is None:
        exclusiveStartKey = 1
    else:
        if exclusiveStartKey < 1:
            return jsonify({"data":[], "message": "Invalid exclusive start key"}), 200

    DataStoreObj = PlaceOrderedDatastore.query.filter_by(
        universe_id = UniverseObj.id,
        scope = scope,
        key = key
    )
    if inclusiveMinValue is not None:
        DataStoreObj = DataStoreObj.filter(PlaceOrderedDatastore.value >= inclusiveMinValue)
    if exclusiveMaxValue is not None:
        DataStoreObj = DataStoreObj.filter(PlaceOrderedDatastore.value < exclusiveMaxValue)
    DataStoreObj : list[PlaceOrderedDatastore] = DataStoreObj.order_by(PlaceOrderedDatastore.value.asc() if ascending else PlaceOrderedDatastore.value.desc()).paginate( page=exclusiveStartKey, per_page=pageSize, error_out=False )
    if DataStoreObj is None:
        return jsonify({"Entries": [], "ExclusiveStartKey": None}), 200

    AllEntries = []
    for entry in DataStoreObj.items:
        AllEntries.append({
            "Target": entry.name,
            "Value": entry.value
        })

    return jsonify({"data":{
        "Entries": AllEntries,
        "ExclusiveStartKey": str(DataStoreObj.next_num) if DataStoreObj.has_next else None
    }}) # TODO: Implement

@DataStoreRoute.route("/persistence/set", methods=["POST"])
@csrf.exempt
@GameServerRequired
def setKey():
    placeId : int = request.args.get("placeId", default=None, type=int)
    dataType : str = request.args.get("type", default=None, type=str)
    scope : str = request.args.get("scope", default="global", type=str)
    key : str = request.args.get("key", default=None, type=str)
    target : str = request.args.get("target", default=None, type=str)
    valueLength : int = request.args.get("valueLength", default=None, type=int)

    value : str = request.form.get("value", default=None, type=str)

    if valueLength is not None and not valueLength < 1024 * 1024 * 1: # 1MB
        return jsonify({"success": False, "message": "Value too large"}),400
    
    PlaceObj : Place = Place.query.filter_by(placeid = placeId).first()
    if PlaceObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200
    UniverseObj : Universe = Universe.query.filter_by(id = PlaceObj.parent_universe_id).first()
    if UniverseObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200
    
    if dataType == "standard":
        DataStoreObj : PlaceDatastore = PlaceDatastore.query.filter_by(
            universe_id = UniverseObj.id,
            scope = scope,
            key = key,
            name = target
        ).order_by(PlaceDatastore.updated_at.desc()).first()
        if DataStoreObj is None:
            DataStoreObj : PlaceDatastore = PlaceDatastore(
                placeid = placeId,
                universe_id = UniverseObj.id,
                scope=scope,
                key=key,
                name=target,
                value=value
            )
            db.session.add(DataStoreObj)
        else:
            DataStoreObj.value = value
        db.session.commit()
    elif dataType == "sorted":
        try:
            value : int = int(value)
        except:
            return jsonify({"success": False, "message": "Value is not an integer"}), 400
        
        DataStoreObj : PlaceOrderedDatastore = PlaceOrderedDatastore.query.filter_by(
            universe_id = UniverseObj.id,
            scope=scope,
            key=key,
            name=target
        ).order_by(PlaceOrderedDatastore.updated_at.desc()).first()
        if DataStoreObj is None:
            DataStoreObj : PlaceOrderedDatastore = PlaceOrderedDatastore(
                placeid = placeId,
                universe_id = UniverseObj.id,
                scope=scope,
                key=key,
                name=target,
                value=value
            )
            db.session.add(DataStoreObj)
        else:
            DataStoreObj.value = value
        db.session.commit()

    return jsonify({"data":value}) # TODO: Implement

@DataStoreRoute.route("/persistence/getV2", methods=["POST"])
@DataStoreRoute.route("/persistence/getv2", methods=["POST"])
@csrf.exempt
@GameServerRequired
def getv2():
    placeId : int = request.args.get("placeId", default=None, type=int)
    dataType : str = request.args.get("type", default=None, type=str)
    scope : str = request.args.get("scope", default="global", type=str)

    PlaceObj : Place = Place.query.filter_by(placeid = placeId).first()
    if PlaceObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200
    UniverseObj : Universe = Universe.query.filter_by(id = PlaceObj.parent_universe_id).first()
    if UniverseObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200

    dataBeingRequested = []

    StartingCount = 0
    while True:
        ReqScope : str = request.form.get(f"qkeys[{str(StartingCount)}].scope", default=None, type=str)
        if ReqScope is None:
            break
        Target : str = request.form.get(f"qkeys[{str(StartingCount)}].target", default=None, type=str)
        DataStoreName : str = request.form.get(f"qkeys[{str(StartingCount)}].key", default=None, type=str)
        if DataStoreName is None or Target is None or ReqScope is None:
            break
        dataBeingRequested.append({"Scope": ReqScope, "Target": Target, "Key": DataStoreName})
        StartingCount += 1
    if len(dataBeingRequested) == 0:
        return jsonify({"data":[], "message": "No data being requested"}), 200
    
    ReturnData = []
    if dataType == 'standard':
        for targetReq in dataBeingRequested:
            DataStoreObj : PlaceDatastore = PlaceDatastore.query.filter_by(universe_id = UniverseObj.id, scope=targetReq["Scope"], key=targetReq["Key"], name=targetReq["Target"]).order_by(PlaceDatastore.updated_at.desc()).first()
            if DataStoreObj is not None:
                ReturnData.append({
                    "Value": DataStoreObj.value,
                    "Scope": DataStoreObj.scope,
                    "Key": DataStoreObj.key,
                    "Target": DataStoreObj.name
                })
    elif dataType == 'sorted':
        for targetReq in dataBeingRequested:
            DataStoreObj : PlaceOrderedDatastore = PlaceOrderedDatastore.query.filter_by(universe_id = UniverseObj.id, scope=targetReq["Scope"], key=targetReq["Key"], name=targetReq["Target"]).order_by(PlaceOrderedDatastore.updated_at.desc()).first()
            if DataStoreObj is not None:
                ReturnData.append({
                    "Value": str(DataStoreObj.value),
                    "Scope": DataStoreObj.scope,
                    "Key": DataStoreObj.key,
                    "Target": DataStoreObj.name
                })

    return jsonify({"data":ReturnData})

@DataStoreRoute.route("/persistence/increment", methods=["POST"])
@csrf.exempt
@GameServerRequired
def increment():
    placeId : int = request.args.get("placeId", default=None, type=int)
    key : str = request.args.get("key", default=None, type=str)
    dataType : str = request.args.get("type", default=None, type=str)
    scope : str = request.args.get("scope", default="global", type=str)
    target : str = request.args.get("target", default=None, type=str)
    value : int = request.args.get("value", default=None, type=int)

    PlaceObj : Place = Place.query.filter_by(placeid = placeId).first()
    if PlaceObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200
    UniverseObj : Universe = Universe.query.filter_by(id = PlaceObj.parent_universe_id).first()
    if UniverseObj is None:
        return jsonify({"data":[], "message": "Place does not exist"}), 200
    
    if dataType == "standard":
        DataStoreObj : PlaceDatastore = PlaceDatastore.query.filter_by(
            universe_id=UniverseObj.id,
            scope=scope,
            key=key,
            name=target
        ).order_by(PlaceDatastore.updated_at.desc()).first()
        if DataStoreObj is None:
            DataStoreObj : PlaceDatastore = PlaceDatastore(
                placeid = placeId,
                universe_id=UniverseObj.id,
                scope=scope,
                key=key,
                name=target,
                value=str(value)
            )
            db.session.add(DataStoreObj)
        else:
            try:
                DataStoreObj.value = str(int(DataStoreObj.value) + value)
            except:
                return jsonify({"data":[], "message": "Value is not an integer"}), 200
        db.session.commit()
    elif dataType == "sorted":
        DataStoreObj : PlaceOrderedDatastore = PlaceOrderedDatastore.query.filter_by(
            universe_id=UniverseObj.id,
            scope=scope,
            key=key,
            name=target
        ).order_by(PlaceOrderedDatastore.updated_at.desc()).first()
        if DataStoreObj is None:
            DataStoreObj : PlaceOrderedDatastore = PlaceOrderedDatastore(
                placeid = placeId,
                universe_id=UniverseObj.id,
                scope=scope,
                key=key,
                name=target,
                value=value
            )
            db.session.add(DataStoreObj)
        else:
            DataStoreObj.value += value # PlaceOrderedDatastore values should always be integers

    return jsonify({"data":value})