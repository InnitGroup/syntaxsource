from app.extensions import db
from datetime import datetime

class DeveloperProduct( db.Model ):
    productid = db.Column( db.BigInteger, primary_key=True, nullable=False, unique=True, autoincrement=True )
    placeid = db.Column( db.BigInteger, db.ForeignKey( 'place.placeid' ), nullable=True, index=True ) # DEPRECATED
    name = db.Column( db.String( 256 ), nullable=False )
    description = db.Column( db.String( 1024 ), nullable=False )
    iconimage_assetid = db.Column( db.BigInteger, db.ForeignKey( 'asset.id' ), nullable=True, index=True )

    robux_price = db.Column( db.BigInteger, nullable=False, default = 0 )
    sales_count = db.Column( db.BigInteger, nullable=False, default = 0 )
    is_for_sale = db.Column( db.Boolean, nullable=False, default = False )

    created_at = db.Column( db.DateTime, nullable=False )
    updated_at = db.Column( db.DateTime, nullable=False )

    creator_id = db.Column( db.BigInteger, db.ForeignKey( 'user.id' ), nullable=False, index=True )
    universe_id = db.Column( db.BigInteger, db.ForeignKey( 'universe.id' ), nullable=True, index=True )

    placeObj = db.relationship( 'Place', lazy='joined', uselist=False )
    creatorObj = db.relationship( 'User', lazy='joined', uselist=False )
    iconimageObj = db.relationship( 'Asset', lazy='joined', uselist=False )

    def __init__( self, placeid, name, description, iconimage_assetid, creator_id, universe_id ):
        self.placeid = placeid
        self.name = name
        self.description = description
        self.iconimage_assetid = iconimage_assetid
        self.creator_id = creator_id
        self.universe_id = universe_id

        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()

    def __repr__( self ):
        return "<DeveloperProduct productid={productid}, placeid={placeid}, name={name}, description={description}, iconimage_assetid={iconimage_assetid}, moderation_status={moderation_status}, robux_price={robux_price}, sales_count={sales_count}, created_at={created_at}, updated_at={updated_at}, creator_id={creator_id}>".format(
            productid=self.productid,
            placeid=self.placeid,
            name=self.name,
            description=self.description,
            iconimage_assetid=self.iconimage_assetid,
            robux_price=self.robux_price,
            sales_count=self.sales_count,
            created_at=self.created_at,
            updated_at=self.updated_at,
            creator_id=self.creator_id
        )