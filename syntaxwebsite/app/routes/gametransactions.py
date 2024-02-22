from flask import Blueprint, render_template, request, redirect, url_for, flash, session, abort, jsonify, make_response
from app.util import auth, friends, websiteFeatures
import logging
from app.services import economy
from app.extensions import db, limiter, csrf, get_remote_address
from app.models.gameservers import GameServer
from app.models.place_developer_product import DeveloperProduct
from app.models.product_receipt import ProductReceipt

GameTransactionsRoute = Blueprint("gametransactions", __name__, url_prefix="/")

@GameTransactionsRoute.before_request
def VerifyUserAgent():
    RequestAddress = get_remote_address()
    TargetServerObj : GameServer = GameServer.query.filter_by( serverIP = RequestAddress ).first()
    if TargetServerObj is None:
        abort(404)
    
    AccessKey = request.headers.get( key = "AccessKey", default = None , type = str )
    if AccessKey is None:
        abort(403)

    if AccessKey != TargetServerObj.accessKey:
        abort(403)

@GameTransactionsRoute.route("/gametransactions/getpendingtransactions/", methods=["GET"])
def GetPendingTransactions():
    PlayerId = request.args.get( key = "PlayerId", default = None, type = int )
    PlaceId = request.args.get( key = "PlaceId", default = None, type = int )

    if PlayerId is None or PlaceId is None:
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400
    
    PendingProductReceipts : list[ProductReceipt] = ProductReceipt.query.filter_by( 
        user_id = PlayerId, is_processed = False 
    ).outerjoin( 
        DeveloperProduct, DeveloperProduct.productid == ProductReceipt.product_id 
    ).filter( DeveloperProduct.placeid == PlaceId ).all()
    
    PendingProductReceiptsDict = []
    for PendingProductReceipt in PendingProductReceipts:
        PendingProductReceiptsDict.append({
            "playerId": PendingProductReceipt.user_id,
            "placeId": PlaceId,
            "receipt": PendingProductReceipt.receipt_id,
            "actionArgs": [
                {
                    "Key": "productId",
                    "Value": PendingProductReceipt.product_id
                },
                {
                    "Key": "currencyTypeId",
                    "Value": 1
                },
                {
                    "Key": "unitPrice",
                    "Value": PendingProductReceipt.robux_amount
                }
            ]
        })

    return jsonify(PendingProductReceiptsDict)

@GameTransactionsRoute.route("/gametransactions/settransactionstatuscomplete", methods=["POST"])
@csrf.exempt
def SetTransactionStatusComplete():
    receiptId : int = request.form.get( key = "receipt", default = None, type = int )
    if receiptId is None:
        logging.error("Invalid request")
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400
    ReceiptObj : ProductReceipt = ProductReceipt.query.filter_by( receipt_id = receiptId ).first()
    if ReceiptObj is None:
        logging.error("Receipt not found")
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400
    ReceiptObj.is_processed = True
    db.session.commit()

    return jsonify({
        "success": True,
    })