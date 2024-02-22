from app.models.friend_relationship import FriendRelationship
from app.models.friend_request import FriendRequest
from app.models.user import User

from app.extensions import db, redis_controller

import redis_lock

class FriendExceptions():
    class AlreadyFriends(Exception):
        pass
    class CannotFriendSelf(Exception):
        pass
    class RedisLockAcquireError(Exception):
        pass
    class UserRateLimited(Exception):
        pass
    class UserNotFriends(Exception):
        pass
    class FriendIsDisabled(Exception):
        pass
    class RecipientHasTooManyFriends(Exception):
        pass
    class SenderHasTooManyFriends(Exception):
        pass

def get_friend_count(
    user : User
) -> int:
    """
        :param user : User : The user

        :return int : The amount of friends the user has
    """

    assert isinstance(user, User), f"Expected user to be of type User, got {user.__class__}"

    return FriendRelationship.query.filter(
        (FriendRelationship.user_id == user.id) | (FriendRelationship.friend_id == user.id)
    ).count()

def get_friend_relationship(
    user1 : User,
    user2 : User
) -> FriendRelationship | None:
    """
        :param user1 : User : The first user
        :param user2 : User : The second

        :return FriendRelationship | None : The friend relationship or None
    """

    assert isinstance(user1, User), f"Expected user1 to be of type User, got {user1.__class__.__name__}"
    assert isinstance(user2, User), f"Expected user2 to be of type User, got {user2.__class__}"

    return FriendRelationship.query.filter(
        (FriendRelationship.user_id == user1.id and FriendRelationship.friend_id == user2.id) |
        (FriendRelationship.user_id == user2.id and FriendRelationship.friend_id == user1.id)
    ).first()

def create_friend_relationship(
    user1 : User,
    user2 : User,
) -> FriendRelationship:
    """
        :param user1 : User : The first user
        :param user2 : User : The second

        :return FriendRelationship : The friend relationship
    """

    assert isinstance(user1, User), f"Expected user1 to be of type User, got {user1.__class__.__name__}"
    assert isinstance(user2, User), f"Expected user2 to be of type User, got {user2.__class__}"

    FirstUser = user1 if user1.id < user2.id else user2
    SecondUser = user2 if user1.id < user2.id else user1

    try:
        with redis_lock.Lock( redis_client = redis_controller, name = f"services:friends:create_friend_relationship:{FirstUser.id}:{SecondUser.id}", expire = 10 ):
            if get_friend_relationship(user1, user2) is not None:
                raise FriendExceptions.AlreadyFriends

            friendRelationship = FriendRelationship(
                user_id = user1.id,
                friend_id = user2.id
            )

            db.session.add(friendRelationship)
            db.session.commit()

            return friendRelationship
    except AssertionError:
        raise FriendExceptions.RedisLockAcquireError

def remove_friend_relationship(
    user1 : User,
    user2 : User
) -> None:
    """
        :param user1 : User : The first user
        :param user2 : User : The second

        :return None
    """

    assert isinstance(user1, User), f"Expected user1 to be of type User, got {user1.__class__}"
    assert isinstance(user2, User), f"Expected user2 to be of type User, got {user2.__class__}"

    FirstUser = user1 if user1.id < user2.id else user2
    SecondUser = user2 if user1.id < user2.id else user1

    try:
        with redis_lock.Lock( redis_client = redis_controller, name = f"services:friends:remove_friend_relationship:{FirstUser.id}:{SecondUser.id}", expire = 10 ):
            friendRelationship = get_friend_relationship(user1, user2)
            if friendRelationship is None:
                raise FriendExceptions.UserNotFriends

            db.session.delete(friendRelationship)
            db.session.commit()

            return None
    except AssertionError:
        raise FriendExceptions.RedisLockAcquireError

def send_friend_request(
    sender_user : User,
    recipient_user : User
) -> FriendRequest | FriendRelationship:
    """
        :param sender_user : User : The user sending the friend request
        :param recipient_user : User : The user receiving the friend request

        :return FriendRequest | FriendRelationship : The friend request or friend relationship if there is already an existing friend request from the recipient user
    """

    assert isinstance(sender_user, User), f"Expected user1 to be of type User, got {sender_user.__class__}"
    assert isinstance(recipient_user, User), f"Expected user2 to be of type User, got {recipient_user.__class__}"

    FirstUser = sender_user if sender_user.id < recipient_user.id else recipient_user
    SecondUser = recipient_user if sender_user.id < recipient_user.id else sender_user

    try:
        with redis_lock.Lock( redis_client = redis_controller, name = f"services:friends:send_friend_request:{FirstUser.id}:{SecondUser.id}", expire = 10 ):
            if get_friend_relationship(sender_user, recipient_user) is not None:
                raise FriendExceptions.AlreadyFriends
            
            if sender_user.id == recipient_user.id:
                raise FriendExceptions.CannotFriendSelf
            
            if get_friend_count(recipient_user) >= 200:
                raise FriendExceptions.RecipientHasTooManyFriends
            if get_friend_count(sender_user) >= 200:
                raise FriendExceptions.SenderHasTooManyFriends
            
            if redis_controller.get(f"rate_limit:friends:send_friend_request:{sender_user.id}") is not None:
                raise FriendExceptions.UserRateLimited
            redis_controller.set(f"rate_limit:friends:send_friend_request:{sender_user.id}", "1", ex = 3)
            
            otherFriendRequest = FriendRequest.query.filter_by(requester_id = recipient_user.id, requestee_id = sender_user.id).first()
            if otherFriendRequest is not None:
                db.session.delete(otherFriendRequest)
                db.session.commit()

                return create_friend_relationship( user1 = sender_user, user2 = recipient_user)
            
            friendRequest = FriendRequest.query.filter_by(requester_id = sender_user.id, requestee_id = recipient_user.id).first()
            if friendRequest is not None:
                return friendRequest
            
            friendRequest = FriendRequest(
                requester_id = sender_user.id,
                requestee_id = recipient_user.id
            )
            db.session.add(friendRequest)
            db.session.commit()

            return friendRequest
    except AssertionError:
        raise FriendExceptions.RedisLockAcquireError
    
def decline_friend_request(
    sender_user : User,
    recipient_user : User
) -> None:
    """
        :param sender_user : User : The user sending the friend request
        :param recipient_user : User : The user receiving the friend request

        :return None
    """

    assert isinstance(sender_user, User), f"Expected user1 to be of type User, got {sender_user.__class__}"
    assert isinstance(recipient_user, User), f"Expected user2 to be of type User, got {recipient_user.__class__}"

    friendRequest = FriendRequest.query.filter_by(requester_id = sender_user.id, requestee_id = recipient_user.id).first()
    if friendRequest is not None:
        db.session.delete(friendRequest)
        db.session.commit()
    
    return None