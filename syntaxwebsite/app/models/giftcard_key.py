from app.extensions import db
from app.enums.GiftcardType import GiftcardType
from datetime import datetime

class GiftcardKey(db.Model):
    id = db.Column(db.BigInteger, primary_key=True)
    key = db.Column(db.String(255), nullable=False)
    type = db.Column(db.Enum(GiftcardType), nullable=False)
    value = db.Column(db.BigInteger, nullable=True)

    created_at = db.Column(db.DateTime, nullable=False)
    redeemed_at = db.Column(db.DateTime, nullable=True)
    redeemed_by = db.Column(db.BigInteger, nullable=True)

    def __init__(
        self,
        key: str,
        type: GiftcardType,
        value: int = None,
        created_at: datetime = None,
    ):
        if created_at is None:
            created_at = datetime.utcnow()

        self.key = key
        self.type = type
        self.value = value
        self.created_at = created_at
    
    def __repr__(self):
        return f'<GiftcardKey {self.id}>'
