from flask import Blueprint, render_template, request, redirect, url_for, flash, session, abort, jsonify, make_response
from app.util import auth
from app.extensions import db, csrf, limiter
from flask_wtf.csrf import CSRFError, generate_csrf

from app.models.user_email import UserEmail
from app.models.user import User

AccountSettingsAPIRoute = Blueprint('accountsettingsapi', __name__, url_prefix='/')

csrf.exempt(AccountSettingsAPIRoute)
@AccountSettingsAPIRoute.errorhandler(CSRFError)
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

@AccountSettingsAPIRoute.errorhandler(429)
def handle_ratelimit_reached(e):
    return jsonify({
        "errors": [
            {
                "code": 9,
                "message": "The flood limit has been exceeded."
            }
        ]
    }), 429

@AccountSettingsAPIRoute.before_request
def before_request():
    if "Roblox/" not in request.user_agent.string:
        csrf.protect()

@AccountSettingsAPIRoute.route("/v1/email", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def get_email_status():
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserEmailObject : UserEmail = UserEmail.query.filter_by(user_id=AuthenticatedUser.id).first()

    HiddenEmail = None
    if UserEmailObject:
        emailParts = UserEmailObject.email.split("@")
        FirstPart = emailParts[0][0] + "*" * (len(emailParts[0])-1)
        SecondPart = emailParts[1]
        HiddenEmail = FirstPart + "@" + SecondPart

    return jsonify({
        "emailAddress": HiddenEmail,
        "verified": UserEmailObject.verified if UserEmailObject else False,
        "canBypassPasswordForEmailUpdate": True
    })

@AccountSettingsAPIRoute.route("/v1/themes/<consumerType>/<int:consumerId>", methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("60/minute")
def get_consumer_theme( consumerType : str, consumerId : int ):
    return jsonify({
        "themeType": "Dark"
    })

