from app.extensions import db

class AssetVote( db.Model ):
    id = db.Column( db.BigInteger, primary_key=True )
    assetid = db.Column( db.BigInteger, nullable=False, index=True )
    userid = db.Column( db.BigInteger, nullable=False, index=True )
    vote = db.Column( db.Boolean, nullable=False, default=True )

    def __init__(self, assetid : int, userid : int, vote : bool):
        self.assetid = assetid
        self.userid = userid
        self.vote = vote

    def __repr__(self):
        return f"<AssetVote {self.id} {self.assetid} {self.userid} {self.vote}>"