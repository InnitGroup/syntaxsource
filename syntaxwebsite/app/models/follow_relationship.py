from app.extensions import db
from datetime import datetime

class FollowRelationship(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, nullable=False, unique=True, autoincrement=True)
    followerUserId = db.Column(db.BigInteger, nullable=False, index=True)
    followeeUserId = db.Column(db.BigInteger, nullable=False, index=True)
    created = db.Column(db.DateTime, nullable=False)

    def __init__(self, followerUserId, followeeUserId):
        self.followerUserId = followerUserId
        self.followeeUserId = followeeUserId
        self.created = datetime.utcnow()
    
    def __repr__(self):
        return "<FollowRelationship followerUserId={followerUserId}, followeeUserId={followeeUserId}, created={created}>".format(
            followerUserId=self.followerUserId,
            followeeUserId=self.followeeUserId,
            created=self.created
        )