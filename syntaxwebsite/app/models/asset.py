from app.extensions import db
from app.enums.AssetType import AssetType
from sqlalchemy import Enum
from datetime import datetime

class Asset(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, unique=True, nullable=False, autoincrement=True)
    roblox_asset_id = db.Column(db.BigInteger, nullable=True, default=None, index=True) # Roblox asset ID
    name = db.Column(db.Text, nullable=False) # Asset name
    description = db.Column(db.String(4096), nullable=False) # Asset description
    created_at = db.Column(db.DateTime, nullable=False) # Asset creation date
    updated_at = db.Column(db.DateTime, nullable=False) # Asset last update date
    asset_type = db.Column(Enum(AssetType), nullable=False, index=True) # Asset type (e.g. shirt, pants, etc.)
    asset_genre = db.Column(db.SmallInteger, nullable=False) # Asset genre (e.g. all, town and city, etc.)
    creator_type = db.Column(db.SmallInteger, nullable=False) # Asset creator type (e.g. user, group, etc.)
    creator_id = db.Column(db.BigInteger, nullable=False, index=True) # Asset creator ID
    
    moderation_status = db.Column(db.SmallInteger, nullable=False, index=True) # Asset moderation status ( 0 = Approved, 1 = Pending, 2 = Declined )

    # Economy
    is_for_sale = db.Column(db.Boolean, nullable=False, default=False, index=True) # Is the asset for sale?
    price_robux = db.Column(db.BigInteger, nullable=False, default=0) # Asset price in Robux
    price_tix = db.Column(db.BigInteger, nullable=False, default=0) # Asset price in Tix
    is_limited = db.Column(db.Boolean, nullable=False, default=False, index=True) # Is the asset limited?
    is_limited_unique = db.Column(db.Boolean, nullable=False, default=False) # Is the asset limited unique?
    serial_count = db.Column(db.BigInteger, nullable=False, default=0) # Asset serial count
    sale_count = db.Column(db.BigInteger, nullable=False, default=0) # Asset sale count
    offsale_at = db.Column(db.DateTime, nullable=True, default=None) # Asset offsale date

    def __init__(
        self,
        roblox_asset_id=None,
        name="Asset",
        description="",
        created_at=None,
        updated_at=None,
        asset_type=AssetType.Image,
        asset_genre=0,
        creator_type=0,
        creator_id=1,
        moderation_status=1,

        is_for_sale=False,
        price_robux=0,
        price_tix=0,
        is_limited=False,
        is_limited_unique=False,
        serial_count=0,
        sale_count=0,
        offsale_at=None,

        force_asset_id=None
    ):
        if created_at is None:
            created_at = datetime.utcnow()
        if updated_at is None:
            updated_at = datetime.utcnow()

        self.roblox_asset_id = roblox_asset_id
        self.name = name
        self.description = description
        self.created_at = created_at
        self.updated_at = updated_at
        self.asset_type = asset_type
        self.asset_genre = asset_genre
        self.creator_type = creator_type
        self.creator_id = creator_id
        self.moderation_status = moderation_status

        self.is_for_sale = is_for_sale
        self.price_robux = price_robux
        self.price_tix = price_tix
        self.is_limited = is_limited
        self.is_limited_unique = is_limited_unique
        self.serial_count = serial_count
        self.sale_count = sale_count
        self.offsale_at = offsale_at

        if force_asset_id is not None:
            self.id = force_asset_id
    
    def __repr__(self):
        return f"<Asset {self.id}>"