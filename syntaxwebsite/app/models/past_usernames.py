from app.extensions import db
from datetime import datetime

class PastUsername(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True, nullable=False)
    user_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)
    username = db.Column(db.Text, nullable=False)
    created = db.Column(db.DateTime, nullable=False)

    def __init__(self, user_id, username):
        self.user_id = user_id
        self.username = username
        self.created = datetime.utcnow()

    def __repr__(self):
        return '<PastUsername {} ({})>'.format(self.username, str(self.id))
