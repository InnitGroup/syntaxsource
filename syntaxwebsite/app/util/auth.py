import hashlib
import logging
import time
import string
import random
import uuid
import pyotp

from argon2 import PasswordHasher
from config import Config
from flask import request, redirect, jsonify, make_response, abort, g
from functools import wraps

from app.models.user import User
from app.models.placeservers import PlaceServer
from app.models.gameservers import GameServer
from app.extensions import db, redis_controller, get_remote_address

config = Config()

def ValidateToken( token : str ) -> bool:
    TokenInfo = redis_controller.get("authtoken_" + token)
    if TokenInfo is None:
        return False
    
    # Token Info Format
    # userid|created|expiry|ip
    TokenInfo = TokenInfo.split("|")
    if len(TokenInfo) != 4:
        redis_controller.delete("authtoken_" + token)
        return False
    
    if int(TokenInfo[2]) < int(time.time()):
        redis_controller.delete("authtoken_" + token)
        return False
    
    return True

def GetAuthenticatedUser( token : str ) -> User:
    AuthTokenInfo = GetTokenInfo(token)
    if AuthTokenInfo is None:
        return None
    return User.query.filter_by(id=int(AuthTokenInfo[0])).first()

def GetTokenInfo( token : str ) -> list:
    TokenInfo = redis_controller.get("authtoken_" + token)
    if TokenInfo is None:
        return None
    
    # Token Info Format
    # userid|created|expiry|ip
    TokenInfo = TokenInfo.split("|")
    if len(TokenInfo) != 4:
        redis_controller.delete("authtoken_" + token)
        return None
    
    if int(TokenInfo[2]) < int(time.time()):
        redis_controller.delete("authtoken_" + token)
        return None
    
    return TokenInfo

def CreateToken( userid : int , ip, expireIn : int = (60 * 60 * 24 * 31)) -> str:
    random.seed(str(uuid.uuid4()))
    Token = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(512))

    # Token Info Format
    # userid|created|expiry|ip
    
    TokenInfo = str(userid) + "|" + str(int(time.time())) + "|" + str(int(time.time()) + expireIn) + "|" + ip
    redis_controller.set("authtoken_" + Token, TokenInfo, ex = expireIn)
    
    return Token

def isAuthenticated():
    if ".ROBLOSECURITY" not in request.cookies:
        return False
    if not ValidateToken(request.cookies[".ROBLOSECURITY"]):
        return False
    return True

def authenticated_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if ".ROBLOSECURITY" not in request.cookies:
            return redirect("/login")
        if not ValidateToken(request.cookies[".ROBLOSECURITY"]):
            RedirectResponse = make_response(redirect("/login"))
            RedirectResponse.set_cookie(".ROBLOSECURITY", expires=0)
            return RedirectResponse
        return f(*args, **kwargs)
    return decorated_function

def authenticated_required_api(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if ".ROBLOSECURITY" not in request.cookies:
            return jsonify({"success": False, "message": "You are not logged in"}), 401
        if not ValidateToken(request.cookies[".ROBLOSECURITY"]):
            ErrorResponse = make_response(jsonify({"success": False, "message": "You are not logged in"}), 401)
            ErrorResponse.set_cookie(".ROBLOSECURITY", expires=0)
            return ErrorResponse
        
        return f(*args, **kwargs)
    return decorated_function

def authenticated_client_endpoint(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if request.cookies.get("Syntax-Session-Id", type = str ) is not None:
            DataSections = request.cookies.get("Syntax-Session-Id", type = str )
        else:
            return jsonify({"success": False, 'error': 'Missing Headers'}), 401
        
        if len(DataSections) != 9:
            return jsonify({"success": False, 'error': 'Invalid Headers'}), 401
        
        AuthToken = DataSections[8]
        if not ValidateToken(AuthToken):
            return jsonify({"success": False, 'error': 'Invalid Token'}), 401
        
        PlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serveruuid=str(DataSections[1])).first()
        if PlaceServerObj is None:
            invalidateToken(AuthToken)
            return jsonify({"success": False, 'error': 'Invalid Token'}), 401

        return f(*args, **kwargs)
    return decorated_function

def gameserver_authenticated_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if "Roblox/" not in request.user_agent.string:
            abort(404)
        RemoteAddress = get_remote_address()
        GameServerObj : GameServer = GameServer.query.filter_by( serverIP = RemoteAddress ).first()
        if GameServerObj is None:
            abort(404)
        requesterAccessKey = request.headers.get( key = "AccessKey", type = str, default = "")
        if "UserRequest" in requesterAccessKey:
            logging.warning(f"GameServer {RemoteAddress} - UserRequest access key used for {request.url}")
            abort(404)
        return f(*args, **kwargs)
    return decorated_function

def gameserver_accesskey_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if "AccessKey" not in request.headers:
            abort(404)
        RequesterAccessKey = request.headers.get( key = "AccessKey", type = str, default = "")
        RemoteAddress = get_remote_address()
        GameServerObj : GameServer = GameServer.query.filter_by( serverIP = RemoteAddress, accessKey = RequesterAccessKey ).first()
        if GameServerObj is None:
            abort(404)
        return f(*args, **kwargs)
    return decorated_function

def invalidateToken(token : str):
    if token is not None:
        redis_controller.delete("authtoken_" + token)

def Validate2FACode( userid : int, code : str ) -> bool:
    from app.pages.settings.settings import generate_secret_key_from_string
    """
        Validates a 2FA code for a user

        :param userid: The user id to validate the code for
        :param code: The code to validate

        :returns: bool (True if correct, False if not)
    """
    user : User = User.query.filter_by(id=userid).first()
    if user is None:
        return False
    if user.TOTPEnabled == False:
        return False
    totp = pyotp.TOTP(generate_secret_key_from_string(str(user.id) + config.FLASK_SESSION_KEY))
    return totp.verify(code)
    
def GetCurrentUser() -> User:
    """
    Gets the current user from the request

    :returns: User (User object if logged in, None if not)
    """

    def _get_user() -> User:
        if ".ROBLOSECURITY" not in request.cookies:
            if "Syntax-Session-Id" not in request.cookies:
                return None
            else:
                DataSections = request.cookies["Syntax-Session-Id"].split("|")
            if len(DataSections) != 9:
                return None
            
            AuthToken = DataSections[8]
            if not ValidateToken(AuthToken):
                return None

            PlaceServerObj : PlaceServer = PlaceServer.query.filter_by(serveruuid=str(DataSections[1])).first()
            if PlaceServerObj is None:
                invalidateToken(AuthToken)
                return None
            
            AuthTokenInfo = GetTokenInfo(AuthToken)
            return User.query.filter_by(id=int(AuthTokenInfo[0])).first()
        if not ValidateToken(request.cookies[".ROBLOSECURITY"]):
            return None
        AuthTokenInfo = GetTokenInfo(request.cookies[".ROBLOSECURITY"])
        if AuthTokenInfo is None:
            return None
        return User.query.filter_by(id=int(AuthTokenInfo[0])).first()

    if not hasattr(g, 'current_authenticated_user'):
        g.current_authenticated_user = _get_user()
    return g.current_authenticated_user


def _GetArgonSalt( UserObj : User ) -> bytes:
    return (config.FLASK_SESSION_KEY + str(UserObj.id)).encode('utf-8')
def _GetPasswordHasher() -> PasswordHasher:
    return PasswordHasher(
        time_cost=16,
        memory_cost=2**14,
        parallelism=2,
        hash_len=32,
        salt_len=16
    )

def VerifyPassword( UserObj : User, password : str ) -> bool:
    """
        Verifies the password of the given user
    
        :param UserObj: The user object to verify the password of
        :param password: The password to verify

        :returns: bool (True if correct, False if not)
    """
    if config.SWITCH_TO_ARGON_PASSWORD_HASH: # Switch this when we migrate to argon
        argon_ph = _GetPasswordHasher()
        if not UserObj.password.startswith("$argon2id"): # Handle old passwords in sha512
            isCorrect = hashlib.sha512(password.encode('utf-8')).hexdigest() == UserObj.password
            if isCorrect:
                UserObj.password = PasswordHasher().hash(password, salt = _GetArgonSalt(UserObj) )
                logging.info(f"User {UserObj.username} [{UserObj.id}] migrated to argon2id password hash")
                db.session.commit()
            return isCorrect
        
        try:
            return argon_ph.verify(UserObj.password, password)
        except:
            return False
    else:
        return hashlib.sha512(password.encode('utf-8')).hexdigest() == UserObj.password
    
def SetPassword( UserObj : User, password : str ):
    """
        Sets the password of the given user

        :param UserObj: The user object to set the password of
        :param password: The password to set

        :returns: bool (True if successful, False if not)
    """
    if config.SWITCH_TO_ARGON_PASSWORD_HASH: # Switch this when we migrate to argon
        argon_ph = _GetPasswordHasher()
        UserObj.password = argon_ph.hash(password, salt = _GetArgonSalt(UserObj) )
    else:
        UserObj.password = hashlib.sha512(password.encode('utf-8')).hexdigest()
    
    db.session.commit()
    return True