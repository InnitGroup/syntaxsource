from app.models.user_membership import UserMembership
from app.enums.MembershipType import MembershipType
from app.extensions import db
from app.models.user import User
from datetime import datetime, timedelta

class UserHasHigherMembershipException(Exception):
    """
        Raised when a user has a higher membership than the one they are trying to be given.
    """
    pass
class UserDoesNotExistException(Exception):
    """
        Raised when a user does not exist.
    """
    pass
class UserDoesNotHaveMembershipException(Exception):
    """
        Raised when a user does not have a membership.
    """
    pass

def GetUserFromId( TargetUser : User | int ) -> User | None:
    """
        Gets a user from their ID.

        :param TargetUser: The user to get.

        :returns: User | None (The user, None if the user does not exist)
    """
    if type(TargetUser) is int:
        TargetUser = User.query.filter_by(id=TargetUser).first()
    return TargetUser

def GetUserMembership( TargetUser : User | int, changeToString : bool = False) -> MembershipType | None | str:
    """
        Gets the membership of a user.

        :param TargetUser: The user to get the membership of.
        :param changeToString: Whether to change the membership enum to a string or not.

        :returns: MembershipType | None | str (The membership of the user, None if the user does not exist, "None" if the user has no membership, or a string if changeToString is True)
    """
    TargetUser = GetUserFromId(TargetUser)
    if TargetUser is None:
        return None
    MembershipObj : UserMembership = UserMembership.query.filter_by(user_id=TargetUser.id).first()
    if MembershipObj is None:
        MembershipObj : UserMembership = UserMembership(
            TargetUser.id,
            MembershipType.NonBuildersClub,
            None,
            None
        )
        db.session.add(MembershipObj)
        db.session.commit()
    if MembershipObj.expiration is not None and MembershipObj.expiration < datetime.utcnow():
        MembershipObj.membership_type = MembershipType.NonBuildersClub
        MembershipObj.expiration = None
        MembershipObj.next_stipend = None
        MembershipObj.created = None
        db.session.commit()
    if changeToString:
        if MembershipObj.membership_type == MembershipType.NonBuildersClub:
            return "None"
        return MembershipObj.membership_type.name
    return MembershipObj.membership_type


def GiveUserMembership( TargetUser : User | int, Membership : MembershipType, expiration : timedelta = timedelta(days=31),ForceMembership : bool = False, throwException : bool = True, incrementExpirationIfSame : bool = True) -> None:
    """
        Gives a user a membership.

        :param TargetUser: The user to give the membership to.
        :param Membership: The membership to give the user.
        :param expiration: The expiration of the membership.
        :param ForceMembership: Whether to force the membership or not.
        :param throwException: Whether to throw an exception or not.
        :param incrementExpirationIfSame: Whether to increment the expiration if the user already has the membership.

        :returns: None
    """
    
    TargetUser = GetUserFromId(TargetUser)
    if TargetUser is None:
        return None
    CurrentMembership : MembershipType = GetUserMembership(TargetUser)
    if CurrentMembership is None:
        if throwException:
            raise UserDoesNotExistException("User does not exist.")
        return
    if CurrentMembership == Membership:
        if incrementExpirationIfSame:
            MembershipObj : UserMembership = UserMembership.query.filter_by(user_id=TargetUser.id).first()
            if MembershipObj is None:
                raise Exception("Membership object does not exist, this should never happen.")
            if MembershipObj.expiration is None:
                return
            MembershipObj.expiration = MembershipObj.expiration + expiration
            db.session.commit()
        return
    if CurrentMembership.value > Membership.value and not ForceMembership:
        if throwException:
            raise UserHasHigherMembershipException("User has a higher membership than the one they are trying to be given.")
        return
    MembershipObj : UserMembership = UserMembership.query.filter_by(user_id=TargetUser.id).first()
    if MembershipObj is None:
        raise Exception("Membership object does not exist, this should never happen.")
    MembershipObj.membership_type = Membership
    MembershipObj.created = datetime.utcnow()
    MembershipObj.expiration = datetime.utcnow() + expiration
    MembershipObj.next_stipend = datetime.utcnow()
    db.session.commit()

    return

def RemoveUserMembership( TargetUser : User | int ) -> None:
    """
        Removes a user's membership.

        :param TargetUser: The user to remove the membership of.

        :returns: None
    """

    TargetUser = GetUserFromId(TargetUser)
    if TargetUser is None:
        return None
    CurrentMembership : MembershipType = GetUserMembership(TargetUser)
    if CurrentMembership is MembershipType.NonBuildersClub:
        return
    MembershipObj : UserMembership = UserMembership.query.filter_by(user_id=TargetUser.id).first()
    if MembershipObj is None:
        raise Exception("Membership object does not exist, this should never happen.")
    MembershipObj.membership_type = MembershipType.NonBuildersClub
    MembershipObj.created = None
    MembershipObj.expiration = None
    MembershipObj.next_stipend = None
    db.session.commit()

    return
def IncrementExpirationLength( TargetUser : User | int, Length : timedelta = timedelta(days=31) ) -> None:
    """
        Increments the expiration length of a user's membership.

        :param TargetUser: The user to increment the expiration length of.
        :param Length: The length to increment the expiration by.

        :returns: None
    """
    TargetUser : User = GetUserFromId(TargetUser)
    if TargetUser is None:
        return None
    CurrentMembership : MembershipType = GetUserMembership(TargetUser)
    if CurrentMembership is None:
        raise UserDoesNotExistException("User does not exist.")
    if CurrentMembership == MembershipType.NonBuildersClub:
        raise UserDoesNotHaveMembershipException("User does not have a membership.")
    MembershipObj : UserMembership = UserMembership.query.filter_by(user_id=TargetUser.id).first()
    if MembershipObj is None:
        raise Exception("Membership object does not exist, this should never happen.")
    if MembershipObj.expiration is None:
        raise Exception("Membership object does not have an expiration, this should never happen.")
    MembershipObj.expiration = MembershipObj.expiration + Length
    db.session.commit()

    return