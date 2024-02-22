from flask import Blueprint, render_template, request, redirect, url_for, session, flash, redirect, make_response, abort, Response
from app.models.user import User
from app.models.usereconomy import UserEconomy
from app.models.login_records import LoginRecord
from app.extensions import db, limiter, csrf, get_remote_address, redis_controller
import hashlib
from datetime import datetime, timedelta
from app.util import websiteFeatures, auth, turnstile
import time
import re
import random
import string
import uuid
from app.models.user_email import UserEmail
import requests
from requests.auth import HTTPBasicAuth
import json
from config import Config
import pyotp
from sqlalchemy import func

config = Config()

login = Blueprint("login", __name__, template_folder="pages")

def CreateLoginRecord( UserId : int, TokenOverwrite : str = None):
    """
        Logs the current user login to the database
        Please only call this function in a flask context
    """
    SessionToken = request.cookies.get(key="t", default=None, type=str)
    if SessionToken is None and TokenOverwrite is None:
        abort(400)
    if TokenOverwrite is not None:
        SessionToken = TokenOverwrite

    userIPHash = hashlib.sha512(
        string = f"{get_remote_address()}:SYNTAX:{config.FLASK_SESSION_KEY}".encode("utf-8")
    ).hexdigest()

    newLoginRecord : LoginRecord = LoginRecord(
        userid = UserId,
        ip = userIPHash,
        useragent = request.headers.get("User-Agent", default="Unknown")[:200],
        timestamp = datetime.utcnow(),
        session_token = SessionToken
    )
    db.session.add(newLoginRecord)
    db.session.commit()


@login.route("/login", methods=["GET"])
@limiter.exempt()
def login_page():
    if auth.isAuthenticated():
        return redirect("/home")
    
    loginEnabled = websiteFeatures.GetWebsiteFeature("WebLogin")
    if not loginEnabled:
        flash("Logins are temporarily disabled", "error")
    
    login_page_response = make_response(render_template("login/login.html", loginEnabled=loginEnabled))
    if request.cookies.get( key = ".ROBLOSECURITY", default = None, type = str ) is not None:
        login_page_response.set_cookie(
            key = ".ROBLOSECURITY",
            value = "",
            expires = 0,
            domain = f".{config.BaseDomain}"
        )
    return login_page_response

@login.errorhandler(429)
def ratelimit_handler(e):
    flash("You are being ratelimited.", "error")
    return redirect(request.referrer)

@login.route("/login", methods=["POST"])
@limiter.limit("10/minute")
def handle_login_post():
    if auth.isAuthenticated():
        return redirect("/home")
    
    requestUsername = request.form.get(
        key = "username",
        default = None,
        type = str
    )
    requestPassword = request.form.get(
        key = "password",
        default = None,
        type = str
    )
    isRequestStudio = request.args.get( key = "studio", default = 0, type = int ) == 1

    def handle_redirect() -> Response:
        if isRequestStudio:
            return redirect("/ide/welcome")
        else:
            return redirect(url_for("login.login_page"))

    if requestUsername is None or requestPassword is None:
        flash("Please fill in all fields", "error")
        return handle_redirect()
    
    loginEnabled = websiteFeatures.GetWebsiteFeature("WebLogin")
    if not loginEnabled:
        flash("Logins are temporarily disabled", "error")
        return handle_redirect()
    
    userObject : User = User.query.filter(func.lower(User.username) == func.lower(requestUsername)).first()
    if userObject is None:
        flash("Incorrect username or password", "error")
        return handle_redirect()
    if userObject.accountstatus == 4:
        flash("Invalid username or password", "error")
        return handle_redirect()
    
    if not auth.VerifyPassword( UserObj = userObject, password = requestPassword ):
        flash("Incorrect username or password", "error")
        return handle_redirect()
    
    if userObject.TOTPEnabled and not isRequestStudio:
        session["totpvalidatesession"] = {
            "userid": userObject.id,
            "startTime": time.time()
        }
        return redirect("/login/totpvalidate")
    elif userObject.TOTPEnabled and isRequestStudio:
        TOTPCode = request.form.get( key = "2fa", default = None, type = str )
        if TOTPCode is None:
            flash("Please fill in all fields", "error")
            return handle_redirect()
        
        if len(TOTPCode) != 6:
            flash("Invalid 2FA Code", "error")
            return handle_redirect()
        
        isValidCode = auth.Validate2FACode( userid = userObject.id, code = TOTPCode )
        if not isValidCode:
            flash("Invalid 2FA Code", "error")
            return handle_redirect()
        
    if userObject.accountstatus != 1:
        session["not-approved-viewer"] = userObject.id
        return redirect("/not-approved")
    
    newAuthToken : str = auth.CreateToken( userid = userObject.id, ip = get_remote_address() )
    authenticatedResponse : Response = make_response( redirect("/home") )
    authenticatedResponse.set_cookie(
        key = ".ROBLOSECURITY",
        value = newAuthToken,
        expires = datetime.utcnow() + timedelta( days = 31 ),
        domain = f".{config.BaseDomain}"
    )

    if request.cookies.get( key = "t", default = None, type = str ) is None:
        newToken : str = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(128))
        authenticatedResponse.set_cookie(
            key = "t",
            value = newToken,
            expires = datetime.utcnow() + timedelta( days = 365 ),
            domain = f".{config.BaseDomain}"
        )
        CreateLoginRecord( UserId = userObject.id, TokenOverwrite = newToken )
    else:
        CreateLoginRecord( UserId = userObject.id )

    return authenticatedResponse

# @login.route("/login", methods=["POST"])
# @limiter.limit("10/minute")
# def login_post():
#     if auth.isAuthenticated():
#         return redirect("/home")
#     username = request.form.get("username")
#     password = request.form.get("password")
#     isstudio = request.args.get("studio", default=0, type=int)
#     csrf.protect()

#     loginEnabled = websiteFeatures.GetWebsiteFeature("WebLogin")
#     if not loginEnabled:
#         flash("Logins are temporarily disabled", "error")
#         if isstudio == 0:
#             return redirect(url_for("login.login_page"))
#         else:
#             return redirect("/ide/welcome")

#     if username is None or password is None:
#         flash("Please fill in all fields", "error")
#         if isstudio == 0:
#             return redirect(url_for("login.login_page"))
#         else:
#             return redirect("/ide/welcome")

#     user : User = User.query.filter_by(username=username).first()
#     if user is None:
#         flash("Incorrect username or password", "error")
#         if isstudio == 0:
#             return redirect(url_for("login.login_page"))
#         else:
#             return redirect("/ide/welcome")
        
#     if user.accountstatus == 4: # GDPR Deletion
#         flash("Invalid username or password", "error")
#         if isstudio == 0:
#             return redirect(url_for("login.login_page"))

#     if not auth.VerifyPassword( UserObj = user, password = password ):
#         flash("Incorrect username or password", "error")
#         if isstudio == 0:
#             return redirect(url_for("login.login_page"))
#         else:
#             return redirect("/ide/welcome")

#     # check if user has 2fa enabled
#     if user.TOTPEnabled:
#         if isstudio == 0:
#             session["totpvalidatesession"] = {
#                 "userid": user.id,
#                 "startTime": time.time()
#             }
#             return redirect("/login/totpvalidate")
#         else:
#             TOTPCode = request.form.get("2fa")
#             if TOTPCode is None:
#                 flash("Please fill in all fields", "error")
#                 return redirect("/ide/welcome")
#             if len(TOTPCode) != 6:
#                 flash("Invalid 2FA Code")
#                 return redirect("/ide/welcome", "error")
#             isValidCode = auth.Validate2FACode(user.id, TOTPCode)
#             if not isValidCode:
#                 flash("Invalid 2FA Code")
#                 return redirect("/ide/welcome", "error")
    
#     if user.accountstatus != 1:
#         session["not-approved-viewer"] = user.id
#         return redirect("/not-approved")
    
#     # Create new session token
#     sessionToken = auth.CreateToken(userid=user.id, ip=get_remote_address())
#     if isstudio == 0:
#         resp = make_response(redirect("/home"))
#     else:
#         resp = make_response(redirect("/ide/welcome"))
#     resp.set_cookie(".ROBLOSECURITY", sessionToken, expires=datetime.utcnow() + timedelta(days=365))
#     if request.cookies.get("t", default=None, type=str) is not None:
#         NewToken = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(128))
#         resp.set_cookie("t", NewToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")
#         CreateLoginRecord( user.id, NewToken )
#     else:
#         CreateLoginRecord( user.id )
#     return resp

@login.route("/login/totpvalidate", methods=["GET"])
def totp_validate():
    if "totpvalidatesession" not in session:
        return redirect("/login")
    if time.time() - session["totpvalidatesession"]["startTime"] > 180:
        del session["totpvalidatesession"]
        flash("Session expired", "error")
        return redirect("/login")
    return render_template("login/totpvalidate.html")

@login.route("/login/totpvalidate", methods=["POST"])
def totp_validate_post():
    from app.pages.settings.settings import generate_secret_key_from_string
    if "totpvalidatesession" not in session:
        return redirect("/login")
    if time.time() - session["totpvalidatesession"]["startTime"] > 180:
        del session["totpvalidatesession"]
        flash("Session expired", "error")
        return redirect("/login")
    csrf.protect()
    totpCode = request.form.get("totpCode")
    if totpCode is None:
        flash("Please fill in all fields")
        return redirect("/login/totpvalidate")
    if len(totpCode) != 6:
        flash("Invalid TOTP Code")
        return redirect("/login/totpvalidate")
    user : User = User.query.filter_by(id=session["totpvalidatesession"]["userid"]).first()
    if user is None:
        flash("User not found")
        return redirect("/login/totpvalidate")
    totp = pyotp.TOTP(generate_secret_key_from_string(str(user.id) + config.FLASK_SESSION_KEY))
    if not totp.verify(totpCode):
        flash("Invalid TOTP Code")
        return redirect("/login/totpvalidate")
    if user.accountstatus != 1:
        session["not-approved-viewer"] = user.id
        return redirect("/not-approved")

    sessionToken = auth.CreateToken(userid=user.id, ip=get_remote_address())
    resp = make_response(redirect("/home"))
    resp.set_cookie(".ROBLOSECURITY", sessionToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")
    del session["totpvalidatesession"]
    if request.cookies.get("t", default=None, type=str) is not None:
        NewToken = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(128))
        resp.set_cookie("t", NewToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")
        CreateLoginRecord( user.id, NewToken )
    else:
        CreateLoginRecord( user.id )
    return resp


@login.route("/logout", methods=["POST"])
def logout():
    if not auth.isAuthenticated():
        return redirect("/login")
    
    auth.invalidateToken(request.cookies.get(".ROBLOSECURITY"))
    resp = make_response(redirect("/login"))
    resp.set_cookie(".ROBLOSECURITY", "", expires=0)

    if "not-approved-viewer" in session:
        del session["not-approved-viewer"]
    return resp

@login.route("/reset-password", methods=["GET"])
def reset_password():
    if auth.isAuthenticated():
        return redirect("/home")
    return render_template("login/send_reset.html")

EmailRegex = r"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$" # RFC 5322 Compliant, because some fucker is gonna complain that he cant verify his email from his self-hosted shit

@login.route("/reset-password", methods=["POST"])
@limiter.limit("10/minute")
def reset_password_post():
    if auth.isAuthenticated():
        return redirect("/home")
    if not websiteFeatures.GetWebsiteFeature("SendResetPassword"):
        flash("Resetting Passwords is temporarily disabled, please try again later", "error")
        return redirect("/reset-password")
    user_email = request.form.get( key = "email", default = None, type = str )
    if user_email is None:
        flash("Please fill in all fields", "error")
        return redirect("/reset-password")
    user_email = user_email.strip().lower()

    if not re.match( EmailRegex, user_email ):
        flash("Invalid Email", "error")
        return redirect("/reset-password")

    RequesterAddress = get_remote_address()
    if redis_controller.exists(f"reset_password_cooldown_v1:{RequesterAddress}"):
        flash("You sent a reset request too recently please wait and try again later", "error")
        return redirect("/reset-password")
    if redis_controller.exists(f"reset_password_email_cooldown_v1:{user_email}"):
        flash("This email has recently been sent a reset request, please wait and try again later", "error")
        return redirect("/reset-password")
    CloudflareTurnstileKey = request.form.get( key = "cf-turnstile-response", default = None, type=str )
    if CloudflareTurnstileKey is None or CloudflareTurnstileKey == '':
        flash("Please complete the captcha", "error")
        return redirect("/reset-password")
    if not turnstile.VerifyToken( CloudflareTurnstileKey ):
        flash("Invalid captcha answer", "error")
        return redirect("/reset-password")

    UserEmailObj : UserEmail = UserEmail.query.filter_by(email = user_email, verified=True).first()
    if UserEmailObj:
        ResetPasswordUUID = str(uuid.uuid4())
        redis_controller.set(f"reset_password_v1:{ResetPasswordUUID}", UserEmailObj.email, ex=60 * 60 * 2)
        emailHash = hashlib.sha1(f"{user_email}:{config.FLASK_SESSION_KEY}".encode("utf-8")).hexdigest()
        resetLink = f"{config.BaseURL}/reset-password/confirm?uuid={ResetPasswordUUID}&confirm={emailHash}"

        EmailData = {
            "Messages": [
                {
                    "From": {
                        "Email": Config.MAILJET_NOREPLY_SENDER,
                        "Name": "syntax.eco"
                    },
                    "To": [
                        {
                            "Email": user_email,
                            "Name": "SYNTAX User"
                        }
                    ],
                    "TemplateID": Config.MAILJET_PASSWORDRESET_TEMPLATE_ID,
                    "TemplateLanguage": True,
                    "Subject": f"SYNTAX - Reset Password",
                    "Variables": {
                        "verificationlink": resetLink
                    }
                }
            ]
        }

        try:
            EmailResponse = requests.post(
                url="https://api.mailjet.com/v3.1/send",
                data=json.dumps(EmailData),
                headers={
                    "Content-Type": "application/json"
                },
                auth = HTTPBasicAuth(
                    Config.MAILJET_APIKEY,
                    Config.MAILJET_SECRETKEY
                )
            )
            if EmailResponse.status_code != 200:
                flash("An error occured while sending the email, please try again later", "error")
                redis_controller.delete(f"reset_password_v1:{ResetPasswordUUID}")
                return redirect("/reset-password")
        except Exception as e:
            flash("An error occured while sending the email, please try again later", "error")
            redis_controller.delete(f"reset_password_v1:{ResetPasswordUUID}")
            return redirect("/reset-password")

    redis_controller.set(f"reset_password_cooldown_v1:{RequesterAddress}", 1, ex=60 * 60)
    redis_controller.set(f"reset_password_email_cooldown_v1:{user_email}", 1, ex=60 * 60)

    flash("A reset password email has been sent if the email is linked to a SYNTAX account", "success")
    return redirect("/reset-password")

@login.route("/reset-password/confirm", methods=["GET"])
def reset_password_confirm():
    uuid = request.args.get("uuid", default=None, type=str)
    confirm = request.args.get("confirm", default=None, type=str)
    if uuid is None or confirm is None:
        flash("Invalid reset link", "error")
        return redirect("/reset-password")
    if not redis_controller.exists(f"reset_password_v1:{uuid}"):
        flash("Invalid reset link", "error")
        return redirect("/reset-password")
    email = redis_controller.get(f"reset_password_v1:{uuid}")
    emailHash = hashlib.sha1(f"{email}:{config.FLASK_SESSION_KEY}".encode("utf-8")).hexdigest()
    if emailHash != confirm:
        flash("Invalid reset link", "error")
        return redirect("/reset-password")
    
    AllLinkedEmails : list[UserEmail] = UserEmail.query.filter_by(email = email).all()
    if len(AllLinkedEmails) == 0:
        flash("Invalid reset link", "error")
        return redirect("/reset-password")

    return render_template("login/reset_password.html", AllLinkedEmails=AllLinkedEmails)

@login.route("/reset-password/confirm", methods=["POST"])
def reset_password_confirm_post():
    uuid = request.args.get("uuid", default=None, type=str)
    confirm = request.args.get("confirm", default=None, type=str)
    if uuid is None or confirm is None:
        flash("Invalid reset link", "error")
        return redirect("/reset-password")
    if not redis_controller.exists(f"reset_password_v1:{uuid}"):
        flash("Invalid reset link", "error")
        return redirect("/reset-password")
    email = redis_controller.get(f"reset_password_v1:{uuid}")
    emailHash = hashlib.sha1(f"{email}:{config.FLASK_SESSION_KEY}".encode("utf-8")).hexdigest()
    if emailHash != confirm:
        flash("Invalid reset link", "error")
        return redirect("/reset-password")
    
    reset_user_id = request.form.get("reset_user_id", default=None, type=int)
    reset_password = request.form.get("reset_password", default=None, type=str)
    if reset_user_id is None or reset_password is None:
        flash("Please fill in all fields", "error")
        return redirect(f"/reset-password/confirm?uuid={uuid}&confirm={confirm}")
    
    UserEmailObj : UserEmail = UserEmail.query.filter_by(email = email, user_id = reset_user_id, verified=True).first()
    if UserEmailObj is None:
        flash("Invalid User Choice", "error")
        return redirect(f"/reset-password/confirm?uuid={uuid}&confirm={confirm}")
    
    UserObj : User = UserEmailObj.user
    if len(reset_password) < 8:
        flash("Password must be at least 8 characters long", "error")
        return redirect(f"/reset-password/confirm?uuid={uuid}&confirm={confirm}")

    auth.SetPassword(UserObj, reset_password)
    redis_controller.delete(f"reset_password_v1:{uuid}")

    flash("Password reset successfully", "success")
    return redirect("/login") 
