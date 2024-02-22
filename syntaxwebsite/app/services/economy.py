from app.extensions import redis_controller, db
from app.util import redislock

from app.models.usereconomy import UserEconomy
from app.models.user import User
from app.models.userassets import UserAsset
from app.models.groups import Group, GroupEconomy
from app.models.asset import Asset
from app.models.asset_rap import AssetRap
from app.services.groups import GetGroupFromId, GetUserFromId

import redis_lock
import math

class InvalidCurrencyTypeException(Exception):
    pass
class EconomyLockAcquireException(Exception):
    pass
class InsufficientFundsException(Exception):
    pass
class AssetNotLimitedException(Exception):
    pass
class AssetDoesNotExistException(Exception):
    pass

def TaxCurrencyAmount( Amount : int ) -> int:
    return math.floor( Amount * 0.7 )

def GetAssetFromId( assetid : int | Asset ) -> Asset | None:
    """
        Returns the Asset object for the given assetid
    """
    if isinstance(assetid, Asset):
        return assetid
    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        raise AssetDoesNotExistException("Asset does not exist")
    return AssetObj

def GetUserEconomyObj( TargetUser : User ) -> UserEconomy | None:
    """
        Returns the UserEconomy object for the given user
    """
    return UserEconomy.query.filter_by( userid=TargetUser.id ).first()

def GetGroupEconomyObj( TargetGroup : Group ) -> GroupEconomy | None:
    """
        Returns the GroupEconomy object for the given group
    """
    return GroupEconomy.query.filter_by( group_id=TargetGroup.id ).first()

def GetUserBalance( TargetUser : User ) -> tuple[int, int]:
    """
        Returns the User's Robux and Tickets balance
    """
    EconomyObj : UserEconomy = GetUserEconomyObj( TargetUser )
    return EconomyObj.robux, EconomyObj.tix

def GetGroupBalance( TargetGroup : Group ) -> tuple[int, int]:
    """
        Returns the Group's Robux and Tickets balance
    """
    EconomyObj : GroupEconomy = GetGroupEconomyObj( TargetGroup )
    return EconomyObj.robux_balance, EconomyObj.tix_balance

def UnsafeIncrementTargetBalance( Target : User | Group, Amount : int, CurrencyType : int ): # CurrencyType is 0 for Robux, 1 for Tickets
    """
        Increments the Target Balance ( Not Recommended for normal use please instead use IncrementTargetBalance)
    """
    if isinstance(Target, User):
        TargetEconomyObj : UserEconomy = GetUserEconomyObj( Target )
        if CurrencyType == 0:
            TargetEconomyObj.robux += Amount
        elif CurrencyType == 1:
            TargetEconomyObj.tix += Amount
        else:
            raise InvalidCurrencyTypeException("Invalid Currency Type")
        db.session.commit()
    elif isinstance(Target, Group):
        TargetEconomyObj : GroupEconomy = GetGroupEconomyObj( Target )
        if CurrencyType == 0:
            TargetEconomyObj.robux_balance += Amount
        elif CurrencyType == 1:
            TargetEconomyObj.tix_balance += Amount
        else:
            raise InvalidCurrencyTypeException("Invalid Currency Type")
        db.session.commit()
    else:
        raise TypeError("Invalid Target Type")

def UnsafeDecrementTargetBalance( Target : User | Group, Amount : int, CurrencyType : int ): # CurrencyType is 0 for Robux, 1 for Tickets
    """
        Decrements the Target Balance ( Not Recommended for normal use please instead use DecrementTargetBalance)
    """
    if isinstance(Target, User):
        TargetEconomyObj : UserEconomy = GetUserEconomyObj( Target )
        if CurrencyType == 0:
            TargetEconomyObj.robux -= Amount
        elif CurrencyType == 1:
            TargetEconomyObj.tix -= Amount
        else:
            raise InvalidCurrencyTypeException("Invalid Currency Type")
        db.session.commit()
    elif isinstance(Target, Group):
        TargetEconomyObj : GroupEconomy = GetGroupEconomyObj( Target )
        if CurrencyType == 0:
            TargetEconomyObj.robux_balance -= Amount
        elif CurrencyType == 1:
            TargetEconomyObj.tix_balance -= Amount
        else:
            raise InvalidCurrencyTypeException("Invalid Currency Type")
        db.session.commit()
    else:
        raise TypeError("Invalid Target Type")
    
def IncrementTargetBalance( Target : User | Group, Amount : int, CurrencyType : int ): # CurrencyType is 0 for Robux, 1 for Tickets
    """
        Increments the Target Balance
    """
    if Amount < 0:
            raise ValueError("Amount must be positive")
    if isinstance(Target, User):
        with redis_lock.Lock( redis_client = redis_controller, name = f"economy:{Target.id}", expire = 1, auto_renewal = True ):
            UnsafeIncrementTargetBalance( Target, Amount, CurrencyType )
        return
    elif isinstance(Target, Group):
        with redis_lock.Lock( redis_client = redis_controller, name = f"economy_group:{Target.id}", expire = 1, auto_renewal = True ):
            UnsafeIncrementTargetBalance( Target, Amount, CurrencyType )
        return
    else:
        raise TypeError("Invalid Target Type")

def DecrementTargetBalance( Target : User | Group, Amount : int, CurrencyType : int ): # CurrencyType is 0 for Robux, 1 for Tickets
    """
        Decrements the Target Balance
    """
    if Amount < 0:
        raise ValueError("Amount must be positive")
    if isinstance(Target, User):
        with redis_lock.Lock( redis_client = redis_controller, name = f"economy:{Target.id}", expire = 1, auto_renewal = True ):
            TargetEconomyObj : UserEconomy = GetUserEconomyObj( Target )
            if CurrencyType == 0:
                if TargetEconomyObj.robux < Amount:
                    raise InsufficientFundsException("Insufficient Funds")
            elif CurrencyType == 1:
                if TargetEconomyObj.tix < Amount:
                    raise InsufficientFundsException("Insufficient Funds")
            UnsafeDecrementTargetBalance( Target, Amount, CurrencyType )
        return
    elif isinstance(Target, Group):
        with redis_lock.Lock( redis_client = redis_controller, name = f"economy_group:{Target.id}", expire = 1, auto_renewal = True ):
            TargetEconomyObj : GroupEconomy = GroupEconomy.query.filter_by( group_id=Target.id ).first()
            if CurrencyType == 0:
                if TargetEconomyObj.robux_balance < Amount:
                    raise InsufficientFundsException("Insufficient Funds")
            elif CurrencyType == 1:
                if TargetEconomyObj.tix_balance < Amount:
                    raise InsufficientFundsException("Insufficient Funds")
            UnsafeDecrementTargetBalance( Target, Amount, CurrencyType )
        return
    else:
        raise TypeError("Invalid Target Type")

def TransferFunds( Source : User | Group, Target : User | Group, Amount : int, CurrencyType : int, ApplyTax : bool = False): # CurrencyType is 0 for Robux, 1 for Tickets
    """
        Transfers funds from the source to the target
    """

    if Amount < 0:
        raise ValueError("Amount must be positive")
    if Source == Target:
        raise ValueError("Source and Target must be different")
    if CurrencyType not in [0,1]:
        raise InvalidCurrencyTypeException("Invalid Currency Type")
    if isinstance(Source, User):
        SourceEconomyObj : UserEconomy = GetUserEconomyObj( Source )
        if CurrencyType == 0:
            if SourceEconomyObj.robux < Amount:
                raise InsufficientFundsException("Insufficient Funds")
        elif CurrencyType == 1:
            if SourceEconomyObj.tix < Amount:
                raise InsufficientFundsException("Insufficient Funds")
    elif isinstance(Source, Group):
        SourceEconomyObj : GroupEconomy = GroupEconomy.query.filter_by( group_id=Source.id ).first()
        if CurrencyType == 0:
            if SourceEconomyObj.robux_balance < Amount:
                raise InsufficientFundsException("Insufficient Funds")
        elif CurrencyType == 1:
            if SourceEconomyObj.tix_balance < Amount:
                raise InsufficientFundsException("Insufficient Funds")
    else:
        raise TypeError("Invalid Source Type")

    TakenAmount : int = Amount
    GivenAmount : int = Amount
    if ApplyTax:
        GivenAmount = TaxCurrencyAmount( Amount )
    try:
        DecrementTargetBalance( Source, TakenAmount, CurrencyType )
    except InsufficientFundsException:
        raise InsufficientFundsException("Insufficient Funds")
    IncrementTargetBalance( Target, GivenAmount, CurrencyType )

    return

def AdjustAssetRap(AssetObj : Asset | int, robux : int):
    """ Adjusts the RAP of an asset
        https://roblox.fandom.com/wiki/Recent_Average_Price
        This will only work with assets that are limited
    """
    AssetObj : Asset = GetAssetFromId(AssetObj)

    AssetRapObject : AssetRap = AssetRap.query.filter_by(assetid=AssetObj.id).first()
    if AssetRapObject is None:
        if not AssetObj.is_limited:
            raise AssetNotLimitedException("Asset is not limited")
        AssetRapObject = AssetRap(assetid=AssetObj.id, rap=robux)
        db.session.add(AssetRapObject)
        db.session.commit()
        return True
    if AssetRapObject.rap <= 0:
        AssetRapObject.rap = robux
    CurrentRAP = AssetRapObject.rap
    AssetRapObject.rap = math.floor(CurrentRAP - ( CurrentRAP - robux ) / 10)
    db.session.commit()
    return True

def GetAssetRap(AssetObj : Asset | int ) -> int:
    """
        Returns the RAP of an asset
    """
    AssetObj : Asset = GetAssetFromId(AssetObj)
    if not AssetObj.is_limited:
        raise AssetNotLimitedException("Asset is not limited")

    AssetRapObject : AssetRap = AssetRap.query.filter_by(assetid=AssetObj.id).first()
    if AssetRapObject is None:
        AssetRapObject = AssetRap(assetid=AssetObj.id, rap=0)
        db.session.add(AssetRapObject)
        db.session.commit()
    return AssetRapObject.rap

def GetCreatorOfAsset( AssetObj : Asset | int ) -> User | Group | None:
    """
        Returns the creator of an asset
    """
    AssetObj : Asset = GetAssetFromId(AssetObj)
    if AssetObj.creator_type == 1:
        return GetGroupFromId(AssetObj.creator_id)
    elif AssetObj.creator_type == 0:
        return GetUserFromId(AssetObj.creator_id)
    else:
        return None
    
def CalculateUserRAP( UserObj : User | int, skipCache : bool = False ) -> int:
    """
        Calculates the RAP of a user
    """
    if redis_controller.exists(f"rap_calculation:{UserObj.id}") and not skipCache:
        return int(redis_controller.get(f"rap_calculation:{UserObj.id}"))

    UserObj : User = GetUserFromId(UserObj)
    UserRAP : int = 0
    UserLimitedAssets : list[UserAsset] = UserAsset.query.filter_by(userid=UserObj.id).outerjoin( Asset, Asset.id == UserAsset.assetid ).filter( Asset.is_limited == True ).all()

    for UserLimitedAsset in UserLimitedAssets:
        UserRAP += GetAssetRap(UserLimitedAsset.assetid)

    redis_controller.set(f"rap_calculation:{UserObj.id}", UserRAP, ex = 60)
    return UserRAP