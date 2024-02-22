from flask import Blueprint, render_template, request, redirect, url_for, session, flash, redirect, make_response, abort
from app.models.user import User
from app.models.invite_key import InviteKey
from app.models.usereconomy import UserEconomy
from app.models.user_avatar import UserAvatar
from app.models.login_records import LoginRecord
from app.util.textfilter import FilterText, TextNotAllowedException
from app.models.past_usernames import PastUsername
from app.pages.login.login import CreateLoginRecord
from app.extensions import db, limiter, csrf, redis_controller, get_remote_address
from app.pages.avatar.avatar import AllowedBodyColors
from app.routes.thumbnailer import TakeUserThumbnail
import logging
import hashlib
from datetime import datetime
from app.util import websiteFeatures, auth, turnstile, redislock
from app.services import invitekeys, proxydetection
from sqlalchemy import func
import random
from datetime import datetime, timedelta
from config import Config
import string

config = Config()
signup = Blueprint("signup", __name__, template_folder="pages")

@signup.route("/signup", methods=["GET"])
@limiter.exempt()
def signup_page():
    if auth.isAuthenticated():
        return redirect("/home")
    SignupEnabled = True
    if not websiteFeatures.GetWebsiteFeature("WebSignup"):
        flash("Signups are temporarily disabled")
        SignupEnabled = False
    return render_template("signup/signup.html", SignupEnabled=SignupEnabled)

def RateLimitReached(e):
    flash("You are being rate limited. Please try again later.")
    return redirect("/signup")

def isUsernameAllowed( username : str ):
    if len(username) < 3 or len(username) > 20:
        return False, "Usernames must be between 3 and 20 characters long" 
    
    if username[0] == "_" or username[-1] == "_":
        return False, "Usernames must not start or end with an underscore"
    
    if username.count("_") > 1:
        return False, "Usernames must not contain more than one underscore"
    
    if username.count(" ") > 0:
        return False, "Usernames must not contain spaces"
    
    allowedCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    hasLetter = False
    for char in username:
        if char not in allowedCharacters:
            return False, "Usernames must only contain letters, numbers and underscores"
        if char in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ":
            hasLetter = True

    if not hasLetter:
        return False, "Usernames must contain at least one letter"
    
    return True, "Allowed"

@signup.route("/signup", methods=["POST"])
@limiter.limit("10/minute", on_breach=RateLimitReached)
def signup_post():
    if auth.isAuthenticated():
        return redirect("/home")
    username = request.form.get("username", default=None, type=str)
    password = request.form.get("password", default=None, type=str)
    agreedtoTerms = request.form.get("agreetoTermsandPrivacy", default="off", type=str) == "on"
    #invitekey = request.form.get("invite-key", default=None, type=str)

    if not websiteFeatures.GetWebsiteFeature("WebSignup"):
        flash("Signups are temporarily disabled")
        return redirect("/signup")
    if 'cf-turnstile-response' not in request.form or request.form.get('cf-turnstile-response') == '':
        flash("Please complete the captcha", "error")
        return redirect("/signup")

    if username is None or password is None: #or invitekey is None:
        flash("Please fill in all fields")
        return redirect("/signup")

    if not agreedtoTerms:
        flash("You must agree to the Terms of service and privacy policy")
        return redirect("/signup")
    
    allowed, reason = isUsernameAllowed(username)
    if not allowed:
        flash(reason)
        return redirect("/signup")
    
    if len(password) < 8:
        flash("Password must be at least 8 characters long")
        return redirect("/signup")

    try:
        FilterText( Text = username, ThrowException = True, UseExtendedBadWords=True)
    except TextNotAllowedException:
        flash("Username is not friendly for Syntax")
        return redirect("/signup")
    
    RequestAddressRisk : int = proxydetection.fetch_address_risk( get_remote_address() )
    if RequestAddressRisk == 1:
        flash("Please disable your VPN or proxy and try again")
        return redirect("/signup")

    if RequestAddressRisk == 3:
        flash("Error 255, please report in our discord.") # We want to be as vague as possible 
        return redirect("/signup")
    redisResultIP = redis_controller.get("signupcooldown:" + get_remote_address())
    redisResultToken = None
    if request.cookies.get("t", default=None, type=str) is not None:
        redisResultToken = redis_controller.get("signupcooldown:token:" + str(request.cookies.get(key="t", default=None, type=str)))

    if redisResultIP is not None or redisResultToken is not None:
        if redisResultIP is None:
            redis_controller.set("signupcooldown:" + get_remote_address(), "1", ex=60*60*24*7)
        if redisResultToken is None and request.cookies.get("t", default=None, type=str) is not None:
            redis_controller.set("signupcooldown:token:" + str(request.cookies.get(key="t", default=None, type=str)), "1", ex=60*60*24*7)
        
        flash("You have recently made an account in the past 7 days.")
        return redirect("/signup")
    
    SessionToken = request.cookies.get(key="t", default=None, type=str)
    if SessionToken is None:
        flash("An issue occured while creating your account. Please try again later.")
        return redirect("/signup")
    if len(SessionToken) != 128:
        flash("An issue occured while creating your account. Please try again later.")
        return redirect("/signup")
    for char in SessionToken:
        if char not in (string.ascii_letters + string.digits):
            flash("An issue occured while creating your account. Please try again later.")
            return redirect("/signup")

    UserIPHash = hashlib.md5(get_remote_address().encode("utf-8")).hexdigest()
    LoginRecords : list[LoginRecord] = LoginRecord.query.filter(LoginRecord.ip == UserIPHash).distinct(LoginRecord.userid).all()
    for record in LoginRecords:
        if record.User.accountstatus != 1:
            if record.session_token != SessionToken:
                NewLoginRecord = LoginRecord(
                    userid = record.userid,
                    ip = UserIPHash,
                    session_token = SessionToken,
                    useragent = request.headers.get("User-Agent"),
                    timestamp = datetime.utcnow()
                )
                db.session.add(NewLoginRecord)
                db.session.commit()

            flash("An issue occured while creating your account. Please try again later.")
            return redirect("/signup")
    LoginRecords : list[LoginRecord] = LoginRecord.query.filter(LoginRecord.session_token == SessionToken).distinct(LoginRecord.userid).all()
    for record in LoginRecords:
        if record.User.accountstatus != 1:
            NewLoginRecord = LoginRecord(
                userid = record.userid,
                ip = UserIPHash,
                session_token = SessionToken,
                useragent = request.headers.get("User-Agent"),
                timestamp = datetime.utcnow()
            )
            db.session.add(NewLoginRecord)
            db.session.commit()

            flash("An issue occured while creating your account. Please try again later.")
            return redirect("/signup")
    
    UserSignupLock = redislock.acquire_lock("UserSignupLock", acquire_timeout = 20, lock_timeout=1)
    if not UserSignupLock:
        flash("An issue occured while creating your account. Please try again later.")
        return redirect("/signup")

    user = User.query.filter(func.lower(User.username) == func.lower(username)).first()
    if user is not None:
        redislock.release_lock("UserSignupLock", UserSignupLock)
        flash("Username already taken")
        return redirect("/signup")
    
    pastUsername = PastUsername.query.filter(func.lower(PastUsername.username) == func.lower(username)).first()
    if pastUsername is not None:
        redislock.release_lock("UserSignupLock", UserSignupLock)
        flash("Username already taken")
        return redirect("/signup")
    
    # try:
    #     inviteKey : InviteKey = invitekeys.GetInviteKey(invitekey)
    # except invitekeys.InviteExceptions.InvalidInviteKey:
    #     redislock.release_lock("UserSignupLock", UserSignupLock)
    #     flash("Invalid invite key")
    #     return redirect("/signup")
    # if inviteKey.used_by is not None:
    #     redislock.release_lock("UserSignupLock", UserSignupLock)
    #     flash("Invite key already used")
    #     return redirect("/signup")
    # InviteKeyCreator : User = User.query.filter_by(id=inviteKey.created_by).first()
    # if InviteKeyCreator is not None:
    #     if InviteKeyCreator.accountstatus != 1:
    #         redislock.release_lock("UserSignupLock", UserSignupLock)
    #         flash("Invite key creator's account is banned")
    #         return redirect("/signup")
    
    if not turnstile.VerifyToken(request.form.get('cf-turnstile-response')):
        redislock.release_lock("UserSignupLock", UserSignupLock)
        flash("Invalid captcha", "error")

    if request.cookies.get(key="t", default=None, type=str) is None:
        abort(400)
    
    redis_controller.set("signupcooldown:" + get_remote_address(), "1", ex=60*60*24*7)
    if request.cookies.get("t", default=None, type=str) is not None:
        redis_controller.set("signupcooldown:token:" + str(request.cookies.get(key="t", default=None, type=str)), "1", ex=60*60*24*7)
    
    NewRegisteredUser : User = User(
        username = username,
        password = "",
        created = datetime.utcnow(),
        lastonline = datetime.utcnow(),
    )

    db.session.add(NewRegisteredUser)
    db.session.commit()

    auth.SetPassword(NewRegisteredUser, password)

    userEconomy = UserEconomy(
        userid = NewRegisteredUser.id,
        robux = 0,
        tix = 0
    )
    db.session.add(userEconomy)

    userAvatar : UserAvatar = UserAvatar(
        user_id=NewRegisteredUser.id
    )
    userAvatar.torso_color_id = random.choice(AllowedBodyColors)
    db.session.add(userAvatar)

    #invitekeys.UseInviteKey(invitekey, NewRegisteredUser)

    db.session.commit()
    redislock.release_lock("UserSignupLock", UserSignupLock)
    logging.info(f"New user registered: {NewRegisteredUser.username} ({NewRegisteredUser.id})")
    
    TakeUserThumbnail(NewRegisteredUser.id)
    sessionToken = auth.CreateToken(userid=NewRegisteredUser.id, ip=get_remote_address())
    resp = make_response(redirect("/home"))
    resp.set_cookie(".ROBLOSECURITY", sessionToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")

    if request.cookies.get("t", default=None, type=str) is not None:
        NewToken = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(128))
        resp.set_cookie("t", NewToken, expires=datetime.utcnow() + timedelta(days=365), domain=f".{config.BaseDomain}")
        CreateLoginRecord( NewRegisteredUser.id, NewToken )
    else:
        CreateLoginRecord( NewRegisteredUser.id )

    return resp