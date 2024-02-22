from app.extensions import db

class UserThumbnail(db.Model):
    userid = db.Column(db.BigInteger, primary_key=True, nullable=False, unique=True)
    full_contenthash = db.Column(db.String(512), nullable=True)
    headshot_contenthash = db.Column(db.String(512), nullable=True)
    updated_at = db.Column(db.DateTime, nullable=True)

    def __init__(self, userid, full_contenthash, headshot_contenthash, updated_at):
        self.userid = userid
        self.full_contenthash = full_contenthash
        self.headshot_contenthash = headshot_contenthash
        self.updated_at = updated_at
    
    def __repr__(self):
        return "<UserThumbnail userid={userid}, full_contenthash={full_contenthash}, headshot_contenthash={headshot_contenthash}, updated_at={updated_at}>".format(
            userid=self.userid,
            full_contenthash=self.full_contenthash,
            headshot_contenthash=self.headshot_contenthash,
            updated_at=self.updated_at
        )

