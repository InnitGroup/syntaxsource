from app.extensions import db   

class UserTradeItem(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    tradeid = db.Column(db.BigInteger, nullable=False, index=True)
    userid = db.Column(db.BigInteger, nullable=False, index=True)
    user_asset_id = db.Column(db.BigInteger, db.ForeignKey("user_asset.id"), nullable=False)

    userasset = db.relationship("UserAsset", backref="tradeitems", lazy=True)

    def __init__(self, tradeid : int, userid : int, user_asset_id : int):
        self.tradeid = tradeid
        self.userid = userid
        self.user_asset_id = user_asset_id
    
    def __repr__(self):
        return f"<UserTradeItem {self.id} {self.tradeid} {self.userid} {self.user_asset_id}>"