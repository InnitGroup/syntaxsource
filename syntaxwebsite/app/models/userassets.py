from app.extensions import db
from datetime import datetime

class UserAsset(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, nullable=False, unique=True, autoincrement=True)
    userid = db.Column(db.BigInteger, nullable=False, index=True)
    assetid = db.Column(db.BigInteger, db.ForeignKey("asset.id"), nullable=False, index=True)

    serial = db.Column(db.BigInteger, nullable=True, default=None)
    price = db.Column(db.BigInteger, nullable=False, default=0)

    created = db.Column(db.DateTime, nullable=False)
    updated = db.Column(db.DateTime, nullable=False)

    is_for_sale = db.Column(db.Boolean, nullable=False, default=False)

    asset = db.relationship("Asset", foreign_keys=[assetid], uselist=False, lazy="joined")

    def __init__(
        self,
        userid,
        assetid,

        serial=None,
        price=0
    ):
        self.userid = userid
        self.assetid = assetid
        self.serial = serial
        self.price = price
        self.created = datetime.utcnow()
        self.updated = datetime.utcnow()
    
    def __repr__(self):
        return "<UserAsset id={id}, userid={userid}, assetid={assetid}, serial={serial}, price={price}, created={created}, updated={updated}>".format(
            id=self.id,
            userid=self.userid,
            assetid=self.assetid,
            serial=self.serial,
            price=self.price,
            created=self.created,
            updated=self.updated
        )