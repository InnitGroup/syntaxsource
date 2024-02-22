from app.extensions import db
from app.models.asset import Asset
from app.enums.PlaceYear import PlaceYear
from app.enums.PlaceRigChoice import PlaceRigChoice
from app.enums.ChatStyle import ChatStyle

class Place( db.Model ):
    placeid = db.Column( db.BigInteger, db.ForeignKey('asset.id') ,primary_key=True, nullable=False, unique=True ) # Should be the same as the asset id
    visitcount = db.Column( db.BigInteger, nullable=False, default=0 )
    is_public = db.Column( db.Boolean, nullable=False, default=True )
    maxplayers = db.Column( db.BigInteger, nullable=False, default=10 )
    placeyear = db.Column( db.Enum( PlaceYear ), nullable=False, default=PlaceYear.Sixteen )
    featured = db.Column( db.Boolean, nullable=False, default=False, index=True)
    bc_required = db.Column( db.Boolean, nullable=False, default=False, index=True)
    rig_choice = db.Column( db.Enum( PlaceRigChoice ), nullable=False, default=PlaceRigChoice.UserChoice )
    chat_style = db.Column( db.Enum( ChatStyle ), nullable=False, default=ChatStyle.ClassicAndBubble )
    min_account_age = db.Column( db.Integer, nullable=False, default=0)

    parent_universe_id = db.Column( db.BigInteger, db.ForeignKey('universe.id'), nullable=True, index=True )

    assetObj = db.relationship( 'Asset', backref=db.backref('place', lazy=True, uselist=False), uselist=False )

    def __init__(
        self,
        placeid,
        visitcount = 0,
        is_public = True,
        maxplayers = 10,
        placeyear = PlaceYear.Sixteen,
        rig_choice = PlaceRigChoice.UserChoice,
        chat_style = ChatStyle.ClassicAndBubble,
        min_account_age = 0,
        parent_universe_id = None
    ):
        self.placeid = placeid
        self.visitcount = visitcount
        self.is_public = is_public
        self.maxplayers = maxplayers
        self.placeyear = placeyear
        self.rig_choice = rig_choice
        self.chat_style = chat_style
        self.min_account_age = min_account_age
        self.parent_universe_id = parent_universe_id

    def __repr__(self):
        return "<Place placeid={placeid}, visitcount={visitcount}, is_public={is_public}, maxplayers={maxplayers}>".format(
            placeid=self.placeid,
            visitcount=self.visitcount,
            is_public=self.is_public,
            maxplayers=self.maxplayers
        )