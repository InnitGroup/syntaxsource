from app.extensions import db
from app.enums.MembershipType import MembershipType
from datetime import datetime, timedelta

class UserMembership(db.Model):
    user_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), primary_key=True)
    membership_type = db.Column(db.Enum(MembershipType), nullable=False)
    created = db.Column(db.DateTime, nullable=True)
    expiration = db.Column(db.DateTime, nullable=True)
    next_stipend = db.Column(db.DateTime, nullable=True)

    def __init__(self, user_id, membership_type, created, expiration):
        self.user_id = user_id
        self.membership_type = membership_type
        self.created = created
        self.expiration = expiration
        if created is not None:
            self.next_stipend = created + timedelta(hours=24)
        else:
            self.next_stipend = None
    
    def __repr__(self):
        return '<UserMembership %r>' % self.user_id
    