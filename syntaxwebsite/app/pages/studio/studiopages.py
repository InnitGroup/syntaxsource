from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify, abort

StudioPagesRoute = Blueprint('studiopages', __name__, url_prefix='/')

@StudioPagesRoute.before_request
def before_request():
    BrowserUserAgent = request.headers.get('User-Agent')
    if BrowserUserAgent is None:
        return abort(404)
    if "RobloxStudio" not in BrowserUserAgent:
        return abort(404)

@StudioPagesRoute.route("/ide/welcome", methods=['GET'])
def myPlaces():
    return render_template("studio/myPlaces.html")