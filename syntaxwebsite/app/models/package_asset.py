from app.extensions import db

class PackageAsset( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True, autoincrement=True)
    package_asset_id = db.Column( db.BigInteger, nullable=False, index=True )
    asset_id = db.Column( db.BigInteger, nullable=False )

    def __init__( self, package_asset_id, asset_id ):
        self.package_asset_id = package_asset_id
        self.asset_id = asset_id

    def __repr__( self ):
        return '<PackageAsset %r>' % self.package_asset_id