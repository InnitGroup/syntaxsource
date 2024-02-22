from app.models.friend_relationship import FriendRelationship
from app.models.friend_request import FriendRequest
from app.models.user import User
from app.extensions import db
from app.util import auth

"""
DEPRECATED
Everything should be moved to app/services/user_relationships/friends.py
"""

def GetFriends( userId : int ) -> list[User]:
    """
        Returns a list of friends for the user
        
        :param userId: The user's id

        :return: A list of friends for the user
    """
    friends : list[FriendRelationship] = FriendRelationship.query.filter((FriendRelationship.user_id == userId) | (FriendRelationship.friend_id == userId)).all()
    if friends is None:
        return []
    
    friendList = []
    for friend in friends:
        OtherUserId = friend.user_id if friend.user_id != userId else friend.friend_id
        OtherUser = User.query.filter_by(id=OtherUserId).first()
        if OtherUser is None:
            continue
        if OtherUser in friendList:
            # This should never happen, but just in case
            db.session.delete(friend)
            db.session.commit()
            continue

        friendList.append(OtherUser)
    
    return friendList

def GetFriendRelationship(userId, otherUserId):
    friends = FriendRelationship.query.filter((FriendRelationship.user_id == userId) | (FriendRelationship.friend_id == userId)).all()
    if friends is None:
        return None
    
    for friend in friends:
        OtherUserId = friend.user_id if friend.user_id != userId else friend.friend_id
        if OtherUserId == otherUserId:
            return friend
    
    return None

def IsFriends(userId, otherUserId):
    friends = FriendRelationship.query.filter((FriendRelationship.user_id == userId) | (FriendRelationship.friend_id == userId)).all()
    if friends is None:
        return False
    
    for friend in friends:
        OtherUserId = friend.user_id if friend.user_id != userId else friend.friend_id
        if OtherUserId == otherUserId:
            return True
    
    return False

def GetFriendRequests(userId):
    friendRequests = FriendRequest.query.filter_by(requestee_id=userId).all()
    if friendRequests is None:
        return []
    
    friendRequestList = []
    for friendRequest in friendRequests:
        OtherUser = User.query.filter_by(id=friendRequest.requester_id).first()
        if OtherUser is None:
            continue
        friendRequestList.append(OtherUser)
    
    return friendRequestList


def GetFriendCount(userId):
    return FriendRelationship.query.filter((FriendRelationship.user_id == userId) | (FriendRelationship.friend_id == userId)).count()