import logging

from app.extensions import db, redis_controller
from app.util import redislock

from app.models.user import User
from app.models.groups import Group, GroupIcon, GroupSettings, GroupRole, GroupRolePermission, GroupMember, GroupEconomy, GroupJoinRequest, GroupStatus, GroupWallPost

class GroupExceptions:
    class RolesetDoesNotExist(Exception):
        pass
    class GroupDoesNotExist(Exception):
        pass
    class UserDoesNotExist(Exception):
        pass
    class RolesetNameNotUnique(Exception):
        pass
    class InvalidRankNumber(Exception):
        pass
    class UserNotInGroup(Exception):
        pass
    class UserAlreadyInsideGroup(Exception):
        pass
    class CorruptedGroup(Exception):
        pass
    class GroupNameAlreadyTaken(Exception):
        pass
    class GroupNameNotAllowed(Exception):
        pass
    class InsufficientPermssions(Exception):
        pass

class UserGroupEntry:
    group_id : int = 0
    group_name : str = ""
    group_description : str = ""
    group_owner_id : int = 0

    group_member_count : int = 0

    user_rank : int = 0
    user_roleset : GroupRole | None = None

    def __init__(self, Group : Group, UserRoleset : GroupRole | None):
        self.group_id = Group.id
        self.group_name = Group.name
        self.group_description = Group.description
        self.group_owner_id = Group.owner_id

        self.user_rank = UserRoleset.rank
        self.user_roleset = UserRoleset

        self.group_member_count = GetGroupMemberCount(Group)

def GetUserFromId( UserObj : User | int ) -> User | None:
    """
    Returns a User object from a User ID.
    """
    if isinstance(UserObj, User):
        return UserObj
    else:
        TargetUser : User | None = User.query.filter_by(id=UserObj).first()
        if TargetUser is None:
            raise GroupExceptions.UserDoesNotExist("User does not exist.")
        return TargetUser

def GetRolesetFromId( Role : GroupRole | int ) -> GroupRole | None:
    """
    Returns a GroupRole object from a GroupRole ID.
    """
    if isinstance(Role, GroupRole):
        return Role
    else:
        TargetGroupRole : GroupRole | None = GroupRole.query.filter_by(id=Role).first()
        if TargetGroupRole is None:
            raise GroupExceptions.RolesetDoesNotExist("Roleset does not exist.")
        return TargetGroupRole

def GetGroupFromId( GroupObj : Group | int ) -> Group | None:
    """
    Returns a Group object from a Group ID.
    """
    if isinstance(GroupObj, Group):
        return GroupObj
    else:
        TargetGroup : Group | None = Group.query.filter_by(id=GroupObj).first()
        if TargetGroup is None:
            raise GroupExceptions.GroupDoesNotExist("Group does not exist.")
        return TargetGroup

def RefreshRolesetCount( Role : GroupRole | int ) -> int:
    """
        Recounts the amount of users in a GroupRole and updates the database.
        then returns the amount of users in the role.
    """
    Role : GroupRole | None = GetRolesetFromId(Role)

    TotalMembers : int = GroupMember.query.filter_by(group_id=Role.group_id, group_role_id=Role.id).count()
    Role.member_count = TotalMembers
    db.session.commit()

    return TotalMembers

def GetGroupMemberCount( Group : Group | int ) -> int:
    """
        Returns the amount of members in a group.
    """
    Group : Group | None = GetGroupFromId(Group)
    TotalMembers : int = 0
    for Role in GroupRole.query.filter_by(group_id=Group.id).all():
        TotalMembers += Role.member_count

    return TotalMembers

def GetUserRankInGroup( TargetUser : User | int, TargetGroup : Group | int ) -> int:
    """
        Returns a integer between 0-255 representing the user rank in the group.
        0 - Guest ( Not in the group )
        1 - 244 - Custom ranks
        255 - Group Owner
    """
    TargetUser : User = GetUserFromId(TargetUser)
    TargetGroup : Group = GetGroupFromId(TargetGroup)
    
    UserGroupMembership : GroupMember | None = GroupMember.query.filter_by(user_id=TargetUser.id, group_id=TargetGroup.id).first()
    if UserGroupMembership is None:
        return 0 # Guest
    try:
        UserAssignedRoleset : GroupRole = GetRolesetFromId(UserGroupMembership.group_role_id)
    except GroupExceptions.RolesetDoesNotExist:
        logging.warn(f"User {TargetUser.id} is in group {TargetGroup.id} but the roleset {UserGroupMembership.group_role_id} does not exist.")
        return 0 # Weird edge case where the user is in the group but the roleset doesn't exist
    return UserAssignedRoleset.rank

def GetUserRolesetInGroup( TargetUser : User | int, TargetGroup : Group | int ) -> GroupRole | None:
    """
        Returns a GroupRole object representing the user's roleset in the group.
    """
    TargetUser : User = GetUserFromId(TargetUser)
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    UserGroupMembership : GroupMember | None = GroupMember.query.filter_by(user_id=TargetUser.id, group_id=TargetGroup.id).first()
    if UserGroupMembership is None:
        GuestRoleset : GroupRole | None = GroupRole.query.filter_by(group_id=TargetGroup.id, rank=0).first()
        if GuestRoleset is None:
            raise GroupExceptions.CorruptedGroup("Group has no guest roleset.")
        return GuestRoleset
    try:
        UserAssignedRoleset : GroupRole = GetRolesetFromId(UserGroupMembership.group_role_id)
    except GroupExceptions.RolesetDoesNotExist:
        logging.warn(f"User {TargetUser.id} is in group {TargetGroup.id} but the roleset {UserGroupMembership.group_role_id} does not exist.")
        return None
    return UserAssignedRoleset

def GetUserGroups( TargetUser : User | int ) -> list[UserGroupEntry]:
    """
        Returns a list of UserGroupEntry objects representing the user's groups.
    """
    TargetUser : User = GetUserFromId(TargetUser)

    UserGroups : list[UserGroupEntry] = []
    for UserGroupMembership in GroupMember.query.filter_by(user_id=TargetUser.id).all():
        try:
            UserAssignedRoleset : GroupRole = GetRolesetFromId(UserGroupMembership.group_role_id)
        except GroupExceptions.RolesetDoesNotExist:
            logging.warn(f"User {TargetUser.id} is in group {UserGroupMembership.group_id} but the roleset {UserGroupMembership.group_role_id} does not exist.")
            continue
        GroupObj : Group = GetGroupFromId(UserGroupMembership.group_id)
        UserGroups.append(UserGroupEntry(
            Group=GroupObj,
            UserRoleset=UserAssignedRoleset
        ))
    return UserGroups

def GetGroupRolesets( TargetGroup : Group | int ) -> list[GroupRole]:
    """
        Returns a list of GroupRole objects representing the group's rolesets.
    """
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    return GroupRole.query.filter_by(group_id=TargetGroup.id).order_by(GroupRole.rank.asc()).all()

def CreateGroupRoleset( TargetGroup : Group | int, Name : str, Description : str, Rank : int ) -> GroupRole:
    """
        Creates a new roleset in the group and returns the GroupRole object.
    """
    TargetGroup : Group = GetGroupFromId(TargetGroup)
    if GroupRole.query.filter_by(group_id=TargetGroup.id, name=Name).first() is not None:
        raise GroupExceptions.RolesetNameNotUnique("A roleset with that name already exists.")
    if Rank < 0 or Rank > 255:
        raise GroupExceptions.InvalidRankNumber("Rank must be between 0 and 255.")
    if len(Name) > 255:
        raise ValueError("Name must be less than 255 characters.")
    if len(Description) > 255:
        raise ValueError("Description must be less than 255 characters.")
    
    NewRoleset : GroupRole = GroupRole(
        group_id=TargetGroup.id,
        name=Name,
        description=Description,
        rank=Rank,
        member_count=0
    )
    db.session.add(NewRoleset)
    db.session.commit()

    RolesetPermission : GroupRolePermission = GroupRolePermission(
        group_role_id=NewRoleset.id
    )
    RolesetPermission.view_status = True
    db.session.add(RolesetPermission)
    db.session.commit()

    return NewRoleset

def ChangeUserRole( TargetUser : User | int , TargetRoleset : GroupRole | int ) -> None:
    """
        Changes the user's roleset in the group if possible.
    """
    TargetUser : User = GetUserFromId(TargetUser)
    TargetRoleset : GroupRole = GetRolesetFromId(TargetRoleset)
    TargetGroup : Group = GetGroupFromId(TargetRoleset.group_id)

    if GetUserRankInGroup(TargetUser, TargetRoleset.group_id) == 0:
        raise GroupExceptions.UserNotInGroup("User is not in the group.")
    
    if GetUserRolesetInGroup(TargetUser, TargetRoleset.group_id) == TargetRoleset:
        return
    
    if TargetGroup.owner_id == TargetUser.id and TargetRoleset.rank != 255:
        raise ValueError("Cannot change the owner's roleset.")
    
    UserGroupMembership : GroupMember = GroupMember.query.filter_by(user_id=TargetUser.id, group_id=TargetGroup.id).first()
    OldRolesetId : int = UserGroupMembership.group_role.id
    UserGroupMembership.group_role_id = TargetRoleset.id
    db.session.commit()
    RefreshRolesetCount(OldRolesetId)
    RefreshRolesetCount(TargetRoleset.id)

    return

def AddUserToGroup( TargetUser : User | int , TargetGroup : Group | int, ForceJoin : bool = False ) -> GroupMember | GroupJoinRequest | None:
    """
        Adds the user to the group if possible.
        ForceJoin : bool ( If the group requires manual approval, this will bypass it. )
    """
    TargetUser : User = GetUserFromId(TargetUser)
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    if GetUserRankInGroup(TargetUser, TargetGroup) != 0:
        raise GroupExceptions.UserAlreadyInsideGroup("User is already in the group.")
    
    TargetGroupSettings : GroupSettings | None = GroupSettings.query.filter_by(group_id=TargetGroup.id).first()
    if TargetGroupSettings is None:
        raise ValueError("Group settings do not exist.")
    if TargetGroupSettings.approval_required and not ForceJoin:
        ExisitingJoinRequest : GroupJoinRequest | None = GroupJoinRequest.query.filter_by(user_id=TargetUser.id, group_id=TargetGroup.id).first()
        if ExisitingJoinRequest is not None:
            return ExisitingJoinRequest
        NewJoinRequest : GroupJoinRequest = GroupJoinRequest(
            user_id=TargetUser.id,
            group_id=TargetGroup.id
        )
        db.session.add(NewJoinRequest)
        db.session.commit()
        return GroupJoinRequest
    
    LowestRankRoleset : GroupRole | None = GroupRole.query.filter_by(group_id=TargetGroup.id).filter(GroupRole.rank > 0).order_by(GroupRole.rank.asc()).first()
    if LowestRankRoleset is None:
        raise GroupExceptions.CorruptedGroup("Group has no rolesets.")
    if LowestRankRoleset.rank == 255:
        raise GroupExceptions.CorruptedGroup("Group has no member roleset.")
    
    NewGroupMember : GroupMember = GroupMember(
        user_id=TargetUser.id,
        group_id=TargetGroup.id,
        group_role_id=LowestRankRoleset.id
    )

    db.session.add(NewGroupMember)
    db.session.commit()

    RefreshRolesetCount(LowestRankRoleset)

    return NewGroupMember

def GetJoinRequest( TargetUser : User | int, TargetGroup : Group | int ) -> GroupJoinRequest | None:
    """
        Returns a GroupJoinRequest object from a user and group.
    """
    TargetUser : User = GetUserFromId(TargetUser)
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    return GroupJoinRequest.query.filter_by(user_id=TargetUser.id, group_id=TargetGroup.id).first()

def AcceptJoinRequest( TargetUser : User | int, TargetGroup : Group | int ) -> GroupMember | None:
    """
        Accepts the user's join request.
    """
    ExisitingJoinRequest : GroupJoinRequest | None = GroupJoinRequest.query.filter_by(user_id=TargetUser.id, group_id=TargetGroup.id).first()
    if ExisitingJoinRequest is None:
        raise ValueError("Join request does not exist.")
    db.session.delete(ExisitingJoinRequest)
    db.session.commit()
    return AddUserToGroup(TargetUser, TargetGroup, ForceJoin=True)

def GetRolesetPermission( GroupRoleset : GroupRole | int ) -> GroupRolePermission:
    """
        Returns a GroupRolePermission object from a GroupRole.
    """
    GroupRoleset : GroupRole = GetRolesetFromId(GroupRoleset)
    RolesetPermission : GroupRolePermission | None = GroupRolePermission.query.filter_by(group_role_id=GroupRoleset.id).first()
    if RolesetPermission is None:
        RolesetPermission : GroupRolePermission = GroupRolePermission(
            group_role_id=GroupRoleset.id
        )
        db.session.add(RolesetPermission)
        db.session.commit()
    return RolesetPermission

def ModifyRolesetPermission(
        GroupRoleset : GroupRole, 
        DeleteFromWall : bool = None,
        PostToWall : bool = None,
        InviteMembers : bool = None,
        PostToStatus : bool = None,
        RemoveMembers : bool = None,
        ViewStatus : bool = None,
        ViewWall : bool = None,
        ChangeRank : bool = None,
        AdvertiseGroup : bool = None,
        ManageRelationships : bool = None,
        AddGroupPlaces : bool = None,
        ViewAuditLogs : bool = None,
        CreateItems : bool = None,
        ManageItems : bool = None,
        SpendGroupFunds : bool = None,
        ManageClan : bool = None,
        ManageGroupGames : bool = None
    ) -> None:
    """
        Modifies the roleset's permissions.
    """
    RolesetPermission : GroupRolePermission = GetRolesetPermission(GroupRoleset)
    
    if DeleteFromWall is not None:
        RolesetPermission.delete_from_wall = DeleteFromWall
    if PostToWall is not None:
        RolesetPermission.post_to_wall = PostToWall
    if InviteMembers is not None:
        RolesetPermission.invite_members = InviteMembers
    if PostToStatus is not None:
        RolesetPermission.post_to_status = PostToStatus
    if RemoveMembers is not None:
        RolesetPermission.remove_members = RemoveMembers
    if ViewStatus is not None:
        RolesetPermission.view_status = ViewStatus
    if ViewWall is not None:
        RolesetPermission.view_wall = ViewWall
    if ChangeRank is not None:
        RolesetPermission.change_rank = ChangeRank
    if AdvertiseGroup is not None:
        RolesetPermission.advertise_group = AdvertiseGroup
    if ManageRelationships is not None:
        RolesetPermission.manage_relationships = ManageRelationships
    if AddGroupPlaces is not None:
        RolesetPermission.add_group_places = AddGroupPlaces
    if ViewAuditLogs is not None:
        RolesetPermission.view_audit_logs = ViewAuditLogs
    if CreateItems is not None:
        RolesetPermission.create_items = CreateItems
    if ManageItems is not None:
        RolesetPermission.manage_items = ManageItems
    if SpendGroupFunds is not None:
        RolesetPermission.spend_group_funds = SpendGroupFunds
    if ManageClan is not None:
        RolesetPermission.manage_clan = ManageClan
    if ManageGroupGames is not None:
        RolesetPermission.manage_group_games = ManageGroupGames
    
    db.session.commit()
    return

from app.util.textfilter import FilterText, TextNotAllowedException
from sqlalchemy import func

def SearchGroupByName( GroupName : str ) -> Group | None :
    """
        Returns a Group object from a group name.
    """
    GroupName = GroupName.lower()
    return Group.query.filter(func.lower(Group.name) == GroupName).first()

def isGroupNameAllowed( GroupName : str ) -> bool:
    """
        Returns True if the group name is allowed.
    """
    if len(GroupName) > 255:
        return False
    if len(GroupName) < 3:
        return False
    
    AlphanumericCharacters : int = 0
    for Character in GroupName:
        if Character.isalnum():
            AlphanumericCharacters += 1
    if AlphanumericCharacters < 3:
        return False
    try:
        FilterText( Text = GroupName, ThrowException = True)
    except TextNotAllowedException:
        return False
    return True

def AssertUserHasPermission( TargetUser : User | int, TargetGroup : Group | int, Permission ) -> None: # Permission should be like GroupRolePermission.post_to_status
    """
        Raises an exception if the user does not have the permission.
    """
    TargetUser : User = GetUserFromId(TargetUser)
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    UserRoleset : GroupRole | None = GetUserRolesetInGroup(TargetUser, TargetGroup)
    if UserRoleset is None:
        raise GroupExceptions.CorruptedGroup("Group does not have a guest roleset.")
    RolesetPermission : GroupRolePermission = GetRolesetPermission(UserRoleset)

    if not getattr(RolesetPermission, Permission.name):
        raise GroupExceptions.InsufficientPermssions("User does not have permission.")
    return


def CreateGroup( GroupName : str, GroupDescription : str, GroupOwner : User | int, GroupIconContentHash : str ) -> Group | None :
    """
        Creates a new group and returns the Group object.
    """

    CreateLock = redislock.acquire_lock("group_creation_lock", 30, 5)
    if not CreateLock:
        raise ValueError("Failed to acquire global creation lock.")

    if SearchGroupByName(GroupName) is not None:
        redislock.release_lock("group_creation_lock", CreateLock)
        raise GroupExceptions.GroupNameAlreadyTaken("Group name is already taken.")

    if isGroupNameAllowed(GroupName) is False:
        redislock.release_lock("group_creation_lock", CreateLock)
        raise GroupExceptions.GroupNameNotAllowed("Group name is not allowed.")
    if len(GroupDescription) > 1024:
        redislock.release_lock("group_creation_lock", CreateLock)
        raise ValueError("Group description must be less than 1024 characters.")
    GroupOwner : User = GetUserFromId(GroupOwner)

    NewGroup : Group = Group(
        name=GroupName,
        description=GroupDescription,
        owner_id=GroupOwner.id
    )
    db.session.add(NewGroup)
    db.session.commit()
    redislock.release_lock("group_creation_lock", CreateLock)
    NewGroupSettings : GroupSettings = GroupSettings(
        group_id=NewGroup.id
    )
    db.session.add(NewGroupSettings)

    NewGroupIcon : GroupIcon = GroupIcon(
        group_id=NewGroup.id,
        content_hash=GroupIconContentHash,
        moderation_status=1,
        creator_id=GroupOwner.id
    )
    db.session.add(NewGroupIcon)

    NewGroupEconomy : GroupEconomy = GroupEconomy(
        group_id=NewGroup.id
    )
    db.session.add(NewGroupEconomy)
    db.session.commit()

    GuestGroupRoleset : GroupRole = CreateGroupRoleset(
        TargetGroup=NewGroup,
        Name="Guest",
        Description="A non-group member.",
        Rank=0
    )
    ModifyRolesetPermission(GuestGroupRoleset, ViewStatus=True, ViewWall=True)
    MemberGroupRoleset : GroupRole = CreateGroupRoleset(
        TargetGroup=NewGroup,
        Name="Member",
        Description="A regular group member.",
        Rank=1
    )
    ModifyRolesetPermission(MemberGroupRoleset, ViewStatus=True, ViewWall=True, PostToWall=True)
    AdminGroupRoleset : GroupRole = CreateGroupRoleset(
        TargetGroup=NewGroup,
        Name="Admin",
        Description="A group administrator.",
        Rank=254
    )
    ModifyRolesetPermission(AdminGroupRoleset, ViewStatus=True, ViewWall=True, PostToWall=True)
    OwnerGroupRoleset : GroupRole = CreateGroupRoleset(
        TargetGroup=NewGroup,
        Name="Owner",
        Description="The group's owner.",
        Rank=255
    )
    ModifyRolesetPermission(
        OwnerGroupRoleset,
        DeleteFromWall=True,
        PostToWall=True,
        InviteMembers=True,
        PostToStatus=True,
        RemoveMembers=True,
        ViewStatus=True,
        ViewWall=True,
        ChangeRank=True,
        AdvertiseGroup=True,
        ManageRelationships=True,
        AddGroupPlaces=True,
        ViewAuditLogs=True,
        CreateItems=True,
        ManageItems=True,
        SpendGroupFunds=True,
        ManageClan=True,
        ManageGroupGames=True
    )

    AddUserToGroup(GroupOwner, NewGroup, ForceJoin=True)
    ChangeUserRole(GroupOwner, OwnerGroupRoleset)
    
    return NewGroup

def PostToGroupStatus( Poster : User | int, TargetGroup : Group | int, StatusMessage : str, ForcePost : bool = False ) -> GroupStatus:
    """
        Posts a status to the group.
        ForcePost : bool ( If True this function will not check for the user permissions. )
    """
    Poster : User = GetUserFromId(Poster)
    TargetGroup : Group = GetGroupFromId(TargetGroup)
    if not ForcePost:
        AssertUserHasPermission(Poster, TargetGroup, GroupRolePermission.post_to_status)
    
    FilteredMessage : str = FilterText(Text=StatusMessage)
    if len(FilteredMessage) > 1024:
        raise ValueError("Status message must be less than 1024 characters.")
    NewStatus : GroupStatus = GroupStatus(
        group_id=TargetGroup.id,
        poster_id=Poster.id,
        content=FilteredMessage
    )
    db.session.add(NewStatus)
    db.session.commit()

    return NewStatus

def PostToGroupWall( Poster : User | int, TargetGroup : Group | int, WallMessage : str, ForcePost : bool = False ) -> GroupWallPost:
    """
        Posts a message to the group wall.
        ForcePost : bool ( If True this function will not check for the user permissions. )
    """
    Poster : User = GetUserFromId(Poster)
    TargetGroup : Group = GetGroupFromId(TargetGroup)
    if not ForcePost:
        AssertUserHasPermission(Poster, TargetGroup, GroupRolePermission.post_to_wall)
    
    FilteredMessage : str = FilterText(Text=WallMessage)
    if len(FilteredMessage) > 1024:
        raise ValueError("Wall message must be less than 1024 characters.")
    NewWallPost : GroupWallPost = GroupWallPost(
        group_id=TargetGroup.id,
        poster_id=Poster.id,
        content=FilteredMessage
    )
    db.session.add(NewWallPost)
    db.session.commit()

    return NewWallPost

def GetGroupWallPosts( TargetGroup : Group | int, Page : int = 1, PerPage : int= 10 ) -> list[GroupWallPost]:
    """
        Returns a list of GroupWallPost objects representing the group's wall posts.
    """
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    return GroupWallPost.query.filter_by(group_id=TargetGroup.id).order_by(GroupWallPost.created_at.desc()).paginate(Page, PerPage, False).items

def RemoveUserFromGroup( TargetUser : User | int, TargetGroup : Group | int, AllowOwnerRemove : bool = False ) -> bool:
    """
        Removes the user from the group.
    """
    TargetUser : User = GetUserFromId(TargetUser)
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    if GetUserRankInGroup(TargetUser, TargetGroup.id) == 0:
        raise GroupExceptions.UserNotInGroup("User is not in the group.")
    
    if TargetGroup.owner_id == TargetUser.id and not AllowOwnerRemove:
        raise ValueError("Cannot remove the owner from the group.")
    
    if TargetGroup.owner_id == TargetUser.id:
        TargetGroup.owner_id = None

    UserGroupMembership : GroupMember = GroupMember.query.filter_by(user_id=TargetUser.id, group_id=TargetGroup.id).first()
    OldRolesetId : int = UserGroupMembership.group_role.id
    db.session.delete(UserGroupMembership)
    db.session.commit()

    RefreshRolesetCount(OldRolesetId)

    return True

def isGroupNameAllowed( GroupName : str ) -> tuple[bool, str]:
    """
        Returns True if the group name is allowed.
        If not it returns a bool and a string which is the reason why its not allowed
    """
    if len(GroupName) > 50:
        return False, "Group name must be less than 40 characters."
    if len(GroupName) < 3:
        return False, "Group name must be more than 3 characters."
    
    AlphanumericCharacters : int = 0
    for Character in GroupName:
        if Character.isalnum():
            AlphanumericCharacters += 1
    if AlphanumericCharacters < 3:
        return False, "Group name must contain at least 3 alphanumeric characters."
    try:
        FilterText( Text = GroupName, ThrowException = True)
    except TextNotAllowedException:
        return False, "Group name is not allowed."
    return True, ""

def DeleteGroupWallPost( TargetPost : GroupWallPost, Remover : User | int, ForceDelete : bool = False ) -> None:
    """
        Deletes a group wall post.
        ForceDelete : bool ( If True this function will not check for the user permissions. )
    """
    TargetPost : GroupWallPost = TargetPost
    Remover : User = GetUserFromId(Remover)
    TargetGroup : Group = GetGroupFromId(TargetPost.group_id)
    if not ForceDelete:
        AssertUserHasPermission(Remover, TargetGroup, GroupRolePermission.delete_from_wall)

    db.session.delete(TargetPost)
    db.session.commit()
    return

def GetLatestGroupStatus( TargetGroup : Group | int, ignoreEmpty : bool = True ) -> GroupWallPost | None: 
    """
        Returns the latest group status.
    """
    TargetGroup : Group = GetGroupFromId(TargetGroup)

    LatestGroupStatusPost : GroupStatus | None = GroupStatus.query.filter_by(group_id=TargetGroup.id).order_by(GroupStatus.created_at.desc()).first()
    if LatestGroupStatusPost is None:
        return None
    if ignoreEmpty and LatestGroupStatusPost.content == "":
        return None
    return LatestGroupStatusPost

def SetNewGroupIcon( TargetGroup : Group | int, NewIconHash : str, Uploader : User | int ) -> GroupIcon:
    """
        Sets a new group icon.
    """
    TargetGroup : Group = GetGroupFromId(TargetGroup)
    Uploader : User = GetUserFromId(Uploader)

    if TargetGroup.icon is not None:
        db.session.delete(TargetGroup.icon)
        db.session.commit()
    
    NewGroupIcon : GroupIcon = GroupIcon(
        group_id=TargetGroup.id,
        content_hash=NewIconHash,
        moderation_status=1,
        creator_id=Uploader.id
    )
    db.session.add(NewGroupIcon)
    db.session.commit()

    return NewGroupIcon

def GetUserGroupCount( UserObj : User | int ) -> int:
    """
        Gets the amount of groups a user is in.
    """
    UserObj : User = GetUserFromId(UserObj)

    return GroupMember.query.filter_by(user_id=UserObj.id).count()