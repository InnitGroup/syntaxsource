from app.models.follow_relationship import FollowRelationship
from app.models.user import User
from app.extensions import db, redis_controller
from app.util.websiteFeatures import GetWebsiteFeature

import redis_lock

class FollowingExceptions():
    class AlreadyFollowing(Exception):
        pass
    class CannotFollowSelf(Exception):
        pass
    class RedisLockAcquireError(Exception):
        pass
    class UserRateLimited(Exception):
        pass
    class UserNotFollowing(Exception):
        pass
    class FollowingIsDisabled(Exception):
        pass

def follow_user(
    follower_user : User,
    followed_user : User,

    bypass_rate_limit : bool = False
) -> None:
    """
        :param follower_user : User : The user that is following
        :param followed_user : User : The user that is being followed

        :param bypass_rate_limit : bool : Bypass the rate limit check

        :return None

        :raises FollowingExceptions.AlreadyFollowing : The user is already following the other user
        :raises FollowingExceptions.CannotFollowSelf : The user cannot follow themselves
        :raises FollowingExceptions.UserNotFound : The user is not found
        :raises FollowingExceptions.RedisLockAcquireError : The Redis lock cannot be acquired
        :raises FollowingExceptions.UserRateLimited : The user is rate limited 
        :raises FollowingExceptions.FollowingIsDisabled : Following is disabled
    """

    assert isinstance(follower_user, User), f"Expected follower_user to be of type User, got {follower_user.__class__.__name__}"
    assert isinstance(followed_user, User), f"Expected followed_user to be of type User, got {followed_user.__class__}"

    if follower_user.id == followed_user.id:
        raise FollowingExceptions.CannotFollowSelf
    
    if GetWebsiteFeature("FollowingUsers") is False:
        raise FollowingExceptions.FollowingIsDisabled

    try:
        with redis_lock.Lock( redis_client = redis_controller, name = f"services:followings:follow_user:{follower_user.id}", expire = 10 ):
            if not bypass_rate_limit:
                if redis_controller.get(f"rate_limit:followings:follow_user_action:{follower_user.id}") is not None:
                    raise FollowingExceptions.UserRateLimited
                redis_controller.set(f"rate_limit:followings:follow_user_action:{follower_user.id}", "1", ex = 5)

            if FollowRelationship.query.filter_by(followerUserId = follower_user.id, followeeUserId = followed_user.id).first() is not None:
                raise FollowingExceptions.AlreadyFollowing
            
            follow_relationship = FollowRelationship(
                followerUserId = follower_user.id,
                followeeUserId = followed_user.id
            )
            db.session.add(follow_relationship)
            db.session.commit()
            
            return None
    except AssertionError:
        raise FollowingExceptions.RedisLockAcquireError

def unfollow_user(
    current_follower : User,
    followed_user : User,

    bypass_rate_limit : bool = False
) -> None:
    """
        :param current_follower : User : The user that is unfollowing
        :param followed_user : User : The user that is being unfollowed

        :param bypass_rate_limit : bool : Bypass the rate limit check

        :return None

        :raises FollowingExceptions.UserNotFollowing : The user is not following the other user
        :raises FollowingExceptions.RedisLockAcquireError : The Redis lock cannot be acquired
        :raises FollowingExceptions.UserRateLimited : The user is rate limited
    """

    assert isinstance(current_follower, User), f"Expected current_follower to be of type User, got {current_follower.__class__.__name__}"
    assert isinstance(followed_user, User), f"Expected followed_user to be of type User, got {followed_user.__class__}"

    try:
        with redis_lock.Lock( redis_client = redis_controller, name = f"services:followings:unfollow_user:{current_follower.id}", expire = 10 ):
            if not bypass_rate_limit:
                if redis_controller.get(f"rate_limit:followings:unfollow_user_action:{current_follower.id}") is not None:
                    raise FollowingExceptions.UserRateLimited
                redis_controller.set(f"rate_limit:followings:unfollow_user_action:{current_follower.id}", "1", ex = 1)

            follow_relationship = FollowRelationship.query.filter_by(followerUserId = current_follower.id, followeeUserId = followed_user.id).first()
            if follow_relationship is None:
                raise FollowingExceptions.UserNotFollowing

            db.session.delete(follow_relationship)
            db.session.commit()

            return None
    except AssertionError:
        raise FollowingExceptions.RedisLockAcquireError
    
def is_following(
    follower_user : User,
    followed_user : User
) -> bool:
    """
        :param follower_user : User : The user that is following
        :param followed_user : User : The user that is being followed

        :return bool : Whether the user is following the other user
    """

    assert isinstance(follower_user, User), f"Expected follower_user to be of type User, got {follower_user.__class__.__name__}"
    assert isinstance(followed_user, User), f"Expected followed_user to be of type User, got {followed_user.__class__}"

    return FollowRelationship.query.filter_by(followerUserId = follower_user.id, followeeUserId = followed_user.id).first() is not None

def get_followers(
    requested_user : User,

    return_as_query : bool = False
) -> list[User]:
    """
        :param requested_user : User : The user that is being requested
        :param return_as_query : bool : Whether to return the result as a query or a list

        :return list[User] : The list of users that are following the requested user
    """

    assert isinstance(requested_user, User), f"Expected requested_user to be of type User, got {requested_user.__class__.__name__}"

    FollowersQuery = User.query.join(FollowRelationship, FollowRelationship.followerUserId == User.id).filter(FollowRelationship.followeeUserId == requested_user.id)
    if return_as_query:
        return FollowersQuery
    
    return FollowersQuery.all()

def get_follower_count(
    requested_user : User,

    skip_cache : bool = False
) -> int:
    """
        :param requested_user : User : The user that is being requested
        :param skip_cache : bool : Whether to skip the cache

        :return int : The number of users that are following the requested user
    """

    assert isinstance(requested_user, User), f"Expected requested_user to be of type User, got {requested_user.__class__}"

    if not skip_cache:
        CachedFollowerCount = redis_controller.get(f"services:followings:follower_count:{requested_user.id}")
        if CachedFollowerCount is not None:
            return int(CachedFollowerCount)
    
    FollowerCount : int = get_followers(requested_user, return_as_query = True).count()
    redis_controller.set(f"services:followings:follower_count:{requested_user.id}", FollowerCount, ex = 10)

    return FollowerCount

def get_following(
    requested_user : User,

    return_as_query : bool = False
) -> list[User]:
    """
        :param requested_user : User : The user that is being requested
        :param return_as_query : bool : Whether to return the result as a query or a list

        :return list[User] : The list of users that the requested user is following
    """

    assert isinstance(requested_user, User), f"Expected requested_user to be of type User, got {requested_user.__class__}"

    FollowingQuery = User.query.join(FollowRelationship, FollowRelationship.followeeUserId == User.id).filter(FollowRelationship.followerUserId == requested_user.id)
    if return_as_query:
        return FollowingQuery
    
    return FollowingQuery.all()

def get_following_count(
    requested_user : User,

    skip_cache : bool = False
) -> int:
    """
        :param requested_user : User : The user that is being requested
        :param skip_cache : bool : Whether to skip the cache

        :return int : The number of users that the requested user is following
    """

    assert isinstance(requested_user, User), f"Expected requested_user to be of type User, got {requested_user.__class__}"

    if not skip_cache:
        CachedFollowingCount = redis_controller.get(f"services:followings:following_count:{requested_user.id}")
        if CachedFollowingCount is not None:
            return int(CachedFollowingCount)
        
    FollowingCount : int = get_following(requested_user, return_as_query = True).count()
    redis_controller.set(f"services:followings:following_count:{requested_user.id}", FollowingCount, ex = 10)

    return FollowingCount