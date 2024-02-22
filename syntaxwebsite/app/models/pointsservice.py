from app.extensions import db

class PointsService(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    placeId = db.Column(db.BigInteger, nullable=False, index=True)
    userId = db.Column(db.BigInteger, nullable=False, index=True)
    points = db.Column(db.BigInteger, nullable=False, default=0)

    def __init__(self, placeId, userId, points):
        self.placeId = placeId
        self.userId = userId
        self.points = points
    
    def __repr__(self):
        return f"<PointsService {self.id} - Place {self.placeId} - User {self.userId} - Points {self.points}>"