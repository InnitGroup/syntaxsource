from app.extensions import db
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime, timedelta

class GameSessionLog( db.Model ):
    id = db.Column( db.BigInteger, primary_key = True, autoincrement = True, nullable = False )
    user_id = db.Column( db.BigInteger, db.ForeignKey( "user.id" ), nullable = False, index=True)
    serveruuid = db.Column( UUID(as_uuid=True), nullable=False, index=True )
    joined_at = db.Column( db.DateTime, nullable = False, index = True )
    left_at = db.Column( db.DateTime, nullable = True )
    place_id = db.Column( db.BigInteger, nullable = False, index=True )

    def __init__(
        self,
        user_id,
        serveruuid,
        place_id,
        joined_at = None,
        left_at = None
    ):
        self.user_id = user_id
        self.serveruuid = serveruuid
        self.place_id = place_id
        self.joined_at = joined_at or datetime.utcnow()
        self.left_at = left_at

    def __repr__(self):
        return "<GameSessionLog user_id={user_id}, serveruuid={serveruuid}, place_id={place_id}, joined_at={joined_at}, left_at={left_at}>".format(
            user_id=self.user_id,
            serveruuid=self.serveruuid,
            place_id=self.place_id,
            joined_at=self.joined_at,
            left_at=self.left_at
        )

    