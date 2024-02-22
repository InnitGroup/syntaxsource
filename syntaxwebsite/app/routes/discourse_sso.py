from flask import Blueprint, render_template, redirect, url_for, request, flash, jsonify, session, abort
from config import Config
from app.extensions import db
from app.util import auth
from app.models.user import User
from app.models.user_email import UserEmail

import hashlib
import hmac
import base64
import urllib.parse
import time
import logging

config = Config()
discourse_sso = Blueprint("discourse_sso", __name__, url_prefix="/discourse")

@discourse_sso.before_request
def VerifyUserAgent():
    if not config.DISCOURSE_SSO_ENABLED:
        return abort(404)

def VerifyPayloadSignature( Payload : str, Signature : str ) -> bool:
    """
        Verifies the payload signature
    """
    return hmac.compare_digest(
        Signature,
        hmac.new(
            key = config.DISCOURSE_SECRET_KEY.encode("utf-8"),
            msg = Payload.encode("utf-8"),
            digestmod = hashlib.sha256
        ).hexdigest()
    )

def SignPayload( Payload : str ) -> str:
    """
        Signs the payload and returns the signature
    """
    return hmac.new(
        key = config.DISCOURSE_SECRET_KEY.encode("utf-8"),
        msg = Payload.encode("utf-8"),
        digestmod = hashlib.sha256
    ).hexdigest()

@discourse_sso.route("/", methods=["GET"])
@auth.authenticated_required
def DiscourseSSOIndex():
    return render_template("discourse/leaving-syntax.html", baseurl=config.DISCOURSE_FORUM_BASEURL)

@discourse_sso.route("/sso", methods=["GET", "POST"])
@auth.authenticated_required
def DiscourseSSO():
    SSOPayload : str = request.args.get("sso", default=None, type=str)
    PayloadSignature : str = request.args.get("sig", default=None, type=str)

    if SSOPayload is None or PayloadSignature is None:
        return abort(404)
    isValidSignature = VerifyPayloadSignature(SSOPayload, PayloadSignature)
    if not isValidSignature:
        return abort(404)
    Payload = urllib.parse.parse_qs(base64.b64decode(SSOPayload).decode("utf-8"))
    if "nonce" not in Payload:
        return abort(404)
    nonce = Payload["nonce"][0]
    if nonce is None:
        return abort(404)
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserEmailObj : UserEmail = UserEmail.query.filter_by(user_id=AuthenticatedUser.id, verified=True).first()
    if UserEmailObj is None:
        flash("You must have a verified email address to access the forums", "error")
        return redirect(url_for("settings.settings_update_email"))

    if request.method == "GET":
        return render_template("discourse/sso-confirm.html", baseurl=config.DISCOURSE_FORUM_BASEURL)
    elif request.method == "POST":
        payload = {
            "nonce": nonce,
            "email": f"SyntaxUser{AuthenticatedUser.id}@forum.syntax.eco",
            "external_id": AuthenticatedUser.id,
            "username": AuthenticatedUser.username,
            "name": AuthenticatedUser.username,
            "avatar_url": f"{config.BaseURL}/Thumbs/Head.ashx?x=420&y=420&userId={AuthenticatedUser.id}&rnd={time.time()}",
            "avatar_force_update": "true",
            "require_activation": "false",
            "suppress_welcome_message": "true"
        }
        
        payload = urllib.parse.urlencode(payload)
        payload = base64.b64encode(payload.encode("utf-8")).decode("utf-8")
        payloadSignature = SignPayload(payload)

        return redirect(f"{config.DISCOURSE_FORUM_BASEURL}/session/sso_login?sso={payload}&sig={payloadSignature}")        
    else:
        return abort(404)