from app.extensions import db

class KofiTransaction(db.Model):
    kofi_transaction_id = db.Column(db.Text, primary_key=True)
    timestamp = db.Column(db.DateTime, nullable=False)
    donation_type = db.Column(db.Text, nullable=False)
    amount = db.Column(db.Float, nullable=False)
    currency = db.Column(db.Text, nullable=False)
    is_subscription_payment = db.Column(db.Boolean, nullable=False)
    message = db.Column(db.Text, nullable=False)
    from_name = db.Column(db.Text, nullable=False)
    from_email = db.Column(db.Text, nullable=False)

    assigned_key = db.Column(db.Text ,nullable=True)

    def __init__(
        self,
        kofi_transaction_id,
        timestamp,
        donation_type,
        amount,
        currency,
        is_subscription_payment,
        message,
        from_name,
        from_email,
        assigned_key=None
    ):
        self.kofi_transaction_id = kofi_transaction_id
        self.timestamp = timestamp
        self.donation_type = donation_type
        self.amount = amount
        self.currency = currency
        self.is_subscription_payment = is_subscription_payment
        self.message = message
        self.from_name = from_name
        self.from_email = from_email
        self.assigned_key = assigned_key
    
    def __repr__(self):
        return f"<KofiTransaction {self.kofi_transaction_id}>"