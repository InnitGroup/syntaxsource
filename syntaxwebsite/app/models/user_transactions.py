from app.extensions import db
from app.enums.TransactionType import TransactionType
from sqlalchemy import Enum
from datetime import datetime

class UserTransaction(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)

    reciever_id = db.Column(db.BigInteger, nullable=False, index=True)
    reciever_type = db.Column(db.Integer, nullable=False, default=0) # 0 = User, 1 = Group
    sender_id = db.Column(db.BigInteger, nullable=False, index=True)
    sender_type = db.Column(db.Integer, nullable=False, default=0) # 0 = User, 1 = Group

    currency_amount = db.Column(db.BigInteger, nullable=False)
    currency_type = db.Column(db.Integer, nullable=False, default=0) # 0 = Robux, 1 = Tix

    assetId = db.Column(db.BigInteger, nullable=True, default=None, index=True)
    custom_text = db.Column(db.Text, nullable=True, default=None)

    transaction_type = db.Column(Enum(TransactionType), nullable=False, index=True)
    created_at = db.Column(db.DateTime, nullable=False)

    def __init__(
        self,
        reciever_id,
        reciever_type,
        sender_id,
        sender_type,
        currency_amount,
        currency_type,
        transaction_type,
        asset_id=None,
        custom_text=None,
        created_at=None
    ):
        self.reciever_id = reciever_id
        self.reciever_type = reciever_type
        self.sender_id = sender_id
        self.sender_type = sender_type
        self.currency_amount = currency_amount
        self.currency_type = currency_type
        self.transaction_type = transaction_type
        self.assetId = asset_id
        self.custom_text = custom_text

        if created_at is None:
            self.created_at = datetime.utcnow()
        else:
            self.created_at = created_at
    def __repr__(self):
        return "<UserTransaction id=%d>" % self.id