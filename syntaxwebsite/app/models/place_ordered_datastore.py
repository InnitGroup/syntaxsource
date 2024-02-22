from app.extensions import db
from datetime import datetime

class PlaceOrderedDatastore( db.Model ):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    placeid = db.Column(db.BigInteger, nullable=False)

    scope = db.Column(db.String(255), nullable=False)
    key = db.Column(db.String(255), nullable=False)
    name = db.Column(db.String(255), nullable=False)
    value = db.Column(db.BigInteger, nullable=False)

    created_at = db.Column(db.DateTime, nullable=False)
    updated_at = db.Column(db.DateTime, nullable=False)

    universe_id = db.Column(db.BigInteger, db.ForeignKey('universe.id'), nullable=True, index=True)

    def __init__(self, placeid, scope, key, name, value, created_at=None, updated_at=None, universe_id=None):
        self.placeid = placeid
        self.scope = scope
        self.key = key
        self.name = name
        self.value = value

        if created_at is None:
            created_at = datetime.utcnow()
        if updated_at is None:
            updated_at = datetime.utcnow()
        self.created_at = created_at
        self.updated_at = updated_at

    def __repr__(self):
        return '<PlaceDatastore %r>' % self.id