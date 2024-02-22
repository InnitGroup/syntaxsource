from app.extensions import db
from sqlalchemy.dialects.postgresql import UUID
import uuid

class GameServer(db.Model):
    serverId = db.Column(UUID(as_uuid=True), primary_key=True, nullable=False, unique=True, default=uuid.uuid4)
    serverName = db.Column(db.String(128), nullable=False)
    serverIP = db.Column(db.String(128), nullable=False)
    serverPort = db.Column(db.Integer, nullable=False)
    accessKey = db.Column(db.String(128), nullable=False)

    lastHeartbeat = db.Column(db.DateTime, nullable=True, default=None)
    heartbeatResponseTime = db.Column(db.Float, nullable=True, default=0)
    isRCCOnline = db.Column(db.Boolean, nullable=False, default=False)
    thumbnailQueueSize = db.Column(db.Integer, nullable=False, default=0)
    RCCmemoryUsage = db.Column(db.BigInteger, nullable=False, default=0)

    allowThumbnailGen = db.Column(db.Boolean, nullable=False, default=True) # If false, the server will not be able to generate thumbnails
    allowGameServerHost = db.Column(db.Boolean, nullable=False, default=True) # If false, the server will not be able to host game servers

    def __init__(
        self,
        serverId,
        serverName,
        serverIP,
        serverPort,
        accessKey,
        allowThumbnailGen=True,
        allowGameServerHost=True
    ):
        self.serverId = serverId
        self.serverName = serverName
        self.serverIP = serverIP
        self.serverPort = serverPort
        self.accessKey = accessKey
        self.allowThumbnailGen = allowThumbnailGen
        self.allowGameServerHost = allowGameServerHost
    
    def __repr__(self):
        return "<GameServers serverId={serverId}, serverName={serverName}, serverIP={serverIP}, serverPort={serverPort}>".format(
            serverId=self.serverId,
            serverName=self.serverName,
            serverIP=self.serverIP,
            serverPort=self.serverPort
        )