from app.extensions import db 
from datetime import datetime

class Message( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True, autoincrement=True, nullable=False )
    sender_id = db.Column( db.BigInteger, db.ForeignKey("user.id"), nullable=False, index=True )
    recipient_id = db.Column( db.BigInteger, db.ForeignKey("user.id"), nullable=False, index=True )
    created = db.Column( db.DateTime, nullable=False )
    read = db.Column( db.Boolean, nullable=False )
    subject = db.Column( db.String( 128 ), nullable=False )
    content = db.Column( db.Text, nullable=False )

    sender = db.relationship( "User", foreign_keys=[sender_id], uselist=False)
    recipient = db.relationship( "User", foreign_keys=[recipient_id], uselist=False)

    def __init__(
        self,
        sender_id,
        recipient_id,
        content,
        subject,

        read=False
    ):
        self.sender_id = sender_id
        self.recipient_id = recipient_id
        self.content = content
        self.read = read
        self.subject = subject
        self.created = datetime.utcnow()
    
    def __repr__(self):
        return '<Message %r>' % self.id