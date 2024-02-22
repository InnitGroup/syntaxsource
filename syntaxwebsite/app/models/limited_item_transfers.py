from app.extensions import db
from app.enums.LimitedItemTransferMethod import LimitedItemTransferMethod

from datetime import datetime

class LimitedItemTransfer(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)

    original_owner_id = db.Column(db.BigInteger, nullable=False, index=True)
    new_owner_id = db.Column(db.BigInteger, nullable=False, index=True)

    asset_id = db.Column(db.BigInteger, nullable=False, index=True)
    user_asset_id = db.Column(db.BigInteger, nullable=False, index=True)
    transferred_at = db.Column(db.DateTime, nullable=False)

    transfer_method = db.Column(db.Enum(LimitedItemTransferMethod), nullable=False, index=True)
    purchased_price = db.Column(db.BigInteger, nullable=True, default=None)
    associated_trade_id = db.Column(db.BigInteger, nullable=True, default=None)

    def __init__(self, original_owner_id, new_owner_id, asset_id, user_asset_id, transfer_method=LimitedItemTransferMethod.Purchase, transferred_at=None, purchased_price=None, associated_trade_id = None):
        self.original_owner_id = original_owner_id
        self.new_owner_id = new_owner_id
        self.asset_id = asset_id
        self.user_asset_id = user_asset_id
        self.transfer_method = transfer_method

        if transferred_at is None:
            self.transferred_at = datetime.utcnow()
        else:
            self.transferred_at = transferred_at
        
        self.purchased_price = purchased_price
        self.associated_trade_id = associated_trade_id