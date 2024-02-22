from app.extensions import db
from datetime import datetime

class PlaceBadge( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True )
    associated_place_id = db.Column( db.BigInteger, db.ForeignKey( 'place.placeid' ), index = True ) # DEPRECATED
    icon_image_id = db.Column( db.BigInteger, db.ForeignKey( 'asset.id' ), nullable = False )

    name = db.Column( db.String( 255 ), nullable = False )
    description = db.Column( db.String( 1024 ), nullable = False )
    created_at = db.Column( db.DateTime, nullable = False, index = True )
    updated_at = db.Column( db.DateTime, nullable = False, index = True )

    enabled = db.Column( db.Boolean, nullable = False, default = True )
    asset_reward = db.Column( db.BigInteger, nullable = True, default = None )

    universe_id = db.Column( db.BigInteger, db.ForeignKey( 'universe.id' ), nullable = True, index = True )

    def __init__( self, name, description, icon_image_id, associated_place_id, universe_id):
        self.name = name
        self.description = description
        self.icon_image_id = icon_image_id
        self.associated_place_id = associated_place_id
        self.universe_id = universe_id

        self.created_at = datetime.utcnow()
        self.updated_at = datetime.utcnow()

    def __repr__( self ):
        return '<PlaceBadge %r>' % self.id
    
class UserBadge( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True )
    badge_id = db.Column( db.BigInteger, db.ForeignKey( 'place_badge.id' ), index = True )
    user_id = db.Column( db.BigInteger, db.ForeignKey( 'user.id' ), index = True )

    awarded_at = db.Column( db.DateTime, nullable = False, index = True )

    badge = db.relationship( 'PlaceBadge', backref = db.backref( 'user_badges', lazy = 'dynamic' ) )

    def __init__( self, badge_id, user_id ):
        self.badge_id = badge_id
        self.user_id = user_id

        self.awarded_at = datetime.utcnow()

    def __repr__( self ):
        return '<UserBadge %r>' % self.id