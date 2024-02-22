from app.extensions import db
from datetime import datetime, timedelta
from app.enums.BanType import BanType

class UserBan(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    userid = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False)
    author_userid = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False)
    reason = db.Column(db.String(512), nullable=False)
    ban_type = db.Column(db.Enum(BanType), nullable=False)
    moderator_note = db.Column(db.String(512), nullable=True)

    created_at = db.Column(db.DateTime, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=True)

    acknowledged = db.Column(db.Boolean, nullable=False, default=False)

    def __init__(
        self,
        userid: int,
        author_userid: int,
        reason: str,
        ban_type: BanType,
        moderator_note: str,
        expires_at: datetime,
        created_at: datetime = None
    ):
        self.userid = userid
        self.author_userid = author_userid
        self.reason = reason
        self.ban_type = ban_type
        self.moderator_note = moderator_note
        self.expires_at = expires_at
    
        if created_at is None:
            created_at = datetime.utcnow()
        self.created_at = created_at

    def __repr__(self):
        return f'<UserBan {self.id} {self.userid} {self.author_userid} {self.reason} {self.ban_type} {self.moderator_note} {self.created_at} {self.expires_at} {self.acknowledged}>'