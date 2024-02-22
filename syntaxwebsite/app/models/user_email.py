from app.extensions import db
from datetime import datetime

class UserEmail( db.Model ):
    user_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), primary_key=True)
    email = db.Column(db.String(256), nullable=False, primary_key=True)
    verified = db.Column(db.Boolean, nullable=False, default=False)
    updated_at = db.Column(db.DateTime, nullable=False)

    user = db.relationship("User", foreign_keys=[user_id], uselist=False, lazy="joined")

    def __init__(self, user_id, email, verified):
        self.user_id = user_id
        self.email = email
        self.verified = verified
        self.updated_at = datetime.utcnow()

    def __repr__(self):
        return f"<UserEmail {self.user_id} {self.email} {self.verified}>"