from app.extensions import db

class UserAvatar(db.Model):
    user_id = db.Column(db.BigInteger, primary_key=True, nullable=False, unique=True) # User ID
    content_hash = db.Column(db.String(512), nullable=True, default=None) # User avatar content hash
    avatar_type = db.Column(db.SmallInteger, nullable=False, default=1) # Deprecated

    # Refer to https://create.roblox.com/docs/reference/engine/datatypes/BrickColor
    # for BrickColor IDs and names
    # The only IDs that should be used is 1001-1032
    head_color_id = db.Column(db.BigInteger, nullable=False, default=1001) # User avatar head color ID
    torso_color_id = db.Column(db.BigInteger, nullable=False, default=1001) # User avatar torso color ID
    right_arm_color_id = db.Column(db.BigInteger, nullable=False, default=1001) # User avatar right arm color ID
    left_arm_color_id = db.Column(db.BigInteger, nullable=False, default=1001) # User avatar left arm color ID
    right_leg_color_id = db.Column(db.BigInteger, nullable=False, default=1001) # User avatar right leg color ID
    left_leg_color_id = db.Column(db.BigInteger, nullable=False, default=1001) # User avatar left leg color ID

    r15 = db.Column(db.Boolean, nullable=True, default=False) # Is the user using R15?

    height_scale = db.Column(db.Float, nullable=False, default=1.0) # User avatar height scale
    width_scale = db.Column(db.Float, nullable=False, default=1.0) # User avatar width scale
    head_scale = db.Column(db.Float, nullable=False, default=1.0) # User avatar head scale
    proportion_scale = db.Column(db.Float, nullable=False, default=1.0) # User avatar proportion scale
    body_type_scale = db.Column(db.Float, nullable=False, default=1.0) # User avatar body type scale

    def __init__(
            self,
            user_id
    ):
        self.user_id = user_id
    
    def __repr__(self):
        return "<UserAvatar user_id={user_id} content_hash={content_hash} avatar_type={avatar_type} head_color_id={head_color_id} torso_color_id={torso_color_id} right_arm_color_id={right_arm_color_id} left_arm_color_id={left_arm_color_id} right_leg_color_id={right_leg_color_id} left_leg_color_id={left_leg_color_id}>".format(
            user_id=self.user_id,
            content_hash=self.content_hash,
            avatar_type=self.avatar_type,
            head_color_id=self.head_color_id,
            torso_color_id=self.torso_color_id,
            right_arm_color_id=self.right_arm_color_id,
            left_arm_color_id=self.left_arm_color_id,
            right_leg_color_id=self.right_leg_color_id,
            left_leg_color_id=self.left_leg_color_id
        )