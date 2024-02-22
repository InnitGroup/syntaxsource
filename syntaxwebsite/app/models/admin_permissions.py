from app.extensions import db

class AdminPermissions(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, nullable=False, unique=True, autoincrement=True)
    userid = db.Column(db.BigInteger, nullable=False, index=True)
    permission = db.Column(db.String(128), nullable=False, index=True)

    def __init__(self, userid, permission):
        self.userid = userid
        self.permission = permission
    
    def __repr__(self):
        return "<AdminPermissions userid={userid}, permission={permission}>".format(
            userid=self.userid,
            permission=self.permission
        )