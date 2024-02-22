from app.extensions import db
from datetime import datetime

class FriendRelationship(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True, nullable=False)
    user_id = db.Column(db.BigInteger, nullable=False, index=True)
    friend_id = db.Column(db.BigInteger, nullable=False, index=True)
    created_at = db.Column(db.DateTime, nullable=False)

    def __init__(self, user_id, friend_id):
        self.user_id = user_id
        self.friend_id = friend_id
        self.created_at = datetime.utcnow()

    def __repr__(self):
        return '<FriendRelationship %r>' % self.id