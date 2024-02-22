from app.extensions import db
from datetime import datetime
from app.enums.PlaceRigChoice import PlaceRigChoice
from app.enums.PlaceYear import PlaceYear

class Universe( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True, autoincrement=True, nullable=False )
    root_place_id = db.Column( db.BigInteger, nullable=False, index=True, unique=True )
    creator_id = db.Column( db.BigInteger, nullable=False, index=True )
    creator_type = db.Column( db.SmallInteger, nullable=False )

    created_at = db.Column( db.DateTime, nullable=False )
    updated_at = db.Column( db.DateTime, nullable=False )

    place_rig_choice = db.Column( db.Enum( PlaceRigChoice ), nullable=False, default = PlaceRigChoice.UserChoice )
    place_year = db.Column( db.Enum( PlaceYear ), nullable=False, default = PlaceYear.Sixteen )
    is_featured = db.Column( db.Boolean, nullable=False, default = False, index=True )
    minimum_account_age = db.Column( db.Integer, nullable=False, default = 0 )
    bc_required = db.Column( db.Boolean, nullable=False, default = False, index=True )
    allow_direct_join = db.Column( db.Boolean, nullable=False, default = False, index=True )
    is_public = db.Column( db.Boolean, nullable=False, default = True, index=True )
    moderation_status = db.Column( db.SmallInteger, nullable=False, default = 0, index=True )
    visit_count = db.Column( db.BigInteger, nullable=False, default = 0, index=True )

    def __init__(
        self,
        root_place_id : int,
        creator_id : int,
        creator_type : int,

        place_rig_choice : PlaceRigChoice = PlaceRigChoice.UserChoice,
        place_year : PlaceYear = PlaceYear.Sixteen,
        is_featured : bool = False,
        minimum_account_age : int = 0,
        bc_required : bool = False,
        allow_direct_join : bool = False,
        is_public : bool = True,

        updated_at : datetime = None,
        created_at : datetime = None
    ):
        self.root_place_id = root_place_id
        self.creator_id = creator_id
        self.creator_type = creator_type

        self.place_rig_choice = place_rig_choice
        self.place_year = place_year

        self.is_featured = is_featured
        self.minimum_account_age = minimum_account_age
        self.bc_required = bc_required
        self.allow_direct_join = allow_direct_join
        self.is_public = is_public

        self.created_at = datetime.utcnow() if created_at is None else created_at
        self.updated_at = datetime.utcnow() if updated_at is None else updated_at