from app.extensions import db

class FflagValue(db.Model):
    flag_id = db.Column(db.BigInteger, primary_key=True, nullable=False, autoincrement=True) # Flag ID
    group_id = db.Column(db.BigInteger, nullable=False, index=True) # Group ID
    name = db.Column(db.String(128), nullable=False) # Flag name
    
    flag_type = db.Column(db.Integer, nullable=False, default=1) # Flag type ( 1 = bool, 2 = number, 3 = string)
    flag_value = db.Column(db.Text, nullable=False) # Flag value ( base64 )

    def __init__(
        self,
        group_id,
        name,
        flag_type,
        flag_value
    ):
        self.group_id = group_id
        self.name = name
        self.flag_type = flag_type
        self.flag_value = flag_value

    def __repr__(self):
        return "<FflagValue flag_id={flag_id}, group_id={group_id}, name={name}, flag_type={flag_type}>".format(
            flag_id=self.flag_id,
            group_id=self.group_id,
            name=self.name,
            flag_type=self.flag_type
        )
