from app.extensions import db

# This is used for the asset moderation system to link two assets together, eg. a Image and Shirt
# So the moderator does not need to approve both assets

class AssetModerationLink(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, unique=True, nullable=False, autoincrement=True)
    ParentAssetId = db.Column(db.BigInteger, db.ForeignKey('asset.id'), nullable=False, index=True) # Parent asset ID, eg. Shirt
    ChildAssetId = db.Column(db.BigInteger, db.ForeignKey('asset.id'), nullable=False, index=True) # Child asset ID eg. Image

    ParentAsset = db.relationship("Asset", foreign_keys=[ParentAssetId], uselist=False, lazy="joined")
    ChildAsset = db.relationship("Asset", foreign_keys=[ChildAssetId], uselist=False, lazy="joined")

    def __init__(
        self,
        ParentAssetId,
        ChildAssetId
    ):
        self.ParentAssetId = ParentAssetId
        self.ChildAssetId = ChildAssetId
    
    def __repr__(self):
        return "<AssetModerationLink id={id} ParentAssetId={ParentAssetId} ChildAssetId={ChildAssetId}>".format(
            id=self.id,
            ParentAssetId=self.ParentAssetId,
            ChildAssetId=self.ChildAssetId
        )