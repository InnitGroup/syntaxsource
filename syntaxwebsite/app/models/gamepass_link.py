from app.extensions import db
import datetime

class GamepassLink(db.Model):
    gamepass_id = db.Column(db.BigInteger, db.ForeignKey("asset.id"), primary_key=True, nullable=False)
    place_id = db.Column(db.BigInteger, db.ForeignKey("asset.id"), primary_key=True, nullable=False, index=True) # DEPRECATED
    creator_id = db.Column(db.BigInteger, db.ForeignKey("user.id"), nullable=False, index=True)
    created_at = db.Column(db.DateTime, nullable=False)

    gamepass = db.relationship("Asset", foreign_keys=[gamepass_id], uselist=False, lazy="joined")
    place = db.relationship("Asset", foreign_keys=[place_id], uselist=False, lazy="joined")
    creator = db.relationship("User", foreign_keys=[creator_id], uselist=False, lazy="joined")

    universe_id = db.Column(db.BigInteger, db.ForeignKey("universe.id"), nullable=True, index=True)

    def __init__(self, place_id, gamepass_id, universe_id, creator_id):
        self.place_id = place_id
        self.gamepass_id = gamepass_id
        self.universe_id = universe_id
        self.creator_id = creator_id
        self.created_at = datetime.datetime.utcnow()

    def __repr__(self):
        return '<GamepassLink %r>' % self.id