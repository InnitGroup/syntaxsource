from app.extensions import db
from datetime import datetime, timedelta

class UserHWIDLog( db.Model ):
    id = db.Column( db.BigInteger, primary_key = True, autoincrement = True, nullable = False )
    user_id = db.Column( db.BigInteger, db.ForeignKey( "user.id" ), nullable = False, index=True)
    hwid = db.Column( db.Text, nullable = False, index=True )
    created_at = db.Column( db.DateTime, nullable = False )

    def __init__(
        self,
        user_id,
        hwid,
        created_at = None
    ):
        self.user_id = user_id
        self.hwid = hwid
        self.created_at = created_at or datetime.utcnow()