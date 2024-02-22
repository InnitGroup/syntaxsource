from app.extensions import db

class AssetVersion(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, unique=True, nullable=False, autoincrement=True)
    asset_id = db.Column(db.BigInteger, nullable=False, index=True)
    version = db.Column(db.BigInteger, nullable=False)
    content_hash = db.Column(db.String(512), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False)
    updated_at = db.Column(db.DateTime, nullable=False)
    uploaded_by = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=True, index=True)

    def __init__(
        self,
        asset_id,
        version,
        content_hash,
        created_at,
        uploaded_by=None
    ):
        self.asset_id = asset_id
        self.version = version
        self.content_hash = content_hash
        self.created_at = created_at
        self.updated_at = created_at
        self.uploaded_by = uploaded_by
    
    def __repr__(self):
        return "<AssetVersion id={id} asset_id={asset_id} version={version} content_hash={content_hash} created_at={created_at} updated_at={updated_at}>".format(
            id=self.id,
            asset_id=self.asset_id,
            version=self.version,
            content_hash=self.content_hash,
            created_at=self.created_at,
            updated_at=self.updated_at
        )