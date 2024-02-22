from app.models.asset import Asset
from app.models.asset_version import AssetVersion
from app.models.user import User
from datetime import datetime
from app.extensions import db
from app.util import auth, redislock

def CreateNewAssetVersion( Asset : Asset, FileHash : str, ForceNewVersion : bool = False, UploadedBy : User | None = None ) -> AssetVersion:
    """
    Creates a new asset version for the given asset
    Returns the new asset version
    """
    AssetLockName = f"createassetversion_{Asset.id}"
    CreateLock = redislock.acquire_lock(AssetLockName, acquire_timeout=20, lock_timeout=1)
    if CreateLock is None:
        return None

    ExistingAssetVersion : AssetVersion = AssetVersion.query.filter_by( asset_id=Asset.id ).first()
    if ExistingAssetVersion is None:
        NewAssetVersion : AssetVersion = AssetVersion(
            asset_id = Asset.id,
            version = 1,
            content_hash = FileHash,
            created_at = datetime.utcnow(),
            uploaded_by = UploadedBy.id if UploadedBy is not None else None
        )
        db.session.add(NewAssetVersion)
        db.session.commit()
        redislock.release_lock(AssetLockName, CreateLock)
        return NewAssetVersion
    
    ExistingAssetVersionWithSameHash : AssetVersion = AssetVersion.query.filter_by( asset_id=Asset.id, content_hash=FileHash ).first()
    if ExistingAssetVersionWithSameHash is not None and not ForceNewVersion:
        redislock.release_lock(AssetLockName, CreateLock)
        return ExistingAssetVersionWithSameHash
    
    CurrentVersion : int = AssetVersion.query.filter_by( asset_id=Asset.id ).order_by(AssetVersion.version.desc()).first().version
    NewAssetVersion : AssetVersion = AssetVersion(
        asset_id = Asset.id,
        version = CurrentVersion + 1,
        content_hash = FileHash,
        created_at = datetime.utcnow(),
        uploaded_by = UploadedBy.id if UploadedBy is not None else None
    )
    db.session.add(NewAssetVersion)
    db.session.commit()
    redislock.release_lock(AssetLockName, CreateLock)
    return NewAssetVersion

def GetLatestAssetVersion( Asset : Asset ) -> AssetVersion:
    """
    Gets the latest asset version for the given asset
    Returns the latest asset version
    """
    return AssetVersion.query.filter_by( asset_id=Asset.id ).order_by(AssetVersion.version.desc()).first()

def GetAssetVersion( Asset : Asset, Version : int ) -> AssetVersion:
    """
    Gets the asset version for the given asset and version
    Returns the asset version
    """
    return AssetVersion.query.filter_by( asset_id=Asset.id, version=Version ).first()
