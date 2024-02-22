from app.extensions import db

class User(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True, unique=True, nullable=False)
    username = db.Column(db.Text, index=True, unique=True, nullable=False)
    password = db.Column(db.Text, nullable=False)

    created = db.Column(db.DateTime, nullable=False)
    description = db.Column(db.Text, nullable=False, default="")
    lastonline = db.Column(db.DateTime, nullable=False)

    # 1 = OK, 2 = Banned, 3 = Deleted, 4 = Forgotten
    accountstatus = db.Column(db.Integer, nullable=False, default=1)
    TOTPEnabled = db.Column(db.Boolean, nullable=False, default=False)

    def __init__( self, username, password, created, lastonline):
        self.username = username
        self.password = password
        self.created = created
        self.lastonline = lastonline
        self.description = "Hi! I just joined Syntax!"

    def __repr__(self):
        return '<User {} ({})>'.format(self.username, str(self.id))

