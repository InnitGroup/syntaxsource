from app.extensions import db

class UserEconomy(db.Model):
    userid = db.Column(db.Integer, db.ForeignKey('user.id'), primary_key=True, unique=True, nullable=False )
    robux = db.Column(db.Integer, nullable=False, default=0)
    tix = db.Column(db.Integer, nullable=False, default=0)

    user = db.relationship('User', backref=db.backref('economy', lazy=True, uselist=False), uselist=False)

    def __init__(self, userid, robux, tix):
        self.userid = userid
        self.robux = robux
        self.tix = tix
    
    def __repr__(self):
        return '<UserEconomy {} ({} R$, {} T$)>'.format(self.userid, str(self.robux), str(self.tix))