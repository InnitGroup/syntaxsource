from app.extensions import db
from datetime import datetime

class PreviouslyPlayed(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True, unique=True)
    userid = db.Column(db.BigInteger, nullable=False, index=True)
    lastplayed = db.Column(db.DateTime, nullable=False)
    placeid = db.Column(db.BigInteger, nullable=False, index=True)

    def __init__(self, userid, placeid):
        self.userid = userid
        self.placeid = placeid
        self.lastplayed = datetime.utcnow()
    
    def __repr__(self):
        return f"<PreviouslyPlayed {self.userid} {self.placeid} {self.lastplayed}>"