from app.extensions import db
from datetime import datetime, timedelta

class ExchangeOffer(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    creator_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)
    creator = db.relationship('User', backref=db.backref('exchange_offers', lazy=True), foreign_keys=[creator_id], uselist=False)

    offer_value = db.Column(db.BigInteger, nullable=False) # Amount of currency the creator is sending 
    receive_value = db.Column(db.BigInteger, nullable=False) # Amount of currency the creator is receiving

    offer_currency_type = db.Column(db.SmallInteger, nullable=False) # Currency type of the offer value, 0 = Robux, 1 = Tix
    # Recieve currency type is the opposite of the offer currency type

    reciever_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=True, index=True) # If the offer is accepted by someone, this will be set to the user's id
    reciever = db.relationship('User', backref=db.backref('exchange_offers_recieved', lazy=True), foreign_keys=[reciever_id], uselist=False)

    created_at = db.Column(db.DateTime, nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)

    ratio = db.Column(db.Float, nullable=False, default=0) # The ratio of the offer value to the receive value
    worth = db.Column(db.Float, nullable=False, default=0, index = True)

    def __init___(
        self,
        creator_id,
        offer_value,
        receive_value,
        offer_currency_type=0, # Robux
        reciever_id=None,
        ratio = None,
        created_at=None,
        expires_at=None
    ):
        if created_at is None:
            created_at = datetime.utcnow()
        
        if expires_at is None:
            expires_at = datetime.utcnow() + timedelta(days=31)

        self.creator_id = creator_id
        self.offer_value = offer_value
        self.receive_value = receive_value
        self.offer_currency_type = offer_currency_type
        self.reciever_id = reciever_id
        self.created_at = created_at
        self.expires_at = expires_at

        if ratio is None:
            self.ratio = (offer_value / receive_value) if offer_currency_type == 0 else (receive_value / offer_value)
        else:
            self.ratio = ratio
    def __repr__(self):
        return '<ExchangeOffer %r>' % self.id