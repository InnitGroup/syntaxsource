from app.extensions import db

class UserAvatarAsset(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True) # ID
    user_id = db.Column(db.BigInteger, nullable=False, index=True) # User ID
    asset_id = db.Column(db.BigInteger, db.ForeignKey('asset.id'), nullable=False, index=True) # Asset ID

    asset = db.relationship('Asset', uselist=False)

    def __init__(
        self,
        user_id,
        asset_id
    ):
        self.user_id = user_id
        self.asset_id = asset_id
    
    def __repr__(self):
        return "<UserAvatarAsset user_id={user_id} asset_id={asset_id}>".format(
            user_id=self.user_id,
            asset_id=self.asset_id
        )