from app.extensions import db
from app.enums.TradeStatus import TradeStatus
from datetime import datetime, timedelta
class UserTrade(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    sender_userid = db.Column(db.BigInteger, nullable=False, index=True)
    recipient_userid = db.Column(db.BigInteger, nullable=False, index=True)

    sender_userid_robux = db.Column(db.BigInteger, nullable=False, default=0) # Robux the sender is offering
    recipient_userid_robux = db.Column(db.BigInteger, nullable=False, default=0) # Robux the recipient is offering

    status = db.Column(db.Enum(TradeStatus), nullable=False, default=TradeStatus.Pending)

    created_at = db.Column(db.DateTime, nullable=False)
    updated_at = db.Column(db.DateTime, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)

    def __init__(
        self,
        sender_userid : int,
        recipient_userid : int,
        sender_userid_robux : int = 0,
        recipient_userid_robux : int = 0,
        status : TradeStatus = TradeStatus.Pending,
        created_at : datetime = None,
        updated_at : datetime = None,
        expires_at : datetime = None
    ):
        self.sender_userid = sender_userid
        self.recipient_userid = recipient_userid
        self.sender_userid_robux = sender_userid_robux
        self.recipient_userid_robux = recipient_userid_robux
        self.status = status
        self.created_at = created_at or datetime.utcnow()
        self.updated_at = updated_at or datetime.utcnow()
        self.expires_at = expires_at or datetime.utcnow() + timedelta(days=7)
    
    def __repr__(self):
        return f"<UserTrade {self.id} {self.sender_userid} {self.recipient_userid} {self.sender_userid_robux} {self.recipient_userid_robux} {self.status} {self.created_at} {self.updated_at} {self.expires_at}>"