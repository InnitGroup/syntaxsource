from flask import Blueprint, render_template, request, redirect, url_for, flash, jsonify
from app.util import auth, membership
from app.enums.MembershipType import MembershipType
from app.extensions import db, redis_controller, get_remote_address
from app.models.user import User
from app.models.user_email import UserEmail
from app.services import economy
from datetime import datetime, timedelta
from config import Config
config = Config()

RBXAPIRoute = Blueprint('RBXAPIRoute', __name__, template_folder='pages')

@RBXAPIRoute.route("/users/<int:userid>", methods=["GET"])
def UserInfoAPI( userid : int ):
    UserObj : User = User.query.filter_by( id = userid ).first()
    if UserObj is None:
        return jsonify( { "success" : False, "message" : "User not found" } ), 404
    return jsonify({
        "Id" : UserObj.id,
        "Username" : UserObj.username
    })

@RBXAPIRoute.route("/users/account-info", methods=["GET"])
@auth.authenticated_required_api
def GetUserAccountInfo():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    UserMembershipType : int = membership.GetUserMembership( AuthenticatedUser ).value
    RobuxBalance, _ = economy.GetUserBalance( AuthenticatedUser )

    UserEmailObj : UserEmail = UserEmail.query.filter_by(user_id = AuthenticatedUser.id ).first()
    if UserEmailObj is not None:
        emailParts = UserEmailObj.email.split("@")
        FirstPart = emailParts[0][0] + "*" * (len(emailParts[0])-1)
        SecondPart = emailParts[1]
        HiddenEmail = FirstPart + "@" + SecondPart 
    else:
        HiddenEmail = None

    return jsonify({
        "UserId": AuthenticatedUser.id,
        "Username": AuthenticatedUser.username,
        "DisplayName": AuthenticatedUser.username,
        "HasPasswordSet": True,
        "Email": HiddenEmail,
        "MembershipType": UserMembershipType,
        "RobuxBalance": RobuxBalance,
        "AgeBracket": 0,
        "Roles": [],
        "EmailNotificationEnabled": False,
        "PasswordNotifcationEnabled": False
    })

@RBXAPIRoute.route("/my/settings/json", methods=["GET"])
@auth.authenticated_required_api
def GetMySettingsJSON():
    AuthenticatedUser : User = auth.GetCurrentUser()
    UserEmailObj : UserEmail = UserEmail.query.filter_by(user_id = AuthenticatedUser.id ).first()
    if UserEmailObj is not None:
        emailParts = UserEmailObj.email.split("@")
        FirstPart = emailParts[0][0] + "*" * (len(emailParts[0])-1)
        SecondPart = emailParts[1]
        HiddenEmail = FirstPart + "@" + SecondPart 
    else:
        HiddenEmail = None

    UserMembershipType : MembershipType = membership.GetUserMembership( AuthenticatedUser )

    return jsonify({
        "ChangeUsernameEnabled": True,
        "IsAdmin": False,
        "UserId": AuthenticatedUser.id,
        "Name": AuthenticatedUser.username,
        "DisplayName": AuthenticatedUser.username,
        "IsEmailOnFile": UserEmailObj is not None,
        "IsEmailVerified": UserEmailObj is not None and UserEmailObj.verified,
        "IsPhoneFeatureEnabled": False,
        "RobuxRemainingForUsernameChange": 0,
        "PreviousUserNames": "",
        "UseSuperSafePrivacyMode": False,
        "IsSuperSafeModeEnabledForPrivacySetting": False,
        "UseSuperSafeChat": False,
        "IsAppChatSettingEnabled": True,
        "IsGameChatSettingEnabled": True,
        "IsAccountPrivacySettingsV2Enabled": True,
        "IsSetPasswordNotificationEnabled": False,
        "ChangePasswordRequiresTwoStepVerification": False,
        "ChangeEmailRequiresTwoStepVerification": False,
        "UserEmail": HiddenEmail,
        "UserEmailMasked": True,
        "UserEmailVerified": UserEmailObj is not None and UserEmailObj.verified,
        "CanHideInventory": False,
        "CanTrade": UserMembershipType != MembershipType.NonBuildersClub,
        "MissingParentEmail": False,
        "IsUpdateEmailSectionShown": True,
        "IsUnder13UpdateEmailMessageSectionShown": False,
        "IsUserConnectedToFacebook": False,
        "IsTwoStepToggleEnabled": False,
        "AgeBracket": 0,
        "UserAbove13": True,
        "ClientIpAddress": get_remote_address(),
        "AccountAgeInDays": (datetime.utcnow() - AuthenticatedUser.created).days,
        "IsOBC": UserMembershipType == MembershipType.OutrageousBuildersClub,
        "IsTBC": UserMembershipType == MembershipType.TurboBuildersClub,
        "IsAnyBC": UserMembershipType != MembershipType.NonBuildersClub,
        "IsPremium": False,
        "IsBcRenewalMembership": False,
        "BcExpireDate": "/Date(-0)/",
        "BcRenewalPeriod": None,
        "BcLevel": None,
        "HasCurrencyOperationError": False,
        "CurrencyOperationErrorMessage": None,
        "BlockedUsersModel": {
            "BlockedUserIds": [],
            "BlockedUsers": [],
            "MaxBlockedUsers": 50,
            "Total": 1,
            "Page": 1
        },
        "Tab": None,
        "ChangePassword": False,
        "IsAccountPinEnabled": True,
        "IsAccountRestrictionsFeatureEnabled": True,
        "IsAccountRestrictionsSettingEnabled": False,
        "IsAccountSettingsSocialNetworksV2Enabled": False,
        "IsUiBootstrapModalV2Enabled": True,
        "IsI18nBirthdayPickerInAccountSettingsEnabled": True,
        "InApp": False,
        "MyAccountSecurityModel": {
            "IsEmailSet": UserEmailObj is not None,
            "IsEmailVerified": UserEmailObj is not None and UserEmailObj.verified,
            "IsTwoStepEnabled": False,
            "ShowSignOutFromAllSessions": True,
            "TwoStepVerificationViewModel": {
            "UserId": AuthenticatedUser.id,
            "IsEnabled": False,
            "CodeLength": 6,
            "ValidCodeCharacters": None
            }
        },
        "ApiProxyDomain": config.BaseURL,
        "AccountSettingsApiDomain": config.BaseURL,
        "AuthDomain": config.BaseURL,
        "IsDisconnectFbSocialSignOnEnabled": True,
        "IsDisconnectXboxEnabled": True,
        "NotificationSettingsDomain": config.BaseURL,
        "AllowedNotificationSourceTypes": [
            "Test",
            "FriendRequestReceived",
            "FriendRequestAccepted",
            "PartyInviteReceived",
            "PartyMemberJoined",
            "ChatNewMessage",
            "PrivateMessageReceived",
            "UserAddedToPrivateServerWhiteList",
            "ConversationUniverseChanged",
            "TeamCreateInvite",
            "GameUpdate",
            "DeveloperMetricsAvailable"
        ],
        "AllowedReceiverDestinationTypes": [
            "DesktopPush",
            "NotificationStream"
        ],
        "BlacklistedNotificationSourceTypesForMobilePush": [],
        "MinimumChromeVersionForPushNotifications": 50,
        "PushNotificationsEnabledOnFirefox": True,
        "LocaleApiDomain": config.BaseURL,
        "HasValidPasswordSet": True,
        "IsUpdateEmailApiEndpointEnabled": True,
        "FastTrackMember": None,
        "IsFastTrackAccessible": False,
        "HasFreeNameChange": False,
        "IsAgeDownEnabled": False,
        "IsSendVerifyEmailApiEndpointEnabled": True,
        "IsPromotionChannelsEndpointEnabled": True,
        "ReceiveNewsletter": False,
        "SocialNetworksVisibilityPrivacy": 6,
        "SocialNetworksVisibilityPrivacyValue": "AllUsers",
        "Facebook": None,
        "Twitter": None,
        "YouTube": None,
        "Twitch": None
    })