from app.extensions import db
from datetime import datetime

class FriendRequest(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True, nullable=False)
    requester_id = db.Column(db.BigInteger, db.ForeignKey("user.id") ,nullable=False, index=True) # The person who sent the friend request
    requestee_id = db.Column(db.BigInteger, nullable=False, index=True) # The person who received the friend request
    created_at = db.Column(db.DateTime, nullable=False)

    requester = db.relationship("User", foreign_keys=[requester_id], backref="friend_requests_sent", uselist=False)

    def __init__(self, requester_id, requestee_id):
        self.requester_id = requester_id
        self.requestee_id = requestee_id
        self.created_at = datetime.utcnow()
    def __repr__(self):
        return '<FriendRequest %r>' % self.id