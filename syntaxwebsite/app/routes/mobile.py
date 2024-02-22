from flask import Blueprint, render_template, request, redirect, url_for, flash, session, abort, jsonify, make_response
from sqlalchemy import func
import hashlib
import random
import logging
from config import Config
from app.extensions import limiter, csrf, get_remote_address
from app.models.user import User
from app.models.user_email import UserEmail
from app.util import auth
from app.services import economy
from datetime import datetime, timedelta

config = Config()
MobileAPIRoute = Blueprint('mobile', __name__, url_prefix='/')

@MobileAPIRoute.route("/device/initialize", methods=["POST"])
@csrf.exempt
def DeviceInit():
    return jsonify({"browserTrackerId":random.randint(100000000,9999999999),"appDeviceIdentifier":None})

@MobileAPIRoute.route("/mobileapi/check-app-version", methods=["GET"])
def check_app_version():
    return jsonify({"data":{"UpgradeAction":"None"}})

@MobileAPIRoute.route("/mobile/pbe", methods=["GET"])
def mobile_pbe():
    return "", 200