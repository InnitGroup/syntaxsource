from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort, after_this_request
from config import Config
from app.models.user import User
from app.extensions import redis_controller, get_remote_address, csrf, limiter
from app.util import auth, websiteFeatures
import string
from datetime import datetime, timedelta
import random
import logging
from sqlalchemy import func
from app.pages.login.login import CreateLoginRecord

config = Config()
AuthenticationRoute = Blueprint('authentication', __name__, url_prefix='/')

@AuthenticationRoute.route('/Login/Negotiate.ashx', methods=['GET'])
def loginNegotiate():
    AuthenticationTicket = request.args.get(
        key = 'suggest',
        default = None,
        type = str
    )
    if AuthenticationTicket is None:
        return 'Invalid request',400
    
    authticketInfo = redis_controller.get(f"authticket:{AuthenticationTicket}")
    if authticketInfo is None:
        return 'Invalid request',400
    redis_controller.delete(f"authticket:{AuthenticationTicket}")

    userId = int(authticketInfo)
    newAuthToken = auth.CreateToken(userId, get_remote_address())
    resp = make_response(newAuthToken, 200)
    resp.headers["Content-Type"] = "text/plain"
    resp.set_cookie(".ROBLOSECURITY", newAuthToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")

    return resp

@AuthenticationRoute.route('/v2/twostepverification/verify', methods=['POST'])
@limiter.limit("12/minute")
@csrf.exempt
def verifyTwoStep():
    if not request.is_json:
        return jsonify( { "errors": [ { "code": 1, "message": "Invalid request." } ] } ), 400
    
    try:
        assert "username" in request.json, "Missing parameter: username"
        assert "code" in request.json, "Missing parameter: code"
        assert "ticket" in request.json, "Missing parameter: ticket"
        assert isinstance(request.json["username"], str), "Invalid parameter type: username, expected string"
        assert isinstance(request.json["code"], int), "Invalid parameter type: code, expected integer"
        assert isinstance(request.json["ticket"], str), "Invalid parameter type: ticket, expected string"
    except Exception as e:
        return jsonify( { "errors": [ { "code": 1, "message": f"Validation failed, {str(e)}" } ] } ), 400

    GivenUsername : str = request.json["username"]
    GivenTwoStepCode : int = request.json["code"]
    GivenTicket : str = request.json["ticket"]

    if redis_controller.exists(f"twofactorticket:{GivenTicket}") == 0:
        return jsonify( { "errors": [ { "code": 5, "message": "Invalid two step verification ticket." } ] } ), 400
    TwoFactorSessionTicketInfo = redis_controller.get(f"twofactorticket:{GivenTicket}")
    if TwoFactorSessionTicketInfo is None:
        return jsonify( { "errors": [ { "code": 5, "message": "Invalid two step verification ticket." } ] } ), 400
    redis_controller.delete(f"twofactorticket:{GivenTicket}")

    UserId = int(TwoFactorSessionTicketInfo)

    Validated2FA = auth.Validate2FACode(UserId, GivenTwoStepCode)
    if not Validated2FA:
        return jsonify( { "errors": [ { "code": 6, "message": "The code is invalid." } ] } ), 400
    
    if Validated2FA:
        Response = make_response(jsonify({}))
        sessionToken = auth.CreateToken(userid=UserId, ip=get_remote_address())
        Response.set_cookie(".ROBLOSECURITY", sessionToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")
        return Response


@AuthenticationRoute.route('/Login/NewAuthTicket', methods=['POST'])
@csrf.exempt
@auth.authenticated_required_api
def loginNewAuthTicket():
    userId = auth.GetCurrentUser().id

    authticket = ''.join(random.choices(string.ascii_uppercase + string.digits, k=256))
    redis_controller.set(f"authticket:{authticket}", userId, 60*10)
    return authticket,200

@AuthenticationRoute.route('/game/GetCurrentUser.ashx', methods=['GET'])
def gameGetCurrentUser():
    AuthenticatedUser = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return "Bad Request", 200
    return str(AuthenticatedUser.id), 200

@AuthenticationRoute.route('/login/RequestAuth.ashx', methods=['GET'])
@limiter.limit("6/minute")
def loginRequestAuth():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return "User is not authorized.", 401
    NewAuthTicket = ''.join(random.choices(string.ascii_uppercase + string.digits, k=256))
    redis_controller.set(f"authticket:{NewAuthTicket}", AuthenticatedUser.id, 60*10)

    resp = make_response(
        f"{config.BaseURL}/Login/Negotiate.ashx?suggest={NewAuthTicket}",
        200
    )
    resp.headers["Content-Type"] = "text/plain"
    return resp

@AuthenticationRoute.route('/game/logout.aspx')
@auth.authenticated_required
def gameLogout():
    auth.invalidateToken(request.cookies.get(".ROBLOSECURITY"))
    resp = make_response(redirect("/login"))
    resp.set_cookie(".ROBLOSECURITY", "", expires=0)
    return resp

@AuthenticationRoute.route('/v2/login', methods=['POST'])
@limiter.limit("12/minute")
@csrf.exempt
def LoginRoute():
    loginEnabled = websiteFeatures.GetWebsiteFeature("WebLogin")
    if not loginEnabled:
        return jsonify( { "errors": [ { "code": 11, "message": "Service unavailable. Please try again." } ] } ), 503

    if not request.is_json:
        return abort(400)
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser and request.user_agent.string != "RobloxStudio/WinInet RobloxApp/0.450.0.411923 (GlobalDist; RobloxDirectDownload)":
        return redirect("/home")
    
    if AuthenticatedUser and request.user_agent.string == "RobloxStudio/WinInet RobloxApp/0.450.0.411923 (GlobalDist; RobloxDirectDownload)":
        Response = make_response(jsonify({
            "username": AuthenticatedUser.username,
            "isUnder13": False,
            "userId": AuthenticatedUser.id,
            "countryCode": "US",
            "membershipType": 4,
            "displayName": AuthenticatedUser.username
        }))
        return Response
    
    if ( "username" not in request.json and "cvalue" not in request.json ) or "password" not in request.json:
        return jsonify( { "errors": [ { "code": 1, "message": "Incorrect username or password. Please try again." } ] } ), 403
    if "username" in request.json:
        Username = str(request.json["username"])
    else:
        Username = str(request.json["cvalue"])
    Password = str(request.json["password"])

    UserObject : User = User.query.filter(func.lower(User.username) == func.lower(Username)).first()
    if not UserObject:
        return jsonify( { "errors": [ { "code": 1, "message": "Incorrect username or password. Please try again." } ] } ), 403
    
    if UserObject.accountstatus != 1:
        return jsonify( { "errors": [ { "code": 1, "message": "Incorrect username or password. Please try again." } ] } ), 403
    
    ActualPassword = Password
    if UserObject.TOTPEnabled:
        if request.user_agent.string == "RobloxStudio/WinInet RobloxApp/0.450.0.411923 (GlobalDist; RobloxDirectDownload)":
            if not auth.VerifyPassword(UserObject, ActualPassword):
                return jsonify( { "errors": [ { "code": 1, "message": "Incorrect username or password. Please try again." } ] } ), 403 
            twofactorticket = ''.join(random.choices(string.ascii_uppercase + string.digits, k=60))
            redis_controller.set(f"twofactorticket:{twofactorticket}", UserObject.id, 60*10) 
            return jsonify({"user": {
                "id": UserObject.id,
                "name": UserObject.username,
                "displayName": UserObject.username
            }, "twoStepVerificationData": {
                "mediaType": "Email",
                "ticket": twofactorticket
            }, "identityVerificationLoginTicket": twofactorticket })
        if ";" not in Password:
            return jsonify( { "errors": [ { "code": 1, "message": "Incorrect username or password. Please try again." } ] } ), 403
        ActualPassword = Password.split(";")[0]
        TOTPCode = Password.split(";")[1]

        if not auth.Validate2FACode(UserObject.id, TOTPCode):
            return jsonify( { "errors": [ { "code": 1, "message": "Incorrect username or password. Please try again." } ] } ), 403
    
    if not auth.VerifyPassword(UserObject, ActualPassword):
        return jsonify( { "errors": [ { "code": 1, "message": "Incorrect username or password. Please try again." } ] } ), 403
    
    sessionToken = auth.CreateToken(userid=UserObject.id, ip=get_remote_address())
    Response = make_response(jsonify({
        "username": UserObject.username,
        "isUnder13": False,
        "userId": UserObject.id,
        "countryCode": "US",
        "membershipType": 4,
        "displayName": UserObject.username
    }))
    Response.set_cookie(".ROBLOSECURITY", sessionToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")
    CreateLoginRecord( UserObject.id )
    #logging.info(f"/v2/login - {UserObject.username} ({UserObject.id}) [{request.user_agent}] logged in successfully")

    return Response

@AuthenticationRoute.route("/v1/logout", methods=["POST"])
@AuthenticationRoute.route("/v2/logout", methods=["POST"])
@auth.authenticated_required_api
@csrf.exempt
def LogoutRoute():
    auth.invalidateToken(request.cookies.get(".ROBLOSECURITY"))
    resp = make_response(jsonify({}))
    resp.set_cookie(".ROBLOSECURITY", "", expires=0)
    return resp

@AuthenticationRoute.route("/v2/passwords/current-status", methods=["GET"])
@auth.authenticated_required_api
def PasswordsCurrentStatusRoute():
    return jsonify({"valid": True})