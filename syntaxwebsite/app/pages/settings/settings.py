import base64
import hashlib
import pyotp
import random
import re
import logging
import requests
import uuid
import json

from app.util.discord import DiscordUserInfo, ExchangeCodeForToken, UnexpectedStatusCode, MissingScope, GetUserInfoFromToken, GenerateAuthorizationURL
from app.models.linked_discord import LinkedDiscord
from app.models.user_email import UserEmail
from app.pages.signup.signup import isUsernameAllowed
from app.models.past_usernames import PastUsername
from app.util.redislock import acquire_lock, release_lock
from app.models.usereconomy import UserEconomy
from datetime import datetime, timedelta
from app.pages.messages.messages import CreateSystemMessage
from app.util.membership import GetUserMembership, GiveUserMembership, UserHasHigherMembershipException, UserDoesNotExistException, RemoveUserMembership
from app.enums.MembershipType import MembershipType
from flask import Blueprint, render_template, request, redirect, url_for, session, flash, redirect, make_response, abort
from app.util import auth, websiteFeatures, textfilter, turnstile, transactions
from app.extensions import db, limiter, redis_controller
from app.models.user import User
from requests.auth import HTTPBasicAuth
from config import Config
from app.models.asset import Asset
from app.models.userassets import UserAsset
from sqlalchemy import func
from app.services import economy
from app.enums.TransactionType import TransactionType

config = Config()

def generate_secret_key_from_string(secret_string):
    secret_bytes = secret_string.encode('utf-8')
    char_list = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    random.seed(secret_bytes)
    secret_key = ''.join([random.choice(char_list) for _ in range(32)])
    return secret_key

settings = Blueprint("settings", __name__, template_folder="pages")

@settings.route("/settings", methods=["GET"])
@auth.authenticated_required
def settings_page():
    user : User = auth.GetCurrentUser()
    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(user_id=user.id).first()
    if LinkedDiscordObj is not None:
        DiscordUserInfoObj : DiscordUserInfo = DiscordUserInfo(LinkedDiscordObj.discord_id, LinkedDiscordObj.discord_username, LinkedDiscordObj.discord_avatar, GlobalName = None, Discriminator = LinkedDiscordObj.discord_discriminator)
    else:
        DiscordUserInfoObj = None
    LinkedEmailObj : UserEmail = UserEmail.query.filter_by(user_id=user.id).first()
    HiddenEmail = None
    if LinkedEmailObj:
        emailParts = LinkedEmailObj.email.split("@")
        FirstPart = emailParts[0][0] + "*" * (len(emailParts[0])-1)
        SecondPart = emailParts[1]
        HiddenEmail = FirstPart + "@" + SecondPart 
    return render_template("settings/settings.html", TOTPenabled = user.TOTPEnabled, description=user.description, DiscordUserInfoObj=DiscordUserInfoObj, LinkedEmailObj=LinkedEmailObj, HiddenEmail=HiddenEmail)

@settings.route("/settings/description", methods=["POST"])
@auth.authenticated_required
def settings_description():
    description = request.form.get("description")
    if description is None:
        return redirect("/settings")
    if len(description) > 256:
        flash("Description is too long")
        return redirect("/settings")
    
    newlineCount = description.count("\n")
    if newlineCount > 5:
        flash("Description can only have 5 lines")
        return redirect("/settings")
    user : User = auth.GetCurrentUser()
    user.description = textfilter.FilterText(description)
    db.session.commit()
    return redirect("/settings")


@settings.route("/settings/enableTOTP", methods=["GET"])
@auth.authenticated_required
def settings_enableTOTP():
    return render_template("settings/enableTOTP.html")

@settings.route("/settings/enableTOTP", methods=["POST"])
@auth.authenticated_required
def settings_enableTOTP_post():
    if "code" not in request.form:
        flash("Please fill in all fields")
        return redirect("/settings/enableTOTP")
    code = request.form.get("code")
    user : User = auth.GetCurrentUser()
    if user.TOTPEnabled:
        return redirect("/settings")
    
    secret_key = generate_secret_key_from_string(str(user.id) + config.FLASK_SESSION_KEY)
    totp = pyotp.TOTP(secret_key)
    if not totp.verify(code):
        flash("Invalid code")
        return redirect("/settings/enableTOTP")
    
    user.TOTPEnabled = True
    db.session.commit()
    return redirect("/settings")

@settings.route("/settings/TOTP/image", methods=["GET"])
@auth.authenticated_required
def settings_TOTP_image():
    user : User = auth.GetCurrentUser()
    if user.TOTPEnabled:
        return redirect("/settings")
    secret_key = generate_secret_key_from_string(str(user.id) + config.FLASK_SESSION_KEY)
    import pyqrcode
    totp = pyotp.TOTP(secret_key)

    url = pyqrcode.create(totp.provisioning_uri(user.username, issuer_name="Syntax"))
    resp = make_response(base64.b64decode(url.png_as_base64_str(scale=5)))
    resp.headers['Content-Type'] = 'image/png'
    return resp

import hashlib

def GenerateStateHash( Cookie : str ) -> str:
    """
    GenerateStateHash generates a state hash for discord oauth2.
    """
    salted_cookie = Cookie + config.FLASK_SESSION_KEY
    return hashlib.md5(salted_cookie.encode('utf-8')).hexdigest()

@settings.route("/settings/unlink_discord", methods=["POST"])
@auth.authenticated_required
def settings_unlink_discord():
    AuthenticatedUser : User = auth.GetCurrentUser()
    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(user_id=AuthenticatedUser.id).first()
    if LinkedDiscordObj is None:
        flash("You do not have a linked discord account")
        return redirect("/settings")
    
    if LinkedDiscordObj.linked_on + timedelta(hours=24) > datetime.utcnow():
        flash("You cannot unlink your discord account until 24 hours after linking")
        return redirect("/settings")
    db.session.delete(LinkedDiscordObj)
    db.session.commit()

    UserMembership : MembershipType = GetUserMembership(AuthenticatedUser)
    if UserMembership == MembershipType.BuildersClub:
        RemoveUserMembership(AuthenticatedUser)
    
    flash("Discord account unlinked")
    return redirect("/settings")

@settings.route("/settings/discord_link", methods=["GET"])
@auth.authenticated_required
def settings_discord_link():
    if not websiteFeatures.GetWebsiteFeature("UsernameChange"):
        flash("Discord Linking is temporarily disabled")
        return redirect("/settings")
    
    UserObj : User = auth.GetCurrentUser()
    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(user_id=UserObj.id).first()
    if LinkedDiscordObj is not None:
        return redirect("/settings")
    state = GenerateStateHash(request.cookies[".ROBLOSECURITY"])
    AuthorizationURL = GenerateAuthorizationURL(state)
    return redirect(AuthorizationURL)

@settings.route("/settings/discord_handler", methods=["GET"])
@auth.authenticated_required
def settings_discord_handler():
    if not websiteFeatures.GetWebsiteFeature("UsernameChange"):
        flash("Discord Linking is temporarily disabled")
        return redirect("/settings")
    UserObj : User = auth.GetCurrentUser()
    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(user_id=UserObj.id).first()
    if LinkedDiscordObj is not None:
        flash("You already have a linked discord account")
        return redirect("/settings")
    expectedState = GenerateStateHash(request.cookies[".ROBLOSECURITY"])
    givenState = request.args.get(key="state", default=None, type=str)
    if givenState is None:
        flash("Invalid state")
        return redirect("/settings")
    if givenState != expectedState:
        flash("Invalid state")
        return redirect("/settings")
    givenCode = request.args.get(key="code", default=None, type=str)
    if givenCode is None:
        flash("Invalid code")
        return redirect("/settings")
    try:
        DiscordOAuth2TokenExchangeResponseJSON = ExchangeCodeForToken(givenCode)
    except UnexpectedStatusCode as e:
        flash(f"UnexpectedStatusCodeException: {str(e)}")
        return redirect("/settings")
    except MissingScope as e:
        flash(f"MissingScopeException: {str(e)}")
        return redirect("/settings")
    try:
        DiscordUserInfoObj : DiscordUserInfo = GetUserInfoFromToken(DiscordOAuth2TokenExchangeResponseJSON["access_token"])
    except UnexpectedStatusCode as e:
        flash(f"UnexpectedStatusCodeException: {str(e)}")
        return redirect("/settings")
    
    DiscordAccountCreationDatetime = datetime.utcfromtimestamp( ( (int(DiscordUserInfoObj.UserId) >> 22) + 1420070400000) / 1000 )
    if DiscordAccountCreationDatetime + timedelta(days=7) > datetime.utcnow():
        flash("Discord account must be at least 7 days old")
        return redirect("/settings")
    
    LinkedDiscordObj : LinkedDiscord = LinkedDiscord.query.filter_by(discord_id=DiscordUserInfoObj.UserId).first()
    if LinkedDiscordObj is not None:
        if LinkedDiscordObj.linked_on + timedelta(hours=24) > datetime.utcnow():
            flash("This discord account has recently been linked to another account, please try again later")
            return redirect("/settings")
        try:
            CreateSystemMessage(
                subject = "Discord Account unlinked",
                message = f"Your discord account was unlinked from your account because \"Account linked to another user\", if you currently have a Builders Club membership it will be automatically removed from your account until you link your discord account again.",
                userid = LinkedDiscordObj.user_id
            )
            OldUserMembership : MembershipType = GetUserMembership(LinkedDiscordObj.user_id)
            if OldUserMembership == MembershipType.BuildersClub:
                RemoveUserMembership(LinkedDiscordObj.user_id)
        except:
            pass
        db.session.delete(LinkedDiscordObj)
        db.session.commit()
    NewLinkedDiscordObj = LinkedDiscord(
        user_id=UserObj.id,
        discord_id=DiscordUserInfoObj.UserId,
        discord_username=DiscordUserInfoObj.Username,
        discord_discriminator=DiscordUserInfoObj.Discriminator,
        discord_avatar=DiscordUserInfoObj.AvatarHash,
        discord_access_token=DiscordOAuth2TokenExchangeResponseJSON["access_token"],
        discord_refresh_token=DiscordOAuth2TokenExchangeResponseJSON["refresh_token"],
        discord_expiry=datetime.utcnow() + timedelta(seconds=DiscordOAuth2TokenExchangeResponseJSON["expires_in"])
    )
    db.session.add(NewLinkedDiscordObj)
    db.session.commit()

    CurrentUserMembership : MembershipType = GetUserMembership(UserObj)
    if CurrentUserMembership == MembershipType.NonBuildersClub:
        try:
            GiveUserMembership(UserObj, MembershipType.BuildersClub, expiration=timedelta(days=31))
        except Exception as e:
            logging.error(f"Failed to give user builders club membership: {str(e)}")
            return redirect("/settings")

    return redirect("/settings")

@settings.route("/settings/update-password", methods=["GET"])
@auth.authenticated_required
def settings_update_password():
    if not websiteFeatures.GetWebsiteFeature("PasswordChange"):
        flash("Password changing is temporarily disabled")
        return redirect("/settings")

    AuthenticatedUser : User = auth.GetCurrentUser()
    return render_template("settings/changepassword.html", is2FAEnabled = AuthenticatedUser.TOTPEnabled)

@settings.route("/settings/update-password", methods=["POST"])
@auth.authenticated_required
@limiter.limit("20/minute")
def settings_update_password_post():
    if not websiteFeatures.GetWebsiteFeature("PasswordChange"):
        flash("Password changing is temporarily disabled")
        return redirect("/settings")

    AuthenticatedUser : User = auth.GetCurrentUser()

    CurrentPassword = request.form.get( key = "current-password", default = "", type = str )
    NewPassword = request.form.get( key = "new-password", default = "", type = str )
    NewPasswordConfirm = request.form.get( key = "confirm-password", default = "", type = str )

    OTPCode = request.form.get( key = "2fa-code", default = None, type = str )

    if AuthenticatedUser.TOTPEnabled:
        if OTPCode is None:
            flash("Please fill in all fields")
            return redirect("/settings/update-password")
        isValidCode = auth.Validate2FACode(AuthenticatedUser.id, OTPCode)
        if not isValidCode:
            flash("Invalid 2FA code")
            return redirect("/settings/update-password")

    if not auth.VerifyPassword(AuthenticatedUser, CurrentPassword):
        flash("Invalid current password")
        return redirect("/settings/update-password")
    
    if NewPassword != NewPasswordConfirm:
        flash("Passwords do not match")
        return redirect("/settings/update-password")
    
    if len(NewPassword) < 8:
        flash("Password must be at least 8 characters")
        return redirect("/settings/update-password")
    
    if len(NewPassword) > 256:
        flash("Password cannot be longer than 256 characters")
        return redirect("/settings/update-password")

    auth.SetPassword(AuthenticatedUser, NewPassword)

    flash("Password updated")
    return redirect("/settings")

@settings.route("/settings/update-username", methods=["GET"])
@auth.authenticated_required
def settings_update_username():
    if not websiteFeatures.GetWebsiteFeature("UsernameChange"):
        flash("Username changing is temporarily disabled")
        return redirect("/settings")
    return render_template("settings/changeusername.html")

@settings.route("/settings/update-username", methods=["POST"])
@auth.authenticated_required
@limiter.limit("20/minute")
def settings_update_username_post():
    if not websiteFeatures.GetWebsiteFeature("UsernameChange"):
        flash("Username changing is temporarily disabled")
        return redirect("/settings")
    AuthenticatedUser : User = auth.GetCurrentUser()

    NewUsername = request.form.get( key = "new-username", default = "", type = str )
    Password = request.form.get( key = "password", default = "", type = str )

    if not auth.VerifyPassword(AuthenticatedUser, Password):
        flash("Incorrect password")
        return redirect("/settings/update-password")
    
    isValidUsername , Reason = isUsernameAllowed(NewUsername)
    if not isValidUsername:
        flash(Reason)
        return redirect("/settings/update-username")
    
    try:
        textfilter.FilterText(NewUsername, ThrowException=True, UseExtendedBadWords=True)
    except Exception as e:
        flash("Username contains inappropriate words")
        return redirect("/settings/update-username")

    if NewUsername == AuthenticatedUser.username:
        flash("Username cannot be the same as your current username")
        return redirect("/settings/update-username")
    
    UsernameTaken = User.query.filter(func.lower(User.username) == func.lower(NewUsername)).first()
    if UsernameTaken is not None:
        flash("Username is taken")
        return redirect("/settings/update-username")
    
    PastUsernameObj : PastUsername = PastUsername.query.filter(func.lower(PastUsername.username) == func.lower(NewUsername)).first()
    if PastUsernameObj is not None:
        if PastUsernameObj.user_id != AuthenticatedUser.id:
            flash("Username is taken")
            return redirect("/settings/update-username")
    
    UserRobuxBalance, _ = economy.GetUserBalance( TargetUser = AuthenticatedUser )
    if UserRobuxBalance < 1000:
        flash("You need at least 1000 robux to change your username")
        return redirect("/settings/update-username")
    
    try:
        economy.DecrementTargetBalance(
            Target = AuthenticatedUser,
            Amount = 1000,
            CurrencyType = 0
        )
    except economy.InsufficientFundsException:
        flash("You need at least 1000 robux to change your username")
        return redirect("/settings/update-username")
    except economy.EconomyLockAcquireException:
        flash("Failed to change username, please try again later no robux was deducted")
        return redirect("/settings/update-username")
    except Exception as e:
        flash("Failed to change username, please try again later")
        return redirect("/settings/update-username")

    try:
        NewPastUsernameObj = PastUsername(
            user_id=AuthenticatedUser.id,
            username=AuthenticatedUser.username
        )
        db.session.add(NewPastUsernameObj)

        AuthenticatedUser.username = NewUsername
        db.session.commit()
    except Exception as e:
        flash("Failed to change username, please try again later")
        return redirect("/settings/update-username")
    
    try:
        transactions.CreateTransaction(
            CurrencyAmount = 1000,
            CurrencyType = 0,
            TransactionType = TransactionType.Purchase,
            AssetId = None,
            CustomText = None,
            Sender = AuthenticatedUser
        )
    except:
        pass
    
    flash("Username updated")
    return redirect("/settings")

@settings.route("/settings/update-email", methods=["GET"])
@auth.authenticated_required
def settings_update_email():
    if not websiteFeatures.GetWebsiteFeature("EmailChange"):
        flash("Email changing is temporarily disabled")
        return redirect("/settings")
    return render_template("settings/changeemail.html")

EmailRegex = r"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$" # RFC 5322 Compliant, because some fucker is gonna complain that he cant verify his email from his self-hosted shit

@settings.route("/settings/update-email", methods=["POST"])
@auth.authenticated_required
@limiter.limit("20/minute")
def settings_update_email_post():
    AuthenticatedUser : User = auth.GetCurrentUser()

    # We've been breached. Allow people to change their emails without cooldown
    #if redis_controller.exists(f"update_email_v1_cooldown:{AuthenticatedUser.id}"):
        #flash("Please wait 12 hours before updating your email again", "error")
        #return redirect("/settings/update-email")
    
    NewEmail = request.form.get( key = "new-email", default = "", type = str ).strip().lower()
    Password = request.form.get( key = "password", default = "", type = str )
    CloudflareTurnstileKey = request.form.get( key = "cf-turnstile-response", default = None, type=str )

    if CloudflareTurnstileKey is None or CloudflareTurnstileKey == '':
        flash("Please complete the captcha", "error")
        return redirect("/settings/update-password")
    if not turnstile.VerifyToken( CloudflareTurnstileKey ):
        flash("Invalid captcha answer", "error")
        return redirect("/settings/update-password")

    if not auth.VerifyPassword(AuthenticatedUser, Password):
        flash("Incorrect password", "error")
        return redirect("/settings/update-password")
    
    if not re.match( EmailRegex, NewEmail ):
        flash("Invalid Email, Not RFC 5322 compliant", "error")
        return redirect("/settings/update-password")
    
    UserEmailObj : UserEmail = UserEmail.query.filter_by(user_id = AuthenticatedUser.id ).first()
    if UserEmailObj:
        if UserEmailObj.email == NewEmail and UserEmailObj.verified:
            flash("Email is already verified to this account", "error")
            return redirect("/settings/update-email")
        UserEmailObj.email = NewEmail
        UserEmailObj.verified = False
        UserEmailObj.updated_at = datetime.utcnow()
    else:
        NewUserEmailObj = UserEmail(
            user_id = AuthenticatedUser.id,
            email = NewEmail,
            verified = False
        )
        db.session.add(NewUserEmailObj)
        db.session.commit()
    
    VerificationUUID = str(uuid.uuid4())
    VerificationURL = f"{config.BaseURL}/settings/update-email/verify?id={VerificationUUID}&user={AuthenticatedUser.id}"

    redis_controller.set(f"update_email_v1:{VerificationUUID}", AuthenticatedUser.id, ex=60 * 60 * 2)
    redis_controller.set(f"update_email_v1_cooldown:{AuthenticatedUser.id}", "1", ex=60 * 60 * 12)

    # Send verification email
    EmailData = {
        "Messages": [
            {
                "From": {
                    "Email": Config.MAILJET_NOREPLY_SENDER,
                    "Name": "syntax.eco"
                },
                "To": [
                    {
                        "Email": NewEmail,
                        "Name": AuthenticatedUser.username
                    }
                ],
                "TemplateID": Config.MAILJET_EMAILVERIFY_TEMPLATE_ID,
                "TemplateLanguage": True,
                "Subject": f"Verify your email on Syntax! - {AuthenticatedUser.username}",
                "Variables": {
                    "username": AuthenticatedUser.username,
                    "verificationlink": VerificationURL
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
            flash("Failed to send verification email", "error")
            redis_controller.delete(f"update_email_v1:{VerificationUUID}")
            redis_controller.delete(f"update_email_v1_cooldown:{AuthenticatedUser.id}")
            return redirect("/settings/update-email")
    except Exception as e:
        flash("Failed to send verification email", "error")
        redis_controller.delete(f"update_email_v1:{VerificationUUID}")
        redis_controller.delete(f"update_email_v1_cooldown:{AuthenticatedUser.id}")
        return redirect("/settings/update-email")
    
    flash("Verification email sent", "success")
    return redirect("/settings/update-email")

@settings.route("/settings/update-email/verify", methods=["GET"])
def VerifyEmailGet():
    EmailVerificationUUID : str = request.args.get( key = "id", default = "", type = str )
    ExpectedUserId : int = request.args.get( key = "user", default = None, type = int )

    if EmailVerificationUUID == "" or ExpectedUserId is None:
        return abort(404)
    
    UserId = redis_controller.get(f"update_email_v1:{EmailVerificationUUID}")
    if UserId is None:
        return abort(404)
    if int(UserId) != ExpectedUserId:
        return abort(404)
    
    UserObj : User = User.query.filter_by(id=UserId).first()
    UserEmailObj : UserEmail = UserEmail.query.filter_by(user_id=UserObj.id).first()

    if UserEmailObj is None:
        return abort(404)
    UserEmailObj.verified = True
    UserEmailObj.updated_at = datetime.utcnow()
    db.session.commit()

    RewardObj = None
    if config.VERIFIED_EMAIL_REWARD_ASSET > 0:
        if not UserAsset.query.filter_by(userid=UserObj.id, assetid=config.VERIFIED_EMAIL_REWARD_ASSET).first():
            NewUserAssetObj : UserAsset = UserAsset(
                userid=UserObj.id,
                assetid=config.VERIFIED_EMAIL_REWARD_ASSET
            )
            db.session.add(NewUserAssetObj)
            db.session.commit()
        RewardObj = Asset.query.filter_by(id=config.VERIFIED_EMAIL_REWARD_ASSET).first()
    
    return render_template("settings/emailverify_success.html", UserObj = UserObj, RewardObj = RewardObj)