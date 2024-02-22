from app.extensions import db

class FflagGroup(db.Model):
    group_id = db.Column(db.BigInteger, primary_key=True, nullable=False, index=True) # Group ID
    name = db.Column(db.String(128), nullable=False) # Group name
    description = db.Column(db.String(512), nullable=False) # Group description
    created_at = db.Column(db.DateTime, nullable=False) # Group creation date
    updated_at = db.Column(db.DateTime, nullable=False) # Group last update date
    enabled = db.Column(db.Boolean, nullable=False) # Group enabled
    apikey = db.Column(db.String(128), nullable=True) # Group API key ( optional )
    gameserver_only = db.Column(db.Boolean, nullable=False) # Group is for gameserver only

    def __init__(
        self,
        group_id,
        name,
        description,
        created_at,
        enabled,
        apikey
    ):
        self.group_id = group_id
        self.name = name
        self.description = description
        self.created_at = created_at
        self.updated_at = created_at
        self.enabled = enabled
        self.apikey = apikey
    
    def __repr__(self):
        return "<FflagGroup group_id={group_id}, name={name}, enabled={enabled}>".format(
            group_id=self.group_id,
            name=self.name,
            enabled=self.enabled
        )