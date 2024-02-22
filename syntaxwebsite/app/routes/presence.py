from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response
from app.extensions import csrf, db
from app.util import auth, friends
from app.models.user import User
from datetime import datetime

PresenceRoute = Blueprint("presence", __name__, url_prefix="/presence")

@PresenceRoute.route("/", methods=["GET"])
@auth.authenticated_required_api
def UpdatePresence():
    Authuser : User = auth.GetCurrentUser()
    if Authuser is None:
        return "BAD REQUEST", 400
    Authuser.lastonline = datetime.utcnow()
    db.session.commit()
    return "OK", 200