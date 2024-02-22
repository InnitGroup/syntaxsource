from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response
from app.models.fflag_group import FflagGroup
from app.models.fflag_value import FflagValue
from app.models.gameservers import GameServer
from app.extensions import redis_controller, get_remote_address
import json
import base64

FFlagRoute = Blueprint("fflag", __name__, url_prefix="/")

def ClearCache( GroupId : int ):
    redis_controller.delete("fflags_" + str(GroupId))
    GenerateFFlags(GroupId, True)

def GenerateFFlags( GroupId : int, BypassCache : bool = False ) -> dict:
    if not BypassCache:
        CachedFFlags = redis_controller.get("fflags_" + str(GroupId))
        if CachedFFlags is not None:
            return json.loads(CachedFFlags)

    FFlagValues = FflagValue.query.filter_by(group_id=GroupId).all()
    if FFlagValues is None:
        return jsonify({}),200
    
    FinalData = {}
    for FFlagValue in FFlagValues:
        FinalData[FFlagValue.name] = str(base64.b64decode(FFlagValue.flag_value).decode('utf-8'))

    redis_controller.set("fflags_" + str(GroupId), json.dumps(FinalData), ex = 60 * 60)
    return FinalData

@FFlagRoute.route("/Setting/QuietGet/<group>", methods=["GET"])
@FFlagRoute.route("/Setting/QuietGet/<group>/", methods=["GET"])
@FFlagRoute.route("/Setting/Get/<group>/", methods=["GET"])
def get_fflag(group):
    FFlagGroupObj : FflagGroup = FflagGroup.query.filter_by(name=group).first()
    if FFlagGroupObj is None:
        return 'Invalid request',400
    
    if FFlagGroupObj.gameserver_only:
        RequestingRemoteAddress = get_remote_address()
        GameServerObj = GameServer.query.filter_by( serverIP = RequestingRemoteAddress ).first()
        if GameServerObj is None:
            return 'Invalid request',400
    
    return jsonify(GenerateFFlags(FFlagGroupObj.group_id)),200

@FFlagRoute.route("/v1/settings/application", methods=["GET"])
def fflag_application():
    applicationName : str = request.args.get(key="applicationName", default=None, type=str)
    if applicationName is None:
        return 'Invalid request',400
    applicationName = "application_" + applicationName

    FFlagGroupObj : FflagGroup = FflagGroup.query.filter_by(name=applicationName).first()
    if FFlagGroupObj is None:
        return 'Invalid request',400
    
    if FFlagGroupObj.gameserver_only:
        RequestingRemoteAddress = get_remote_address()
        GameServerObj = GameServer.query.filter_by( serverIP = RequestingRemoteAddress ).first()
        if GameServerObj is None:
            return 'Invalid request',400
    
    return jsonify({
        "applicationSettings": GenerateFFlags(FFlagGroupObj.group_id)
    }),200
    
