from flask import Blueprint, render_template, request, redirect, url_for, flash, session, abort, jsonify, make_response
from app.util import auth
from app.extensions import db, csrf, limiter
from flask_wtf.csrf import CSRFError, generate_csrf
from datetime import datetime, timedelta

from app.models.user_email import UserEmail
from app.models.user import User
from app.models.placeserver_players import PlaceServerPlayer
from app.models.placeservers import PlaceServer
from app.models.place import Place
from app.models.asset import Asset

PresenceAPIRoute = Blueprint('presenceapiroute', __name__, url_prefix='/')

csrf.exempt(PresenceAPIRoute)
@PresenceAPIRoute.errorhandler(CSRFError)
def handle_csrf_error(e):
    ErrorResponse = make_response(jsonify({
        "errors": [
            {
                "code": 0,
                "message": "Token Validation Failed"
            }
        ]
    }))

    ErrorResponse.status_code = 403
    ErrorResponse.headers["x-csrf-token"] = generate_csrf()
    return ErrorResponse

@PresenceAPIRoute.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({
        "errors": [
            {
                "code": 9,
                "message": "The flood limit has been exceeded."
            }
        ]
    }), 429

@PresenceAPIRoute.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        csrf.protect()

@PresenceAPIRoute.route("/v1/presence/users", methods=["POST"])
@auth.authenticated_required_api
@limiter.limit("30/minute")
def multi_get_users_presence():
    if not request.is_json:
        return jsonify({"errors": [{"code": 0,"message": "Invalid Request"}]}), 400
    
    if "userIds" not in request.json:
        return jsonify({"errors": [{"code": 0,"message": "Invalid Request"}]}), 400
    
    userIds = request.json["userIds"]

    if type(userIds) is not list:
        return jsonify({"errors": [{"code": 0,"message": "Invalid Request"}]}), 400

    if len(userIds) > 100:
        return jsonify({"errors": [{"code": 0,"message": "Invalid Request"}]}), 400
    
    requestedData = []
    for userId in userIds:
        try:
            userId = int(userId)
        except:
            return jsonify({"errors": [{"code": 1,"message": "Invalid UserId"}]}), 400
        userObject : User = User.query.filter_by(id=userId).first()
        if userObject is None:
            return jsonify({"errors": [{"code": 1,"message": "Invalid UserId"}]}), 400
        else:
            isUserOnline = userObject.lastonline > datetime.utcnow() - timedelta(minutes=1)
            UserPlaceServerPlayerObj : PlaceServerPlayer | None = PlaceServerPlayer.query.filter_by( userid = userId ).first()
            isUserInGame = UserPlaceServerPlayerObj is not None
            userPresenceType = 2 if isUserInGame else 1 if isUserOnline else 0

            PlaceServerHost : PlaceServer | None = None
            PlaceObject : Place | None = None

            if isUserInGame:
                PlaceServerHost : PlaceServer = PlaceServer.query.filter_by( serveruuid = UserPlaceServerPlayerObj.serveruuid ).first()
                if PlaceServerHost is not None:
                    PlaceObject : Place = Place.query.filter_by( placeid = PlaceServerHost.serverPlaceId ).first()
                    PlaceAssetObj : Asset = PlaceObject.assetObj
                else:
                    PlaceAssetObj = None
                    UserPlaceServerPlayerObj = None

            requestedData.append({
                "userPresenceType": userPresenceType,
                "lastLocation": "Website" if not isUserInGame else PlaceAssetObj.name,
                "placeId": PlaceAssetObj.id if isUserInGame else None,
                "rootPlaceId": PlaceAssetObj.id if isUserInGame else None,
                "gameId": PlaceServerHost.serveruuid if isUserInGame else None,
                "userId": userId,
                "lastOnline": userObject.lastonline.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
            })
    
    return jsonify({
        "userPresences": requestedData
    }), 200