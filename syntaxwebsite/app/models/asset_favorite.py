from app.extensions import db

class AssetFavorite( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True, autoincrement=True )
    assetid = db.Column( db.BigInteger, nullable=False, index=True )
    userid = db.Column( db.BigInteger, nullable=False, index=True )

    def __init__(self, assetid : int, userid : int):
        self.assetid = assetid
        self.userid = userid
    
    def __repr__(self):
        return f"<AssetFavorite {self.id} {self.assetid} {self.userid}>"