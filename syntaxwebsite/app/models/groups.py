from app.extensions import db
from datetime import datetime

class Group(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    owner_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=True, index=True) # Can be nullable since owners can leave groups
    name = db.Column(db.String(255), nullable=False, index=True)
    description = db.Column(db.String(1024), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False)
    updated_at = db.Column(db.DateTime, nullable=False)
    locked = db.Column(db.Boolean, nullable=False, default=False)

    owner = db.relationship('User', backref=db.backref('groups', lazy=True))

    def __init__(
        self,
        owner_id,
        name,
        description,
        created_at=None,
        updated_at=None,
    ):
        if created_at is None:
            created_at = datetime.utcnow()
        if updated_at is None:
            updated_at = datetime.utcnow()

        self.owner_id = owner_id
        self.name = name
        self.description = description
        self.created_at = created_at
        self.updated_at = updated_at
    
    def __repr__(self):
        return '<Group %r>' % self.name

class GroupIcon(db.Model):
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), primary_key=True)
    content_hash = db.Column(db.String(512), nullable=False, index=True)
    moderation_status = db.Column(db.Integer, nullable=False, default=1)
    creator_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)

    created_at = db.Column(db.DateTime, nullable=False)

    group = db.relationship('Group', backref=db.backref('icon', lazy=True, uselist=False), uselist=False)
    creator = db.relationship('User', backref=db.backref('group_icons', lazy=True))

    def __init__(
        self,
        group_id,
        content_hash,
        moderation_status,
        creator_id,
        created_at=None
    ):
        if created_at is None:
            created_at = datetime.utcnow()

        self.group_id = group_id
        self.content_hash = content_hash
        self.moderation_status = moderation_status
        self.creator_id = creator_id
        self.created_at = created_at
    
    def __repr__(self):
        return '<GroupIcon %r>' % self.group_id

class GroupSettings(db.Model):
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), primary_key=True)
    approval_required = db.Column(db.Boolean, nullable=False, default=False)
    enemies_allowed = db.Column(db.Boolean, nullable=False, default=False)
    funds_visible = db.Column(db.Boolean, nullable=False, default=False)
    games_visible = db.Column(db.Boolean, nullable=False, default=False)
    membership_required = db.Column(db.Boolean, nullable=False, default=False)

    last_updated = db.Column(db.DateTime, nullable=False)

    group = db.relationship('Group', backref=db.backref('settings', lazy=True, uselist=False), uselist=False)

    def __init__(
        self,
        group_id,
        approval_required = False,
        enemies_allowed = False,
        funds_visible = False,
        games_visible = False,
        membership_required = False,
        last_updated=None
    ):
        if last_updated is None:
            last_updated = datetime.utcnow()

        self.group_id = group_id
        self.approval_required = approval_required
        self.enemies_allowed = enemies_allowed
        self.funds_visible = funds_visible
        self.games_visible = games_visible
        self.membership_required = membership_required
        self.last_updated = last_updated
    
    def __repr__(self):
        return '<GroupSettings %r>' % self.group_id

class GroupRole(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), nullable=False, index=True)
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.String(255), nullable=False)
    rank = db.Column(db.Integer, nullable=False, default=1)
    member_count = db.Column(db.Integer, nullable=False, default=0)

    created_at = db.Column(db.DateTime, nullable=False)
    updated_at = db.Column(db.DateTime, nullable=False)

    group = db.relationship('Group', backref=db.backref('roles', lazy=True))

    def __init__(
        self,
        group_id,
        name,
        description,
        rank,
        member_count,
        created_at=None,
        updated_at=None
    ):
        if created_at is None:
            created_at = datetime.utcnow()
        if updated_at is None:
            updated_at = datetime.utcnow()

        self.group_id = group_id
        self.name = name
        self.description = description
        self.rank = rank
        self.member_count = member_count
        self.created_at = created_at
        self.updated_at = updated_at

    def __repr__(self):
        return '<GroupRole %r>' % self.name

class GroupRolePermission(db.Model):
    group_role_id = db.Column(db.BigInteger, db.ForeignKey('group_role.id'), primary_key=True)
    # One to one relationship
    group_roleset = db.relationship('GroupRole', backref=db.backref('permissions', uselist=False, lazy=True), lazy=True, uselist=False)

    delete_from_wall = db.Column(db.Boolean, nullable=False, default=False)
    post_to_wall = db.Column(db.Boolean, nullable=False, default=False)
    invite_members = db.Column(db.Boolean, nullable=False, default=False)
    post_to_status = db.Column(db.Boolean, nullable=False, default=False)
    remove_members = db.Column(db.Boolean, nullable=False, default=False)
    view_status = db.Column(db.Boolean, nullable=False, default=False)
    view_wall = db.Column(db.Boolean, nullable=False, default=False)
    change_rank = db.Column(db.Boolean, nullable=False, default=False)
    advertise_group = db.Column(db.Boolean, nullable=False, default=False)
    manage_relationships = db.Column(db.Boolean, nullable=False, default=False)
    add_group_places = db.Column(db.Boolean, nullable=False, default=False)
    view_audit_logs = db.Column(db.Boolean, nullable=False, default=False)
    create_items = db.Column(db.Boolean, nullable=False, default=False)
    manage_items = db.Column(db.Boolean, nullable=False, default=False)
    spend_group_funds = db.Column(db.Boolean, nullable=False, default=False)
    manage_clan = db.Column(db.Boolean, nullable=False, default=False)
    manage_group_games = db.Column(db.Boolean, nullable=False, default=False)

    def __init__(
        self,
        group_role_id
    ):
        self.group_role_id = group_role_id
    
    def __repr__(self):
        return '<GroupRolePermission %r>' % self.group_role_id

class GroupMember(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), nullable=False, index=True)
    user_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)
    group_role_id = db.Column(db.BigInteger, db.ForeignKey('group_role.id'), nullable=False, index=True)

    created_at = db.Column(db.DateTime, nullable=False)

    group = db.relationship('Group', backref=db.backref('members', lazy=True))
    user = db.relationship('User', backref=db.backref('group_members', lazy=True))
    group_role = db.relationship('GroupRole', backref=db.backref('members', lazy=True))

    def __init__(
        self,
        group_id,
        user_id,
        group_role_id,
        created_at=None
    ):
        if created_at is None:
            created_at = datetime.utcnow()
        self.created_at = created_at
        self.group_id = group_id
        self.user_id = user_id
        self.group_role_id = group_role_id
    
    def __repr__(self):
        return '<GroupMember %r>' % self.id

class GroupEconomy(db.Model):
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), primary_key=True)
    robux_balance = db.Column(db.BigInteger, nullable=False, default=0)
    tix_balance = db.Column(db.BigInteger, nullable=False, default=0)

    group = db.relationship('Group', backref=db.backref('economy', lazy=True, uselist=False), uselist=False)

    def __init__(
        self,
        group_id
    ):
        self.group_id = group_id
    
    def __repr__(self):
        return '<GroupEconomy %r>' % self.group_id

class GroupJoinRequest(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), nullable=False, index=True)
    user_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)
    created_at = db.Column(db.DateTime, nullable=False)

    group = db.relationship('Group', backref=db.backref('join_requests', lazy=True))
    user = db.relationship('User', backref=db.backref('group_join_requests', lazy=True))

    def __init__(
        self,
        group_id,
        user_id,
        created_at=None
    ):
        if created_at is None:
            created_at = datetime.utcnow()
        self.group_id = group_id
        self.user_id = user_id
        self.created_at = created_at
    
    def __repr__(self):
        return '<GroupJoinRequest %r>' % self.id

class GroupStatus(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), nullable=False, index=True)
    poster_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)
    content = db.Column(db.String(1024), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False)

    group = db.relationship('Group', backref=db.backref('statuses', lazy=True))
    poster = db.relationship('User', backref=db.backref('group_statuses', lazy=True))

    def __init__(
        self,
        group_id,
        poster_id,
        content,
        created_at=None
    ):
        self.group_id = group_id
        self.poster_id = poster_id
        self.content = content
        if created_at is None:
            created_at = datetime.utcnow()
        self.created_at = created_at
    
    def __repr__(self):
        return '<GroupStatus %r>' % self.id
    
class GroupWallPost(db.Model):
    id = db.Column(db.BigInteger, primary_key=True, autoincrement=True)
    group_id = db.Column(db.BigInteger, db.ForeignKey('group.id'), nullable=False, index=True)
    poster_id = db.Column(db.BigInteger, db.ForeignKey('user.id'), nullable=False, index=True)
    content = db.Column(db.String(1024), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False)

    group = db.relationship('Group', backref=db.backref('wall_posts', lazy=True))
    poster = db.relationship('User', backref=db.backref('group_wall_posts', lazy=True, uselist=False), uselist=False)

    def __init__(
        self,
        group_id,
        poster_id,
        content,
        created_at=None
    ):
        self.group_id = group_id
        self.poster_id = poster_id
        self.content = content
        if created_at is None:
            created_at = datetime.utcnow()
        self.created_at = created_at

    def __repr__(self):
        return '<GroupWallPost %r>' % self.id