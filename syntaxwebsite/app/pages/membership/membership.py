from flask import Blueprint, render_template, request, redirect, url_for, session, flash, redirect, make_response

from app.extensions import db, redis_controller
from app.models.user import User
from app.util import auth

MembershipPages = Blueprint("membership", __name__, template_folder="pages")

@MembershipPages.route("/membership", methods=["GET"])
@auth.authenticated_required
def membership_page():
    return render_template("membership/index.html")

@MembershipPages.route("/membership/payment_methods", methods=["GET"])
@auth.authenticated_required
def payment_methods_page():
    return render_template("membership/payment_methods.html")