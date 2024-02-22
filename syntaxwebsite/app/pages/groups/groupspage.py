from flask import Blueprint, render_template, request, redirect, url_for, flash, abort, jsonify, make_response
from app.services import groups, economy
from app.models.user import User
from app.models.groups import Group, GroupMember, GroupJoinRequest, GroupRole, GroupRolePermission, GroupWallPost, GroupEconomy, GroupIcon, GroupSettings, GroupStatus
from app.util import auth, websiteFeatures, textfilter, s3helper, membership, transactions
from app.extensions import db, limiter, csrf
from slugify import slugify
from functools import wraps
from app.util.assetvalidation import ValidateClothingImage
from app.enums.MembershipType import MembershipType
from app.enums.TransactionType import TransactionType
import hashlib
import logging
from io import BytesIO
import string

allowedCharacters = string.ascii_letters + string.digits + string.punctuation + " " + "™®"

groups_page = Blueprint('groups_page', __name__, template_folder='templates')

def CountAlnumericCharacters( string : str ):
    count = 0
    for char in string:
        if char.isalnum():
            count += 1
    return count

def GetUserGroups( user : User ) -> list[GroupMember]:
    return GroupMember.query.filter_by(user_id=user.id).all()

def AdminPermissionRequired( GroupObj : Group | int, TargetUser : User | int ):
    GroupObj : Group = groups.GetGroupFromId(GroupObj)
    TargetUser : User = groups.GetUserFromId(TargetUser)
    if GroupObj is None or TargetUser is None:
        return abort(403)
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(TargetUser, GroupObj)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions

    isGroupAdmin = UserPermissions.change_rank or \
        UserPermissions.manage_clan or \
        UserPermissions.manage_relationships or \
        UserPermissions.remove_members or \
        UserPermissions.spend_group_funds
    
    if not isGroupAdmin:
        return abort(403)

@groups_page.route('/groups/admin/<int:groupid>', methods=['GET'])
@auth.authenticated_required
def groupadmin(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    if groupObject is None:
        return abort(404)
    AdminPermissionRequired(groupObject, AuthenticatedUser)

    return redirect(f"/groups/admin/{groupid}/info")

@groups_page.route("/groups/admin/<int:groupid>/kick/<int:userid>", methods=['DELETE'])
@auth.authenticated_required
@limiter.limit("25/minute")
def groupadmin_kickmember(groupid, userid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    AdminPermissionRequired(groupObject, AuthenticatedUser)
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions

    if not UserPermissions.remove_members:
        flash("You do not have permission to kick a user.", "error")
        return jsonify({"success": False}),403
    
    try:
        TargetUser : User = groups.GetUserFromId(userid)
    except groups.GroupExceptions.UserDoesNotExist:
        flash("The user you are trying to kick does not exist.", "error")
        return jsonify({"success": False}),404

    if TargetUser == AuthenticatedUser:
        flash("You cannot kick yourself.", "error")
        return jsonify({"success": False}),403
    
    TargetUserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(TargetUser, groupObject)
    if TargetUserCurrentRole.rank == 0:
        flash("This user is not a member of this group.", "error")
        return jsonify({"success": False}),400
    
    if TargetUserCurrentRole.rank >= UserCurrentRole.rank:
        flash("You cannot kick a user with the same or higher rank than you.", "error")
        return jsonify({"success": False}),403
    
    groups.RemoveUserFromGroup(TargetUser, groupObject)
    flash(f"You have kicked {TargetUser.username} from this group.", "success")
    return jsonify({"success": True}),200

@groups_page.route("/groups/admin/<int:groupid>/members", methods=['GET'])
@auth.authenticated_required
def groupadmin_members(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    if groupObject is None:
        return abort(404)
    AdminPermissionRequired(groupObject, AuthenticatedUser)
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions

    searchByUsername = request.args.get("search", None, str)
    searchByRole = request.args.get("role", None, int) # Role Id
    pageNumber = request.args.get("page", 1, int)

    if searchByUsername is not None:
        if CountAlnumericCharacters(searchByUsername) < 3:
            searchByUsername = None
    if searchByRole is not None:
        try:
            searchByRole : GroupRole = groups.GetRolesetFromId(searchByRole)
            if searchByRole.group_id != groupObject.id:
                searchByRole = None
        except groups.GroupExceptions.RolesetDoesNotExist:
            searchByRole = None
    if pageNumber < 1:
        pageNumber = 1
    
    if searchByUsername is None and searchByRole is None:
        Members : list[GroupMember] = GroupMember.query.filter_by(group_id=groupObject.id)
    elif searchByUsername is None and searchByRole is not None:
        Members : list[GroupMember] = GroupMember.query.filter_by(group_id=groupObject.id, group_role_id=searchByRole.id)
    elif searchByUsername is not None and searchByRole is None:
        Members : list[GroupMember] = GroupMember.query.filter_by(group_id=groupObject.id).join(User).filter(User.username.ilike(f"%{searchByUsername}%"))
    else:
        Members : list[GroupMember] = GroupMember.query.filter_by(group_id=groupObject.id, group_role_id=searchByRole.id).join(User).filter(User.username.ilike(f"%{searchByUsername}%"))

    Members = Members.order_by(GroupMember.created_at.desc()).paginate(page = pageNumber, per_page = 12, error_out = False)
    SortedRoles = groupObject.roles
    SortedRoles.sort(key=lambda x: x.rank, reverse=False)

    JoinRequestCount = GroupJoinRequest.query.filter_by(group_id=groupObject.id).count()

    return render_template(
        "groups/admin_subpage/members.html", 
        group=groupObject, 
        user=AuthenticatedUser, 
        role=UserCurrentRole, 
        permissions=UserPermissions, 
        page="members",
        searchByUsername=searchByUsername,
        searchByRole=searchByRole,
        pageNumber=pageNumber,
        Members=Members,
        SortedRoles = SortedRoles,
        JoinRequestCount=JoinRequestCount
    )

@groups_page.route("/groups/admin/<int:groupid>/change_role/<int:userid>/<int:roleid>", methods=['POST'])
@auth.authenticated_required
@limiter.limit("15/minute")
def groupadmin_members_change_role(groupid, userid, roleid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    if groupObject is None:
        return abort(404)
    AdminPermissionRequired(groupObject, AuthenticatedUser)
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    if not UserPermissions.change_rank:
        flash("You do not have permission to change a user's role.", "error")
        return jsonify({"success": False}),403
    if userid == AuthenticatedUser.id:
        flash("You cannot change your own role.", "error")
        return jsonify({"success": False}),400
    
    try:
        TargetRole : GroupRole = groups.GetRolesetFromId(roleid)
        if TargetRole.group_id != groupObject.id:
            TargetRole = None
    except groups.GroupExceptions.RolesetDoesNotExist:
        TargetRole = None
    if TargetRole is None or TargetRole.rank == 0:
        flash("The role you are trying to set is invalid.", "error")
        return jsonify({"success": False}),400
    if TargetRole.rank > UserCurrentRole.rank:
        flash("You cannot set a user's role to a role higher than your own.", "error")
        return jsonify({"success": False}),400
    
    try:
        TargetUser : User = groups.GetUserFromId(userid)
    except groups.GroupExceptions.UserDoesNotExist:
        flash("The user you are trying to set a role for does not exist.", "error")
        return jsonify({"success": False}),400

    TargetUserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(TargetUser, groupObject)
    if TargetUserCurrentRole.rank > UserCurrentRole.rank:
        flash("You cannot set a higher ranking user's role.", "error")
        return jsonify({"success": False}),400
    if TargetUserCurrentRole.rank == 0: # Not in group
        flash("The user you are trying to set a role for is not in the group.", "error")
        return jsonify({"success": False}),400
    if TargetUserCurrentRole == TargetRole:
        flash("The user you are trying to set a role for already has that role.", "error")
        return jsonify({"success": True}),200
    
    groups.ChangeUserRole(TargetUser, TargetRole)
    flash(f"Successfully changed {TargetUser.username}'s role to {TargetRole.name}.", "success")
    return jsonify({"success": True}),200

@groups_page.route("/groups/admin/<int:groupid>/members", methods=['POST'])
@auth.authenticated_required
@csrf.exempt
def groupadmin_members_search(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    if groupObject is None:
        return abort(404)
    AdminPermissionRequired(groupObject, AuthenticatedUser)
    searchInput = request.form.get("search-input", "", str)
    searchByRole = request.form.get("search-by", 0, int)

    if searchByRole == 0:
        searchByRole = None
    if searchInput == "":
        searchInput = None
    
    if searchInput is None and searchByRole is None:
        return redirect(f"/groups/admin/{groupid}/members")
    elif searchInput is None and searchByRole is not None:
        return redirect(f"/groups/admin/{groupid}/members?role={searchByRole}")
    elif searchInput is not None and searchByRole is None:
        return redirect(f"/groups/admin/{groupid}/members?search={searchInput}")
    else:
        return redirect(f"/groups/admin/{groupid}/members?search={searchInput}&role={searchByRole}")

@groups_page.route("/groups/admin/<int:groupid>/members/requests", methods=['GET'])
@auth.authenticated_required
def groupadmin_members_requests(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    if not groupObject.settings.approval_required or not UserPermissions.invite_members:
        return abort(404)
    PageNumber = request.args.get( key = "page", default=1, type=int)
    JoinRequests : list[GroupJoinRequest] = GroupJoinRequest.query.filter_by(group_id=groupObject.id).order_by(GroupJoinRequest.created_at.desc()).paginate( page=PageNumber, per_page=12, error_out=False)
    return render_template("groups/admin_subpage/join_requests.html", group=groupObject, user=AuthenticatedUser, role=UserCurrentRole, permissions=UserPermissions, page="members", JoinRequests=JoinRequests)

@groups_page.route("/groups/admin/<int:groupid>/members/requests/deny/<int:userid>", methods=['GET'])
@auth.authenticated_required
def groupadmin_members_requests_deny(groupid, userid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    if not groupObject.settings.approval_required or not UserPermissions.invite_members:
        return abort(404)
    
    UserJoinRequest : GroupJoinRequest = GroupJoinRequest.query.filter_by(group_id=groupObject.id, user_id=userid).first()
    if UserJoinRequest is None:
        flash("Join request does not exist.", "error")
        return redirect(f"/groups/admin/{groupid}/members/requests")
    db.session.delete(UserJoinRequest)
    db.session.commit()
    return redirect(f"/groups/admin/{groupid}/members/requests")

@groups_page.route("/groups/admin/<int:groupid>/members/requests/accept/<int:userid>", methods=['GET'])
@auth.authenticated_required
def groupadmin_members_requests_accept(groupid, userid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    if not groupObject.settings.approval_required or not UserPermissions.invite_members:
        return abort(404)
    
    UserJoinRequest : GroupJoinRequest = GroupJoinRequest.query.filter_by(group_id=groupObject.id, user_id=userid).first()
    if UserJoinRequest is None:
        flash("Join request does not exist.", "error")
        return redirect(f"/groups/admin/{groupid}/members/requests")
    UserGroupCount = groups.GetUserGroupCount(userid)
    UserMembership : MembershipType = membership.GetUserMembership(userid)
    GroupLimit = {
        MembershipType.NonBuildersClub: 5,
        MembershipType.BuildersClub: 10,
        MembershipType.TurboBuildersClub: 20,
        MembershipType.OutrageousBuildersClub: 100
    }
    if UserGroupCount >= GroupLimit[UserMembership]:
        flash("This user has reached the maximum number of groups they can join.", "error")
        return redirect(f"/groups/admin/{groupid}/members/requests")
    db.session.delete(UserJoinRequest)
    db.session.commit()
    groups.AddUserToGroup(userid, groupObject, ForceJoin=True)

    return redirect(f"/groups/admin/{groupid}/members/requests")

@groups_page.route("/groups/admin/<int:groupid>/members/requests/deny_all", methods=['POST'])
@auth.authenticated_required
def groupadmin_members_requests_deny_all(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    if not groupObject.settings.approval_required or not UserPermissions.invite_members:
        return abort(404)

    AllJoinRequests : list[GroupJoinRequest] = GroupJoinRequest.query.filter_by(group_id=groupObject.id).all()
    for joinRequest in AllJoinRequests:
        db.session.delete(joinRequest)
    db.session.commit()
    return redirect(f"/groups/admin/{groupid}/members/requests")

@groups_page.route("/groups/admin/<int:groupid>/info", methods=['GET'])
@auth.authenticated_required
def groupadmin_info(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    if groupObject is None:
        return abort(404)
    AdminPermissionRequired(groupObject, AuthenticatedUser)
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    return render_template("groups/admin_subpage/groupinfo.html", group=groupObject, user=AuthenticatedUser, role=UserCurrentRole, permissions=UserPermissions, page="info")

@groups_page.route("/groups/admin/<int:groupid>/info", methods=['POST'])
@auth.authenticated_required
@limiter.limit("10/minute")
def groupadmin_info_post(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != groupObject.owner_id:
        return abort(403)
    AdminPermissionRequired(groupObject, AuthenticatedUser)

    ImageFile = request.files.get("file")
    NewDescription = request.form.get("description")

    if ImageFile is not None and ImageFile.filename != "":
        if ImageFile.content_length > 1024 * 1024 * 2: # 2MB
            flash("Icon is too large, must be less than 2MB", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        if ImageFile.content_type not in ["image/png", "image/jpeg"]:
            flash("Icon must be a PNG or JPEG image", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        # Validate icon
        NewIcon = ValidateClothingImage( ImageFile, verifyResolution=False, validateFileSize=False, returnImage=True )
        if NewIcon is False or NewIcon is None:
            flash("Icon is invalid", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        if NewIcon.width != NewIcon.height:
            flash("Icon must be a square", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        if NewIcon.width > 1024 or NewIcon.height > 1024:
            flash("Icon must be less than 1024x1024", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        if NewIcon.width < 128 or NewIcon.height < 128:
            flash("Icon must be at least 128x128", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        
        ImageFile = BytesIO()
        NewIcon.save(ImageFile, format="PNG")

        ImageFile.seek(0)
        IconImageHash = hashlib.sha512(ImageFile.read()).hexdigest()
        if not s3helper.DoesKeyExist(IconImageHash):
            ImageFile.seek(0)
            s3helper.UploadBytesToS3(ImageFile.read(), IconImageHash, contentType="image/png")
        
        groups.SetNewGroupIcon(groupObject, IconImageHash, AuthenticatedUser)
        flash("Group icon updated", "success")
    
    if NewDescription != groupObject.description:
        if len(NewDescription) > 1024:
            flash("Description must be less than 1024 characters", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        if CountAlnumericCharacters(NewDescription) < 10:
            flash("Description must contain at least 10 alphanumeric characters", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        NewLineCount = NewDescription.count("\n")
        if NewLineCount > 15:
            flash("Description must contain less than 15 newlines", "error")
            return redirect(f"/groups/admin/{groupid}/info")
        
        NewDescription = textfilter.FilterText(NewDescription)
        groupObject.description = NewDescription
        db.session.commit()
        flash("Group description updated", "success")
    
    return redirect(f"/groups/admin/{groupid}/info")

@groups_page.route("/groups/admin/<int:groupid>/settings", methods=['GET'])
@auth.authenticated_required
def groupadmin_settings(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    if groupObject is None:
        return abort(404)
    AdminPermissionRequired(groupObject, AuthenticatedUser)
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    return render_template("groups/admin_subpage/settings.html", group=groupObject, user=AuthenticatedUser, role=UserCurrentRole, permissions=UserPermissions, page="settings")

@groups_page.route("/groups/admin/<int:groupid>/settings", methods=['POST'])
@auth.authenticated_required
@limiter.limit("15/minute")
def groupadmin_settings_post(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    if groupObject is None:
        return abort(404)
    if groupObject.owner_id != AuthenticatedUser.id:
        return abort(403)
    
    approval_required = request.form.get("approval-required", "off", str) == "on"
    membership_required = request.form.get("membership-required", "off", str) == "on"
    enemy_declarations_allowed = request.form.get("declarations-allowed", "off", str) == "on"
    funds_visible = request.form.get("funds-visible", "off", str) == "on"
    games_visible = request.form.get("games-visible", "off", str) == "on"

    groupSettings : GroupSettings = groupObject.settings
    groupSettings.approval_required = approval_required
    groupSettings.membership_required = membership_required
    groupSettings.enemies_allowed = enemy_declarations_allowed
    groupSettings.funds_visible = funds_visible
    groupSettings.games_visible = games_visible
    if not approval_required:
        AllJoinRequests : list[GroupJoinRequest] = GroupJoinRequest.query.filter_by(group_id=groupObject.id).all()
        for joinRequest in AllJoinRequests:
            db.session.delete(joinRequest)
    db.session.commit()

    flash("Group settings updated", "success")
    return redirect(f"/groups/admin/{groupid}/settings")

@groups_page.route('/groups/admin/<int:groupid>/roles', methods=["GET"])
@auth.authenticated_required
def groupadmin_roles(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    AdminPermissionRequired(groupObject, AuthenticatedUser)

    # Redirect to the top role
    TopRole : GroupRole = GroupRole.query.filter_by(group_id=groupObject.id).order_by(GroupRole.rank.desc()).first()
    return redirect(f"/groups/admin/{groupid}/roles/{TopRole.id}/view")

@groups_page.route('/groups/admin/<int:groupid>/roles/<int:roleid>/view', methods=["GET"])
@auth.authenticated_required
def groupadmin_role_view(groupid, roleid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    AdminPermissionRequired(groupObject, AuthenticatedUser)

    try:
        roleObject : GroupRole = groups.GetRolesetFromId(roleid)
    except groups.GroupExceptions.RolesetDoesNotExist:
        return abort(404)
    if roleObject.group_id != groupObject.id:
        return abort(404)

    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    AllGroupRoles : list[GroupRole] = GroupRole.query.filter_by(group_id=groupObject.id).order_by(GroupRole.rank.desc()).all()
    return render_template("groups/admin_subpage/roles.html", group=groupObject, user=AuthenticatedUser, roles=AllGroupRoles, page="roles", role=UserCurrentRole, permissions=UserPermissions, selectedrole = roleObject)

@groups_page.route('/groups/admin/<int:groupid>/roles/<int:roleid>/update', methods=["POST"])
@auth.authenticated_required
@limiter.limit("10/minute")
def groupadmin_role_update(groupid, roleid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != groupObject.owner_id:
        return abort(403)
    try:
        TargetRole : GroupRole = groups.GetRolesetFromId(roleid)
    except groups.GroupExceptions.RolesetDoesNotExist:
        return abort(404)
    if TargetRole.group_id != groupObject.id:
        return abort(404)

    RoleName = request.form.get("role-name", TargetRole.name, str)
    RoleDescription = request.form.get("role-description", TargetRole.description, str)
    RoleRank = request.form.get("role-rank", TargetRole.rank, int)
    
    ViewWallPermission = request.form.get("view_wall", "off", str) == "on"
    PostWallPermission = request.form.get("post_to_wall", "off", str) == "on"
    DeleteWallPermission = request.form.get("delete_from_wall", "off", str) == "on"
    ViewGroupShoutPermission = request.form.get("view_status", "off", str) == "on"
    PostGroupShoutPermission = request.form.get("post_to_status", "off", str) == "on"

    ManageMembersPermission = request.form.get("change_rank", "off", str) == "on"
    AcceptJoinsPermission = request.form.get("invite_members", "off", str) == "on"
    RemoveMembersPermission = request.form.get("remove_members", "off", str) == "on"

    CreateItemsPermission = request.form.get("create_items", "off", str) == "on"
    ManageItemsPermission = request.form.get("manage_items", "off", str) == "on"
    ManageGroupGamesPermission = request.form.get("manage_group_games", "off", str) == "on"

    ManageRelationshipsPermission = request.form.get("manage_relationships", "off", str) == "on"
    ViewAuditLogsPermission = request.form.get("view_audit_logs", "off", str) == "on"

    if TargetRole.rank == 0:
        if RoleName != TargetRole.name or RoleDescription != TargetRole.description or RoleRank != TargetRole.rank:
            return abort(400)
        if CreateItemsPermission or ManageItemsPermission or ManageGroupGamesPermission:
            flash("You cannot give the guest role Asset permissions.", "error")
            return redirect(f"/groups/admin/{groupid}/roles/{roleid}/view")
    
    FilteredRoleName = textfilter.FilterText(RoleName)
    FilteredRoleDescription = textfilter.FilterText(RoleDescription)
    if len(FilteredRoleName) > 32:
        flash("Role name must be less than 32 characters", "error")
        return redirect(f"/groups/admin/{groupid}/roles/{roleid}/view")
    if len(FilteredRoleDescription) > 256:
        flash("Role description must be less than 256 characters", "error")
        return redirect(f"/groups/admin/{groupid}/roles/{roleid}/view")
    if CountAlnumericCharacters(FilteredRoleName) < 3:
        flash("Role name must contain at least 3 alphanumeric characters", "error")
        return redirect(f"/groups/admin/{groupid}/roles/{roleid}/view")
    
    if RoleRank < 1 or RoleRank > 254:
        if TargetRole.rank not in [0, 255]:
            flash("Role rank must be between 1 and 254. 0 and 255 are reserved for guests and the owner.", "error")
            return redirect(f"/groups/admin/{groupid}/roles/{roleid}/view")
    
    if TargetRole.rank != 0:
        TargetRole.name = FilteredRoleName
        TargetRole.description = FilteredRoleDescription
    
    if TargetRole.rank not in [0,255]:
        TargetRole.rank = RoleRank
    
    if TargetRole.rank != 255:
        groups.ModifyRolesetPermission(
            TargetRole,
            ViewWall=ViewWallPermission,
            PostToWall=PostWallPermission,
            DeleteFromWall=DeleteWallPermission,
            ViewStatus=ViewGroupShoutPermission,
            PostToStatus=PostGroupShoutPermission,

            ChangeRank=ManageMembersPermission,
            InviteMembers=AcceptJoinsPermission,
            RemoveMembers=RemoveMembersPermission,

            CreateItems=CreateItemsPermission,
            ManageItems=ManageItemsPermission,
            ManageGroupGames=ManageGroupGamesPermission,

            ManageRelationships=ManageRelationshipsPermission,
            ViewAuditLogs=ViewAuditLogsPermission
        )
    
    db.session.commit()
    flash("Role updated", "success")
    return redirect(f"/groups/admin/{groupid}/roles/{roleid}/view")

@groups_page.route('/groups/admin/<int:groupid>/roles/create', methods=["GET"])
@auth.authenticated_required
def groupadmin_role_create(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != groupObject.owner_id:
        return abort(403)
    
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions

    return render_template("groups/admin_subpage/create_role.html", group=groupObject, user=AuthenticatedUser, page="roles", role=UserCurrentRole, permissions=UserPermissions)

@groups_page.route('/groups/admin/<int:groupid>/roles/create', methods=["POST"])
@auth.authenticated_required
@limiter.limit("10/minute")
def groupadmin_role_create_post(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != groupObject.owner_id:
        return abort(403)
    
    RoleName = request.form.get("name", None, str)
    RoleDescription = request.form.get("description", None, str)
    RoleRank = request.form.get("rank", None, int)

    if RoleName is None or RoleDescription is None or RoleRank is None:
        return abort(400)
    if RoleRank < 1 or RoleRank > 254:
        flash("Role rank must be between 1 and 254. 0 and 255 are reserved for guests and the owner.", "error")
        return redirect(f"/groups/admin/{groupid}/roles/create")
    if len(RoleName) > 32:
        flash("Role name must be less than 32 characters", "error")
        return redirect(f"/groups/admin/{groupid}/roles/create")
    if len(RoleDescription) > 256:
        flash("Role description must be less than 256 characters", "error")
        return redirect(f"/groups/admin/{groupid}/roles/create")
    if CountAlnumericCharacters(RoleName) < 3:
        flash("Role name must contain at least 3 alphanumeric characters", "error")
        return redirect(f"/groups/admin/{groupid}/roles/create")
    
    GroupRoleCount = GroupRole.query.filter_by(group_id=groupObject.id).count()
    if GroupRoleCount >= 255:
        flash("You cannot create more than 255 roles. ( Why do you even need that many!? )", "error")
        return redirect(f"/groups/admin/{groupid}/roles/create")

    RobuxBalance, _ = economy.GetUserBalance(AuthenticatedUser)
    if RobuxBalance < 25:
        flash("You do not have enough robux to create a new role.", "error")
        return redirect(f"/groups/admin/{groupid}/roles/create")
    economy.DecrementTargetBalance(AuthenticatedUser, 25, 0)
    transactions.CreateTransaction(
        Reciever = User.query.filter_by(id=1).first(),
        Sender = AuthenticatedUser,
        CurrencyAmount = 25,
        CurrencyType = 0,
        TransactionType = TransactionType.Purchase,
        AssetId = None,
        CustomText = "Created Group Role"
    )

    FilteredRoleName = textfilter.FilterText(RoleName)
    FilteredRoleDescription = textfilter.FilterText(RoleDescription)

    NewRole : GroupRole = groups.CreateGroupRoleset(groupObject, FilteredRoleName, FilteredRoleDescription, RoleRank)
    groups.ModifyRolesetPermission(
        NewRole,
        ViewWall=True,
        PostToWall=True,
        ViewStatus=True
    )
    return redirect(f"/groups/admin/{groupid}/roles/{NewRole.id}/view")

@groups_page.route('/groups/admin/<int:groupid>/payouts', methods=["GET"])
@auth.authenticated_required
def groupadmin_payout_user(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != groupObject.owner_id:
        return abort(403)
    
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions

    return render_template("groups/admin_subpage/payout.html", group=groupObject, user=AuthenticatedUser, page="payouts", role=UserCurrentRole, permissions=UserPermissions)

@groups_page.route('/groups/admin/<int:groupid>/payouts/one-time', methods=["POST"])
@auth.authenticated_required
@limiter.limit("15/minute")
def groupadmin_payout_onetime_user_post( groupid : int ):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser.id != groupObject.owner_id:
        return abort(403)
    
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)
    UserPermissions : GroupRolePermission = UserCurrentRole.permissions

    payoutCurrency : str = request.form.get( key = "payout-currency", default = None, type = str )
    payoutAmount : int = request.form.get( key = "payout-amount", default = None, type = int )
    payoutRecipientUsername : str = request.form.get( key = "payout-recipient", default = None, type = str )

    if payoutCurrency is None or payoutAmount is None or payoutRecipientUsername is None:
        return abort(400)

    if payoutCurrency not in ["robux", "tickets"]:
        return abort(400)

    if payoutAmount < 1:
        flash("Payout amount must be greater than 0", "error")
        return redirect(f"/groups/admin/{groupid}/payouts")
    if len(payoutRecipientUsername) > 128:
        flash("User does not exist or username is not correct", "error")
        return redirect(f"/groups/admin/{groupid}/payouts") 

    payoutRecipient : User = User.query.filter_by(username=payoutRecipientUsername).first()
    if payoutRecipient is None:
        flash("User does not exist or username is not correct", "error")
        return redirect(f"/groups/admin/{groupid}/payouts")
    if payoutRecipient.accountstatus != 1:
        flash("User has a active ban", "error")
        return redirect(f"/groups/admin/{groupid}/payouts")
    if groups.GetUserRankInGroup(payoutRecipient, groupObject) == 0:
        flash("User is not in the group", "error")
        return redirect(f"/groups/admin/{groupid}/payouts")

    robuxBalance, ticketsBalance = economy.GetGroupBalance( groupObject )
    if payoutCurrency == "robux":
        if robuxBalance < payoutAmount:
            flash("Group does not have enough robux to payout", "error")
            return redirect(f"/groups/admin/{groupid}/payouts")
    elif payoutCurrency == "tickets":
        if ticketsBalance < payoutAmount:
            flash("Group does not have enough tickets to payout", "error")
            return redirect(f"/groups/admin/{groupid}/payouts")
    
    try:
        economy.TransferFunds(
            Source = groupObject,
            Target = payoutRecipient,
            Amount = payoutAmount,
            CurrencyType = 0 if payoutCurrency == "robux" else 1,
            ApplyTax = False
        )
    except economy.InsufficientFundsException:
        flash("Group does not have enough funds to payout", "error")
        return redirect(f"/groups/admin/{groupid}/payouts")
    except Exception as e:
        logging.error(f"groupadmin_payout_onetime_user_post : An error occured while trying to payout: {e}")
        flash("An error occured while trying to payout, please contact support", "error")
        return redirect(f"/groups/admin/{groupid}/payouts")
    
    try:
        transactions.CreateTransaction(
            Reciever = payoutRecipient,
            Sender = groupObject,
            CurrencyAmount = payoutAmount,
            CurrencyType = 0 if payoutCurrency == "robux" else 1,
            TransactionType = TransactionType.GroupPayout,
            AssetId = None,
            CustomText = f"Group Payout from {AuthenticatedUser.username}"
        )
    except Exception as e:
        logging.error(f"groupadmin_payout_onetime_user_post : An error occured while trying to create a transaction: {e}")

    flash(f"Successfully paid {payoutRecipient.username} {payoutAmount} {payoutCurrency}", "success")
    return redirect(f"/groups/admin/{groupid}/payouts")

@groups_page.route('/groups/<int:groupid>/<string:slug>')
@groups_page.route('/groups/<int:groupid>/')
@auth.authenticated_required
def groupview(groupid, slug=""):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    
    SlugName = slugify(groupObject.name, lowercase=False)
    if SlugName is None or SlugName == "":
        SlugName = "unnamed"
    
    if slug != SlugName:
        PageNumber = request.args.get( key = "page", default=None, type=int)
        if PageNumber is None:
            return redirect(f"/groups/{groupid}/{SlugName}")
        else:
            return redirect(f"/groups/{groupid}/{SlugName}?page={PageNumber}")
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserCurrentRole : GroupRole = groups.GetUserRolesetInGroup(AuthenticatedUser, groupObject)

    GroupWall = []
    if UserCurrentRole.permissions.view_wall:
        PageNumber : int = request.args.get( key = "page", default=1, type=int)
        if PageNumber < 1:
            PageNumber = 1
        GroupWall = GroupWallPost.query.filter_by(group_id=groupObject.id).order_by(GroupWallPost.created_at.desc()).paginate( page=PageNumber, per_page=10, error_out=False)
    
    GroupRoles : list[GroupRole] = groupObject.roles
    GroupRoles.sort(key=lambda x: x.rank, reverse=False)

    UserPermissions : GroupRolePermission = UserCurrentRole.permissions
    isGroupAdmin = UserPermissions.change_rank or \
        UserPermissions.manage_clan or \
        UserPermissions.manage_relationships or \
        UserPermissions.remove_members or \
        UserPermissions.spend_group_funds
    CurrentJoinRequest : GroupJoinRequest | None = groups.GetJoinRequest(AuthenticatedUser, groupObject)

    return render_template(
        'groups/view.html', 
        groupObj=groupObject, 
        groupservice = groups, 
        UserCurrentRole=UserCurrentRole,
        UserGroups=GetUserGroups(AuthenticatedUser), 
        GroupWall=GroupWall, 
        GroupRoles=GroupRoles, 
        GroupStatus=groups.GetLatestGroupStatus(groupObject),
        PageNumber=PageNumber,
        isThereNextPage=GroupWall.has_next,
        isTherePreviousPage=GroupWall.has_prev,
        slug=SlugName,
        isGroupAdmin=isGroupAdmin,
        CurrentJoinRequest=CurrentJoinRequest)

@groups_page.errorhandler(429)
def RateLimitReached(e):
    if request.headers.get("Accept", default="text/html") == "application/json":
        return jsonify({
            "error": "You are being rate limited. Please try again later.",
            "success": False
        }), 429

    flash("You are being rate limited. Please try again later.", "error")
    return make_response(redirect(request.referrer), 429)

@groups_page.route('/groups/join/<int:groupid>', methods=["POST"])
@limiter.limit("5/minute", on_breach=RateLimitReached)
@auth.authenticated_required
def groupjoin(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    
    if not websiteFeatures.GetWebsiteFeature("GroupJoining"):
        flash("Group joining is temporarily disabled!", "error")
        return redirect(f"/groups/{groupid}/")

    if groupObject.locked:
        flash("This group is locked!", "error")
        return redirect(f"/groups/{groupid}/")

    AuthenticatedUser : User = auth.GetCurrentUser()
    if groups.GetUserRankInGroup(AuthenticatedUser, groupObject) != 0:
        flash("You are already in this group!", "error")
        return redirect(f"/groups/{groupid}/")
    ExisitingJoinRequest : GroupJoinRequest = groups.GetJoinRequest(AuthenticatedUser, groupObject)
    if ExisitingJoinRequest is not None:
        flash("You have already requested to join this group!", "error")
        return redirect(f"/groups/{groupid}/")
    
    UserMembership : MembershipType = membership.GetUserMembership(AuthenticatedUser)
    if groupObject.settings.membership_required:    
        if UserMembership == MembershipType.NonBuildersClub:
            flash("You need to have a Builders Club membership to join this group!", "error")
            return redirect(f"/groups/{groupid}/")

    UserGroupCount = groups.GetUserGroupCount(AuthenticatedUser)
    GroupLimit = {
        MembershipType.NonBuildersClub: 5,
        MembershipType.BuildersClub: 10,
        MembershipType.TurboBuildersClub: 20,
        MembershipType.OutrageousBuildersClub: 100
    }
    if UserGroupCount >= GroupLimit[UserMembership]:
        flash("You have reached the maximum number of groups you can join!", "error")
        return redirect(f"/groups/{groupid}/")

    JoinResponse : GroupMember | GroupJoinRequest | None = groups.AddUserToGroup( TargetUser=AuthenticatedUser, TargetGroup=groupObject, ForceJoin=False)
    if JoinResponse is None:
        flash("An error occured while trying to join this group!", "error")
        return redirect(f"/groups/{groupid}/")
    if isinstance(JoinResponse, GroupJoinRequest):
        flash("Your join request has been sent!", "success")
        return redirect(f"/groups/{groupid}/")
    
    flash("Joined group successfully!", "success")
    return redirect(f"/groups/{groupid}/")

@groups_page.route('/groups/leave/<int:groupid>', methods=["POST"])
@auth.authenticated_required
def groupleave(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    
    if not websiteFeatures.GetWebsiteFeature("GroupLeaving"):
        flash("Group leaving is temporarily disabled!", "error")
        return redirect(f"/groups/{groupid}/")

    AuthenticatedUser : User = auth.GetCurrentUser()
    if groups.GetUserRankInGroup(AuthenticatedUser, groupObject) == 0:
        CurrentJoinRequest : GroupJoinRequest | None = groups.GetJoinRequest(AuthenticatedUser, groupObject)
        if CurrentJoinRequest is not None:
            db.session.delete(CurrentJoinRequest)
            db.session.commit()
            flash("Your join request has been cancelled!", "success")
            return redirect(f"/groups/{groupid}/")
        flash("You are not in this group!", "error")
        return redirect(f"/groups/{groupid}/")
    if groupObject.owner_id == AuthenticatedUser.id:
        flash("Owners cannot leave their group for now", "error")
        return redirect(f"/groups/{groupid}/")
    
    LeaveResponse : bool = groups.RemoveUserFromGroup( TargetUser=AuthenticatedUser, TargetGroup=groupObject)
    if not LeaveResponse:
        flash("An error occured while trying to leave this group!", "error")
        return redirect(f"/groups/{groupid}/")
    
    flash("Left group successfully!", "success")
    return redirect(f"/groups/{groupid}/")

@groups_page.route('/groups/members_json/<int:groupid>', methods=["GET"])
@groups_page.route('/groups/<int:groupid>/members_json', methods=["GET"])
@auth.authenticated_required_api
@limiter.limit("5/second")
def groupmembers_json(groupid):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    
    RolesetId : int = request.args.get( key ="role", default=None, type=int)
    PageNumber : int = request.args.get( key = "page", default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1
    
    try:
        RolesetObject : GroupRole = groups.GetRolesetFromId(RolesetId)
    except groups.GroupExceptions.RolesetDoesNotExist:
        return abort(404)
    
    if RolesetObject.group_id != groupObject.id:
        return abort(404)
    
    Members : list[GroupMember] = GroupMember.query.filter_by(
        group_id=groupObject.id,
        group_role_id=RolesetObject.id
    ).order_by(GroupMember.created_at.desc()).paginate( page=PageNumber, per_page=10, error_out=False)
    
    MembersList = []
    for Member in Members.items:
        MembersList.append({
            "userId": Member.user_id,
            "username": Member.user.username,
        })

    return jsonify({
        "users": MembersList,
        "nextpage": Members.has_next
    })
    
@groups_page.route('/groups/wall_post/<int:groupid>', methods=["POST"])
@auth.authenticated_required
@limiter.limit("5/minute", on_breach=RateLimitReached)
def PostToGroupWall( groupid : int ):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)

    AuthenticatedUser : User = auth.GetCurrentUser()
    
    try:
        groups.AssertUserHasPermission(AuthenticatedUser, groupObject, GroupRolePermission.post_to_wall)
    except groups.GroupExceptions.InsufficientPermssions:
        flash("You do not have permission to post to this group's wall!", "error")
        return redirect(f"/groups/{groupid}/")
    
    if not websiteFeatures.GetWebsiteFeature("GroupWallPosting"):
        flash("Group Wall Posting is temporarily disabled!", "error")
        return redirect(f"/groups/{groupid}/")

    PostContent : str = request.form.get("post_content", default=None, type=str)
    if PostContent is None or PostContent == "":
        flash("Please fill in all fields", "error")
        return redirect(f"/groups/{groupid}/")
    
    if len(PostContent) > 512:
        flash("Your post cannot be longer than 512 characters!", "error")
        return redirect(f"/groups/{groupid}/")
    
    if CountAlnumericCharacters(PostContent) < 3:
        flash("Your post must contain at least 3 alphanumeric characters!", "error")
        return redirect(f"/groups/{groupid}/")
    
    if len(PostContent.split("\n")) > 10:
        flash("Your post cannot contain more than 10 lines!", "error")
        return redirect(f"/groups/{groupid}/")
    
    PostResponse : GroupWallPost | None = groups.PostToGroupWall(AuthenticatedUser, groupObject, PostContent)
    if PostResponse is None:
        flash("An error occured while trying to post to this group's wall!", "error")
        return redirect(f"/groups/{groupid}/")
    
    return redirect(f"/groups/{groupid}/")

@groups_page.route('/groups/<int:groupid>/delete_post/<int:postid>', methods=["POST"])
@auth.authenticated_required
@csrf.exempt
@limiter.limit("10/minute", on_breach=RateLimitReached)
def DeleteGroupWallPost( groupid : int, postid : int ):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    
    PostObject : GroupWallPost = GroupWallPost.query.filter_by(id=postid, group_id=groupObject.id).first()
    if PostObject is None:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()

    try:
        groups.AssertUserHasPermission(AuthenticatedUser, groupObject, GroupRolePermission.delete_from_wall)
    except groups.GroupExceptions.InsufficientPermssions:
        if PostObject.poster_id != AuthenticatedUser.id:
            flash("You do not have permission to delete this post!", "error")
            return redirect(f"/groups/{groupid}/")
    
    groups.DeleteGroupWallPost(PostObject, AuthenticatedUser, ForceDelete=True)
    
    flash("Deleted post successfully!", "success")
    return redirect(f"/groups/{groupid}/")

@groups_page.route("/groups/update_status/<int:groupid>", methods=["POST"])
@auth.authenticated_required
@limiter.limit("5/minute", on_breach=RateLimitReached)
def UpdateGroupStatus( groupid : int ):
    try:
        groupObject : Group = groups.GetGroupFromId(groupid)
    except groups.GroupExceptions.GroupDoesNotExist:
        return abort(404)
    AuthenticatedUser : User = auth.GetCurrentUser()
    try:
        groups.AssertUserHasPermission(AuthenticatedUser, groupObject, GroupRolePermission.post_to_status)
    except groups.GroupExceptions.InsufficientPermssions:
        flash("You do not have permission to update this group's status!", "error")
        return redirect(f"/groups/{groupid}/")
    
    OriginalStatus : str = request.form.get(
        key="status",
        default=None,
        type=str
    )
    if OriginalStatus is None:
        flash("Please fill in all fields!", "error")
        return redirect(f"/groups/{groupid}/")
    
    if len(OriginalStatus) > 255:
        flash("Your status cannot be longer than 255 characters!", "error")
        return redirect(f"/groups/{groupid}/")
    
    if CountAlnumericCharacters(OriginalStatus) < 3 and OriginalStatus != "":
        flash("Your status must contain at least 3 alphanumeric characters!", "error")
        return redirect(f"/groups/{groupid}/")

    FilteredStatus : str = textfilter.FilterText(OriginalStatus)

    groups.PostToGroupStatus(
        AuthenticatedUser,
        groupObject,
        FilteredStatus
    )

    flash("Updated group status successfully!", "success")
    return redirect(f"/groups/{groupid}/")

@groups_page.route("/groups/create", methods=["GET"])
@auth.authenticated_required
def CreateGroupPage():
    if not websiteFeatures.GetWebsiteFeature("GroupCreation"):
        flash("Group creation is temporarily disabled!", "error")
        return render_template("groups/create.html")
    return render_template("groups/create.html")

@groups_page.route("/groups/create", methods=["POST"])
@auth.authenticated_required
def CreateGroupPage_post():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if not websiteFeatures.GetWebsiteFeature("GroupCreation"):
        flash("Group creation is temporarily disabled!", "error")
        return redirect("/groups/create")
    
    GroupName : str = request.form.get("name", default=None, type=str)
    GroupDescription : str = request.form.get("description", default=None, type=str)
    IconImage = request.files.get("icon", default=None)
    if GroupName is None or GroupDescription is None or IconImage is None:
        flash("Please fill in all fields!", "error")
        return redirect("/groups/create")
    GroupName = GroupName.strip()
    
    if len(GroupName) > 30:
        flash("Group name cannot be longer than 30 characters!", "error")
        return redirect("/groups/create")
    if len(GroupDescription) > 1024:
        flash("Group description cannot be longer than 1024 characters!", "error")
        return redirect("/groups/create")
    if CountAlnumericCharacters(GroupName) < 3:
        flash("Group name must contain at least 3 alphanumeric characters!", "error")
        return redirect("/groups/create")
    if CountAlnumericCharacters(GroupDescription) < 10:
        flash("Group description must contain at least 10 alphanumeric characters!", "error")
        return redirect("/groups/create")
    if len(GroupDescription.split("\n")) > 15:
        flash("Group description cannot contain more than 15 lines!", "error")
        return redirect("/groups/create")

    if not GroupName[0].isalnum():
        flash("Group name must start with a alphanumeric character!", "error")
        return redirect("/groups/create")

    for char in GroupName:
        if char not in allowedCharacters:
            flash("Group name contains invalid characters!", "error")
            return redirect("/groups/create")
        if char == " " and GroupName[GroupName.index(char) + 1] == " ":
            flash("Group name cannot contain two or more consecutive spaces!", "error")
            return redirect("/groups/create")
    
    if IconImage.filename == "":
        flash("Please upload an icon!", "error")
        return redirect("/groups/create")
    
    if IconImage.content_length > 1024 * 1024 * 2:
        flash("Icon cannot be larger than 2MB!", "error")
        return redirect("/groups/create")
    if IconImage.content_type not in ["image/png", "image/jpeg"]:
        flash("Icon must be a PNG or JPEG image", "error")
        return redirect("/groups/create")
    
    NewIcon = ValidateClothingImage( IconImage, verifyResolution=False, validateFileSize=False, returnImage=True )
    if NewIcon is False or NewIcon is None:
        flash("Icon is invalid", "error")
        return redirect("/groups/create")
    if NewIcon.width != NewIcon.height:
        flash("Icon must be a square", "error")
        return redirect("/groups/create")
    if NewIcon.width > 1024 or NewIcon.height > 1024:
        flash("Icon must be less than 1024x1024", "error")
        return redirect("/groups/create")
    if NewIcon.width < 128 or NewIcon.height < 128:
        flash("Icon must be at least 128x128", "error")
        return redirect("/groups/create")
    
    UserMembership : MembershipType = membership.GetUserMembership(AuthenticatedUser)
    UserGroupCount = groups.GetUserGroupCount(AuthenticatedUser)
    GroupLimit = {
        MembershipType.NonBuildersClub: 5,
        MembershipType.BuildersClub: 10,
        MembershipType.TurboBuildersClub: 20,
        MembershipType.OutrageousBuildersClub: 100
    }
    if UserGroupCount >= GroupLimit[UserMembership]:
        flash("You have reached the maximum number of groups you can join!", "error")
        return redirect("/groups/create")
    try:
        textfilter.FilterText(GroupName, ThrowException=True)
    except textfilter.TextNotAllowedException:
        flash("Group name is not safe for SYNTAX!", "error")
        return redirect("/groups/create")
    ExistingGroup : Group = groups.SearchGroupByName(GroupName)
    if ExistingGroup is not None:
        flash("Group name is already taken!", "error")
        return redirect("/groups/create")
    FilteredGroupDescription : str = textfilter.FilterText(GroupDescription)

    RobuxBalance, _ = economy.GetUserBalance(AuthenticatedUser)
    if RobuxBalance < 100:
        flash("You do not have enough robux to create a group.", "error")
        return redirect("/groups/create")
    economy.DecrementTargetBalance(AuthenticatedUser, 100, 0)
    transactions.CreateTransaction(
        Reciever = User.query.filter_by(id=1).first(),
        Sender = AuthenticatedUser,
        CurrencyAmount = 100,
        CurrencyType = 0,
        TransactionType = TransactionType.Purchase,
        AssetId = None,
        CustomText = "Created Group"
    )
    IconImage = BytesIO()
    NewIcon.save(IconImage, format="PNG")

    IconImage.seek(0)
    IconImageHash = hashlib.sha512(IconImage.read()).hexdigest()
    if not s3helper.DoesKeyExist(IconImageHash):
        IconImage.seek(0)
        s3helper.UploadBytesToS3(IconImage.read(), IconImageHash, contentType="image/png")

    NewGroup : Group = groups.CreateGroup(GroupName, FilteredGroupDescription, AuthenticatedUser, IconImageHash)
    return redirect(f"/groups/{NewGroup.id}/")
from sqlalchemy import func

@groups_page.route("/groups/search", methods=["GET"])
@auth.authenticated_required
def SearchGroupsPage():
    PageNumber : int = request.args.get( key = "page", default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1
    Query : str = request.args.get( key = "query", default="", type=str)
    if len(Query) > 32:
        Query = Query[:32]
    if len(Query) < 3:
        Query = ""
    
    GroupQuery = Group.query
    if Query != "":
        GroupQuery = GroupQuery.filter(Group.name.ilike(f"%{Query}%"))
    GroupQuery = GroupQuery.outerjoin(GroupRole, GroupRole.group_id == Group.id ).group_by(Group.id).order_by(func.coalesce(func.sum(GroupRole.member_count), 0).desc()).order_by(Group.created_at.desc())
    GroupQuery = GroupQuery.paginate( page=PageNumber, per_page=12, error_out=False)

    return render_template("groups/search.html", query=Query, groups=GroupQuery, groupservice=groups)

@groups_page.route("/groups/search", methods=["POST"])
@auth.authenticated_required
@csrf.exempt
def SearchGroupsPage_post():
    Query : str = request.form.get("query", default="", type=str)
    if len(Query) > 32:
        Query = Query[:32]
    if len(Query) < 3:
        Query = ""
    
    if Query == "":
        return redirect("/groups/search")
    return redirect(f"/groups/search?query={Query}")

@groups_page.route("/groups", methods=["GET"])
@auth.authenticated_required
def GroupsPage():
    AuthenticatedUser : User = auth.GetCurrentUser()
    FirstGroup : GroupMember = GroupMember.query.filter_by(user_id=AuthenticatedUser.id).order_by(GroupMember.created_at.asc()).first()
    if FirstGroup is None:
        return redirect("/groups/search")
    return redirect(f"/groups/{FirstGroup.group_id}/")