from app.extensions import db

class AssetThumbnail(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, unique=True, nullable=False, autoincrement=True)
    asset_id = db.Column(db.BigInteger, db.ForeignKey('asset.id'), nullable=False, index=True) # Asset ID
    asset_version_id = db.Column(db.BigInteger, nullable=False) # Asset version ID
    content_hash = db.Column(db.String(512), nullable=False) # Asset thumbnail content hash
    created_at = db.Column(db.DateTime, nullable=False) # Asset thumbnail creation date
    updated_at = db.Column(db.DateTime, nullable=False) # Asset thumbnail last update date
    moderation_status = db.Column(db.SmallInteger, nullable=False) # Asset thumbnail moderation status ( 0 = Approved, 1 = Pending, 2 = Declined )

    asset = db.relationship('Asset', backref=db.backref('thumbnails', lazy=True, uselist=True), uselist=False)
    def __init__(
        self,
        asset_id,
        asset_version_id,
        content_hash,
        created_at,
        moderation_status
    ):
        self.asset_id = asset_id
        self.asset_version_id = asset_version_id
        self.content_hash = content_hash
        self.created_at = created_at
        self.updated_at = created_at
        self.moderation_status = moderation_status
    
    def __repr__(self):
        return "<AssetThumbnail asset_id={asset_id} asset_version_id={asset_version_id} content_hash={content_hash} created_at={created_at} updated_at={updated_at} moderation_status={moderation_status}>".format(
            asset_id=self.asset_id,
            asset_version_id=self.asset_version_id,
            content_hash=self.content_hash,
            created_at=self.created_at,
            updated_at=self.updated_at,
            moderation_status=self.moderation_status
        )