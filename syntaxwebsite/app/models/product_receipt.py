from app.extensions import db
from datetime import datetime

class ProductReceipt( db.Model ):
    receipt_id = db.Column( db.BigInteger, primary_key=True, nullable=False, unique=True, autoincrement=True )
    user_id = db.Column( db.BigInteger, db.ForeignKey( 'user.id' ), nullable=False, index=True )
    product_id = db.Column( db.BigInteger, db.ForeignKey( 'developer_product.productid' ), nullable=False, index=True )
    robux_amount = db.Column( db.BigInteger, nullable=False )
    is_processed = db.Column( db.Boolean, nullable=False, default = False )

    created_at = db.Column( db.DateTime, nullable=False )

    userObj = db.relationship( 'User', lazy='joined', uselist=False )
    productObj = db.relationship( 'DeveloperProduct', lazy='joined', uselist=False )

    def __init__( self, user_id, product_id, robux_amount ):
        self.user_id = user_id
        self.product_id = product_id
        self.robux_amount = robux_amount

        self.created_at = datetime.utcnow()

    def __repr__( self ):
        return "<ProductReceipt receipt_id={receipt_id}, user_id={user_id}, product_id={product_id}, robux_amount={robux_amount}, is_processed={is_processed}, created_at={created_at}>".format(
            receipt_id=self.receipt_id,
            user_id=self.user_id,
            product_id=self.product_id,
            robux_amount=self.robux_amount,
            is_processed=self.is_processed,
            created_at=self.created_at
        )