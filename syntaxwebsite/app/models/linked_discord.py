from app.extensions import db
from datetime import datetime

class LinkedDiscord(db.Model):
    user_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), primary_key=True)
    discord_id = db.Column(db.BigInteger, nullable=False)
    discord_username = db.Column(db.String(255), nullable=False)
    discord_discriminator = db.Column(db.String(255), nullable=True)
    discord_avatar = db.Column(db.Text, nullable=True)
    discord_access_token = db.Column(db.String(512), nullable=True)
    discord_refresh_token = db.Column(db.String(512), nullable=True)
    discord_expiry = db.Column(db.DateTime, nullable=True)

    last_updated = db.Column(db.DateTime, nullable=False)
    linked_on = db.Column(db.DateTime, nullable=False)

    user = db.relationship('User', backref=db.backref('discord', lazy=True))

    def __init__(self,
        user_id,
        discord_id,
        discord_username,
        discord_discriminator,
        discord_avatar,
        discord_access_token,
        discord_refresh_token,
        discord_expiry,
        last_updated=None,
        linked_on=None
    ):
        self.user_id = user_id
        self.discord_id = discord_id
        self.discord_username = discord_username
        self.discord_discriminator = discord_discriminator
        self.discord_avatar = discord_avatar
        self.discord_access_token = discord_access_token
        self.discord_refresh_token = discord_refresh_token,
        self.discord_expiry = discord_expiry

        if last_updated is None:
            self.last_updated = datetime.utcnow()
        else:
            self.last_updated = last_updated
        if linked_on is None:
            self.linked_on = datetime.utcnow()
        else:
            self.linked_on = linked_on
    def __repr__(self):
        return '<LinkedDiscord %r>' % self.user_id