from app.extensions import db

class LoginRecord(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True, nullable=False)
    userid = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)
    ip = db.Column(db.Text, nullable=False, index=True)
    useragent = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, nullable=False)
    session_token = db.Column(db.Text, nullable=True, index=True)

    User = db.relationship('User', backref=db.backref('login_records', lazy=True), uselist=False)

    def __init__(self, userid, ip, useragent, timestamp, session_token = None):
        self.userid = userid
        self.ip = ip
        self.useragent = useragent
        self.timestamp = timestamp
        self.session_token = session_token
    
    def __repr__(self):
        return '<LoginRecord {} ({} - {})>'.format(self.id, self.userid, self.ip)