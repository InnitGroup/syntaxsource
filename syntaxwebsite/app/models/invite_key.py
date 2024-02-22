from app.extensions import db
from datetime import datetime

class InviteKey(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True, nullable=False)
    key = db.Column(db.String(255), nullable=False) # syntax-randomstring
    created_at = db.Column(db.DateTime, nullable=False)
    created_by = db.Column(db.BigInteger, db.ForeignKey('user.id') ,nullable=True, index=True)
    used_by = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=True)
    used_on = db.Column(db.DateTime, nullable=True)

    creator = db.relationship('User', backref=db.backref('invite_keys', lazy=True), foreign_keys=[created_by], uselist=False)
    user = db.relationship('User', backref=db.backref('used_invite_keys', lazy=True), foreign_keys=[used_by], uselist=False)

    def __init__(
        self,
        key,
        created_by
    ):
        self.key = key
        self.created_by = created_by
        self.created_at = datetime.utcnow()

    def __repr__(self):
        return '<InviteKey %r>' % self.id