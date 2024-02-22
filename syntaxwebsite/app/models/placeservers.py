from app.extensions import db
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime, timedelta

class PlaceServer(db.Model):
    serveruuid = db.Column(UUID(as_uuid=True), primary_key=True, nullable=False, unique=True)
    originServerId = db.Column(UUID(as_uuid=True), nullable=False, index=True)
    serverIP = db.Column(db.String(128), nullable=False)
    serverPort = db.Column(db.Integer, nullable=False)

    serverPlaceId = db.Column(db.BigInteger, nullable=False, index=True)
    serverRunningTime = db.Column(db.BigInteger, nullable=False, default=0)

    playerCount = db.Column(db.Integer, nullable=False, default=0)
    maxPlayerCount = db.Column(db.Integer, nullable=False, default=20)

    lastping = db.Column(db.DateTime, nullable=True)

    reservedServerAccessCode = db.Column(db.Text, nullable=True)

    def __init__(
        self,
        serveruuid,
        originServerId,
        serverIP,
        serverPort,
        serverPlaceId,

        serverRunningTime=0,
        playerCount=0,
        maxPlayerCount=20,
        reservedServerAccessCode=None
    ):
        self.serveruuid = serveruuid
        self.originServerId = originServerId
        self.serverIP = serverIP
        self.serverPort = serverPort
        self.serverPlaceId = serverPlaceId
        self.serverRunningTime = serverRunningTime
        self.playerCount = playerCount
        self.maxPlayerCount = maxPlayerCount
        self.lastping = datetime.utcnow()
        self.reservedServerAccessCode = reservedServerAccessCode
    
    def __repr__(self):
        return "<PlaceServer serveruuid={serveruuid}, originServerId={originServerId}, serverIP={serverIP}, serverPort={serverPort}, serverPlaceId={serverPlaceId}>".format(
            serveruuid=self.serveruuid,
            originServerId=self.originServerId,
            serverIP=self.serverIP,
            serverPort=self.serverPort,
            serverPlaceId=self.serverPlaceId
        )
