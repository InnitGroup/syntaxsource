from app.extensions import db
from datetime import datetime

class AssetRap(db.Model):
    assetid = db.Column(db.BigInteger, primary_key=True, nullable=False, unique=True)
    rap = db.Column(db.BigInteger, nullable=False, default=0)
    updated = db.Column(db.DateTime, nullable=False)

    def __init__(
        self,
        assetid,
        rap=0
    ):
        self.assetid = assetid
        self.rap = rap
        self.updated = datetime.utcnow()
    
    def __repr__(self):
        return "<AssetRap assetid={assetid}, rap={rap}, updated={updated}>".format(
            assetid=self.assetid,
            rap=self.rap,
            updated=self.updated
        )