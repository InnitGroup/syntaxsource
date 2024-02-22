from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, abort
from config import Config
import json
import logging
from app.models.giftcard_key import GiftcardKey
from app.enums.GiftcardType import GiftcardType
from app.models.kofi_transaction import KofiTransaction
from app.extensions import db, csrf
import requests
import datetime
import random
import string
from requests.auth import HTTPBasicAuth
from config import Config

config = Config()

KofiHandlerRoute = Blueprint("kofihandler", __name__, template_folder="pages")

def GenerateCode():
    Code = ""
    for i in range(0, 5):
        Chunk = ''.join(random.choices(string.ascii_uppercase + string.digits, k=5))
        Code += Chunk
        if i != 4:
            Code += "-"
    return Code

@KofiHandlerRoute.before_request
def before_request():
    if config.KOFI_ENABLED is False:
        return abort(404)

@KofiHandlerRoute.route("/internal/kofi_handler", methods=["POST"])
@csrf.exempt
def kofi_handler():
    try:
        PurchaseData = json.loads(
            request.form.get(key="data", default=None, type=str)
        )
        if PurchaseData is None:
            return abort(400)
    except:
        return abort(400)
    
    if PurchaseData["verification_token"] != Config.KOFI_VERIFICATION_TOKEN:
        return abort(401)

    if "email" not in PurchaseData:
        logging.error("KofiHandler: Email not in PurchaseData")
        return abort(400)
    UserEmail : str = PurchaseData["email"]
    
    logging.info(f"KofiHandler: Received donation from {UserEmail}, Transaction ID: {PurchaseData['kofi_transaction_id']}")
    TransactionObj : KofiTransaction = KofiTransaction.query.filter_by(kofi_transaction_id=PurchaseData["kofi_transaction_id"]).first()
    if TransactionObj is not None:
        logging.error(f"KofiHandler: Transaction ID {PurchaseData['kofi_transaction_id']} already exists")
        return abort(400)
    
    NewGiftcardCode : str = GenerateCode()
    NewGiftcardObj : GiftcardKey = GiftcardKey(
        key = NewGiftcardCode,
        type = GiftcardType.Outrageous_BuildersClub,
        value = 1
    )
    db.session.add(NewGiftcardObj)
    db.session.commit()

    NewTransactionObj : KofiTransaction = KofiTransaction(
        kofi_transaction_id = PurchaseData["kofi_transaction_id"],
        timestamp = datetime.datetime.strptime(PurchaseData["timestamp"], "%Y-%m-%dT%H:%M:%SZ"),
        donation_type = PurchaseData["type"],
        amount = float(PurchaseData["amount"]),
        currency = PurchaseData["currency"],
        is_subscription_payment = PurchaseData["is_subscription_payment"],
        message = PurchaseData["message"],
        from_name = PurchaseData["from_name"],
        from_email = PurchaseData["email"],
        assigned_key = NewGiftcardObj.key
    )
    db.session.add(NewTransactionObj)
    db.session.commit()

    EmailData = {
        "Messages": [
            {
                "From": {
                    "Email": Config.MAILJET_NOREPLY_SENDER,
                    "Name": "Syntax Donation Processor"
                },
                "To": [
                    {
                        "Email": UserEmail,
                        "Name": PurchaseData["from_name"]
                    }
                ],
                "TemplateID": Config.MAILJET_DONATION_TEMPLATE_ID,
                "TemplateLanguage": True,
                "Subject": "Thank you for your donation!",
                "Variables": {
                    "redeem_key": NewGiftcardObj.key,
                }
            }
        ]
    }
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
        logging.error(f"KofiHandler: Failed to send email to {UserEmail}")
        logging.error(EmailResponse.json())
        return "OK", 200 # We don't want to return an error to Ko-fi since we already processed the donation, so we just return OK
    
    logging.info(f"KofiHandler: Successfully sent email to {UserEmail} and processed donation")
    return "OK", 200
