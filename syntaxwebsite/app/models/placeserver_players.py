from app.extensions import db
from sqlalchemy.dialects.postgresql import UUID

class PlaceServerPlayer(db.Model):
    userid = db.Column(db.BigInteger, db.ForeignKey('user.id'), primary_key=True, nullable=False, unique=True)
    serveruuid = db.Column(UUID(as_uuid=True), nullable=False, index=True)
    joinTime = db.Column(db.DateTime, nullable=False)
    lastHeartbeat = db.Column(db.DateTime, nullable=True, default=None)

    user = db.relationship('User', backref=db.backref('placeserver_players', lazy=True), uselist=False)

    def __init__(self, userid, serveruuid, joinTime):
        self.userid = userid
        self.serveruuid = serveruuid
        self.joinTime = joinTime
        self.lastHeartbeat = joinTime
    
    def __repr__(self):
        return "<PlaceServerPlayer userid={userid}, serveruuid={serveruuid}, joinTime={joinTime}>".format(
            userid=self.userid,
            serveruuid=self.serveruuid,
            joinTime=self.joinTime
        )
