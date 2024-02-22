from flask import Blueprint, render_template, request, redirect, url_for, flash, make_response, jsonify
from app.models.gameservers import GameServer
from app.models.pointsservice import PointsService
from app.extensions import get_remote_address, db, csrf
import logging

PointsServiceRoute = Blueprint('pointsservice', __name__)

@PointsServiceRoute.route("/points/get-point-balance", methods=["GET"])
def get_point_balance():
    userId = request.args.get('userId')
    placeId = request.args.get('placeId')
    if userId is None or placeId is None:
        return jsonify({"success": False, "message": "Missing parameters"}),400
    if userId.isnumeric() is False or placeId.isnumeric() is False:
        return jsonify({"success": False, "message": "Invalid parameters"}),400
    RequestIP = get_remote_address()
    if RequestIP is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401    
    server = GameServer.query.filter_by(serverIP=RequestIP).first()
    if server is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    points : PointsService = PointsService.query.filter_by(userId=userId, placeId=placeId).first()
    if points is None:
        points = PointsService(userId=userId, placeId=placeId, points=0)
        db.session.add(points)
        db.session.commit()
    return jsonify({"success": True, "pointBalance": points.points}),200    
        

@PointsServiceRoute.route("/points/award-points", methods=["POST"])
@csrf.exempt
def award_points():
    userId = request.args.get(key='userId', default=None, type=int)
    placeId = request.args.get(key='placeId', default=None, type=int)
    amount = request.args.get(key='amount', default=None, type=int)
    if userId is None or placeId is None or amount is None:
        return jsonify({"success": False, "message": "Missing parameters"}),400
    RequestIP = get_remote_address()
    if RequestIP is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401    
    server = GameServer.query.filter_by(serverIP=RequestIP).first()
    if server is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    points : PointsService = PointsService.query.filter_by(userId=userId, placeId=placeId).first()
    if points is None:
        points = PointsService(userId=userId, placeId=placeId, points=0)
        db.session.add(points)
        db.session.commit()
    points.points += int(amount)
    db.session.commit()
    return jsonify({"success": True, "userBalance": points.points, "pointsAwarded": amount, "userGameBalance": points.points}),200