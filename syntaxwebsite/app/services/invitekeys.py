import random
import string
import uuid
from datetime import datetime
from app.extensions import db

from app.models.invite_key import InviteKey
from app.models.user import User

class InviteExceptions:
    class InvalidInviteKey(Exception):
        pass
    class UserDoesNotExist(Exception):
        pass
    class InviteKeyAlreadyUsed(Exception):
        pass

def _GenerateInviteKey() -> str:
    """
        Returns a randomly generated invite key
    """
    RandomUUID = str(uuid.uuid4())
    invite_key = "syntax" + RandomUUID[6:]
    InviteKeyObj : InviteKey = InviteKey.query.filter_by(key=invite_key).first()
    if InviteKeyObj is not None:
        return _GenerateInviteKey()
    return invite_key

def GetUserFromId( UserObj : User | int ) -> User | None:
    """
    Returns a User object from a User ID.
    """
    if isinstance(UserObj, User):
        return UserObj
    else:
        TargetUser : User | None = User.query.filter_by(id=UserObj).first()
        if TargetUser is None:
            raise InviteExceptions.UserDoesNotExist("User does not exist.")
        return TargetUser

def GetInviteKey( key : str ) -> InviteKey:
    InviteKeyObj : InviteKey = InviteKey.query.filter_by(key=key).first()
    if InviteKeyObj is None:
        raise InviteExceptions.InvalidInviteKey()
    return InviteKeyObj

def UseInviteKey( key : str, user : User ) -> InviteKey:
    InviteKeyObj : InviteKey = GetInviteKey(key)
    if InviteKeyObj.used_by is not None:
        raise InviteExceptions.InviteKeyAlreadyUsed()
    InviteKeyObj.used_by = user.id
    InviteKeyObj.used_on = datetime.utcnow()
    db.session.add(InviteKeyObj)
    db.session.commit()
    return InviteKeyObj

def CreateInviteKey( creator : User | int | None ) -> InviteKey:
    """
        Create a new invite key.
    """
    if creator is not None:
        creator = GetUserFromId(creator)
    invite_key = _GenerateInviteKey()
    InviteKeyObj = InviteKey(
        key = invite_key,
        created_by = creator.id if creator is not None else None
    )
    db.session.add(InviteKeyObj)
    db.session.commit()
    return InviteKeyObj