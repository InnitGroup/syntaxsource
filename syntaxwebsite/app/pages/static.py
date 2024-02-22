# Pages which has no function but to display static content
from flask import Blueprint, render_template, redirect
from app.util import auth

static = Blueprint("static", __name__, template_folder="pages")

@static.route("/terms")
def terms():
    return render_template("terms.html")

@static.route("/privacy")
def privacy():
    return render_template("privacy.html")

@static.route("/download")
@auth.authenticated_required
def download():
    return render_template("downloads.html")

@static.route("/Games.aspx")
@auth.authenticated_required
def gamesaspx():
    return redirect("/games")

@static.route("/drivers")
@auth.authenticated_required
def drivers():
    return render_template("drivers.html")
