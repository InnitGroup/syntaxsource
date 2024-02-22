from app.extensions import db
from datetime import datetime

class LegacyDataPersistence( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True, nullable=False, unique=True, autoincrement=True )
    userid = db.Column( db.BigInteger, nullable=False, index=True )
    placeid = db.Column( db.BigInteger, nullable=False, index=True ) # DEPRECATED
    data = db.Column( db.LargeBinary, nullable=False )

    last_updated = db.Column( db.DateTime, nullable=False )

    universe_id = db.Column( db.BigInteger, db.ForeignKey('universe.id'), nullable=True, index=True ) 

    def __init__(
        self,
        userid,
        placeid,
        universe_id
    ):
        self.userid = userid
        self.placeid = placeid
        self.last_updated = datetime.utcnow()
        self.universe_id = universe_id

    def __repr__(self):
        return "<LegacyDataPersistence id={id}, userid={userid}, placeid={placeid}>".format(
            id=self.id,
            userid=self.userid,
            placeid=self.placeid
        )

