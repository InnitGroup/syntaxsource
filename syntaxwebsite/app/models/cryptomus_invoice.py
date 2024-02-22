from app.extensions import db
from datetime import datetime
from app.enums.CryptomusPaymentStatus import CryptomusPaymentStatus

class CryptomusInvoice(db.Model):
    id = db.Column( db.Text, primary_key=True, unique=True, nullable=False, index = True )
    cryptomus_invoice_id = db.Column( db.Text, nullable=False, index = True )
    
    initiator_id = db.Column( db.Integer, db.ForeignKey('user.id'), nullable=False, index = True )
    
    required_amount = db.Column( db.Float, nullable=False )
    paid_amount_usd = db.Column( db.Float, nullable=False, default=0 )
    currency = db.Column( db.Text, nullable=False )
    status = db.Column( db.Enum(CryptomusPaymentStatus), nullable=False )
    is_final = db.Column( db.Boolean, nullable=False, default=False )

    extra_data = db.Column( db.Text, nullable=True )

    created_at = db.Column( db.DateTime, nullable=False )
    updated_at = db.Column( db.DateTime, nullable=False )
    expires_at = db.Column( db.DateTime, nullable=False )

    assigned_key = db.Column( db.Text, nullable=True )

    def __init__(
        self,
        id : str,
        cryptomus_invoice_id : str,

        initiator_id : int,

        required_amount : float,
        currency : str,
        status : CryptomusPaymentStatus,

        expires_at : datetime,
        created_at : datetime = None,
        updated_at : datetime = None,
        paid_amount_usd : float = 0,
        extra_data : str = None
    ):
        self.id = id
        self.cryptomus_invoice_id = cryptomus_invoice_id
        self.initiator_id = initiator_id
        self.required_amount = required_amount
        self.currency = currency
        self.status = status
        self.expires_at = expires_at
        self.created_at = created_at if created_at is not None else datetime.utcnow()
        self.updated_at = updated_at if updated_at is not None else datetime.utcnow()
        self.paid_amount_usd = paid_amount_usd
        self.extra_data = extra_data