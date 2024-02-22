from app.extensions import db

class PlaceIcon(db.Model):
    placeid = db.Column(db.BigInteger, db.ForeignKey('asset.id'), primary_key=True, nullable=False, unique=True)
    contenthash = db.Column(db.String(512), nullable=True)
    updated_at = db.Column(db.DateTime, nullable=True)
    moderation_status = db.Column(db.SmallInteger, nullable=False, default=1) # Asset thumbnail moderation status ( 0 = Approved, 1 = Pending, 2 = Declined )

    asset = db.relationship('Asset', backref=db.backref('place_icon', lazy=True, uselist=False), uselist=False)

    def __init__(self, placeid, contenthash, updated_at, moderation_status=1):
        self.placeid = placeid
        self.contenthash = contenthash
        self.updated_at = updated_at
        self.moderation_status = moderation_status
    
    def __repr__(self):
        return "<PlaceIcon placeid={placeid}, contenthash={contenthash}, updated_at={updated_at}>".format(
            placeid=self.placeid,
            contenthash=self.contenthash,
            updated_at=self.updated_at
        )