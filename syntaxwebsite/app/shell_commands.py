# Commands for flask shell
from app.extensions import db, redis_controller
from app.models.user import User
from app.util import auth
from sqlalchemy import func
import logging
def lookup_user_id():
    """Lookup user by Id"""
    try:
        UserId : int = int(input("User Lookup by UserId: "))
        if UserId < 0:
            raise Exception("UserId must be a positive integer")
    except Exception as e:
        logging.error(f"Unable to parse user input, please enter a valid integer, error: {e}")
    
    UserObj : User = User.query.filter_by(id=UserId).first()
    if UserObj is None:
        logging.error(f"Unable to find user with UserId: {UserId}")
    else:
        logging.info(f"""
Username : {UserObj.username}
UserId : {UserObj.id}
CreatedOn : {UserObj.created}
LastPing : {UserObj.lastonline}
AccountStatus : {UserObj.accountstatus}
2FA Enabled : {UserObj.TOTPEnabled}

-- Description --
{UserObj.description}
-- End Description --

""")

def lookup_user_name():
    """Lookup user by Username"""
    try:
        Username : str = str(input("User Lookup by Username: "))
        if len(Username) < 1:
            raise Exception("Username must be a valid string")
    except Exception as e:
        logging.error(f"Unable to parse user input, please enter a valid string, error: {e}")
    
    UserObj : User = User.query.filter(func.lower(User.username) == func.lower(Username)).first()
    if UserObj is None:
        logging.error(f"Unable to find user with Username: {Username}")
    else:
        logging.info(f"""
Username : {UserObj.username}
UserId : {UserObj.id}
CreatedOn : {UserObj.created}
LastPing : {UserObj.lastonline}
AccountStatus : {UserObj.accountstatus}
2FA Enabled : {UserObj.TOTPEnabled}

-- Description --
{UserObj.description}
-- End Description --

""")
        
def refund_unused_invite_keys():
    from app.models.invite_key import InviteKey
    from app.services.economy import IncrementTargetBalance
    from app.util.transactions import CreateTransaction
    from app.enums.TransactionType import TransactionType
    from app.pages.messages.messages import CreateSystemMessage

    allDistinctInviteKeyCreators : list[User] = User.query.join(InviteKey, User.id == InviteKey.created_by).filter(InviteKey.used_by == None).distinct(User.id).all()

    def process_user_invite_keys( userObj : User ):
        AmountOwed : int = 0
        InviteKeysDeleted : int = 0

        AllInviteKeys : list[InviteKey] = InviteKey.query.filter_by(created_by=userObj.id, used_by=None).all()
        for InviteKeyObj in AllInviteKeys:
            AmountOwed += 20
            InviteKeysDeleted += 1
            db.session.delete(InviteKeyObj)
        db.session.commit()

        if AmountOwed > 0:
            IncrementTargetBalance(userObj, AmountOwed, 0)
            CreateTransaction(
                Reciever = userObj,
                Sender = None,
                CurrencyAmount = AmountOwed,
                CurrencyType = 0,
                TransactionType = TransactionType.BuildersClubStipend,
                AssetId = None,
                CustomText = f"Refunded {InviteKeysDeleted} unused invite keys",
            )
            CreateSystemMessage(
                subject = "Invite Key Refund",
                message = f"""Hello {userObj.username},
    This is an automated message to inform you that as invite keys are no longer used on SYNTAX, we have refunded you R$ {AmountOwed} for {InviteKeysDeleted} unused invite keys. Please contact us on our Discord Server if you have any questions.

Sincerely,
The SYNTAX Team""",
                userid = userObj.id
            )

            logging.info(f"Refunded {InviteKeysDeleted} unused invite keys for user {userObj.username}")
    
    logging.info(f"Found {len(allDistinctInviteKeyCreators)} users with unused invite keys")
    for UserObj in allDistinctInviteKeyCreators:
        process_user_invite_keys(UserObj)

def refund_limiteds():
    from app.models.userassets import UserAsset
    from app.models.asset import Asset
    from app.services.economy import IncrementTargetBalance, GetAssetRap
    from app.util.transactions import CreateTransaction
    from app.enums.TransactionType import TransactionType
    from app.enums.MembershipType import MembershipType
    from app.pages.messages.messages import CreateSystemMessage
    from app.models.user import User
    from app.util.membership import GetUserMembership
    import math

    limitedRAPValueLookup : dict[int, int] = {}
    refundCapAmount : dict [MembershipType, int] = {
        MembershipType.NonBuildersClub : 200,
        MembershipType.BuildersClub : 500,
        MembershipType.TurboBuildersClub : 750,
        MembershipType.OutrageousBuildersClub : 1200
    }

    def _get_limited_rap_value( assetId : int ):
        if assetId in limitedRAPValueLookup:
            return limitedRAPValueLookup[assetId]
        else:
            rapValue : int = GetAssetRap(assetId)
            limitedRAPValueLookup[assetId] = rapValue
            return rapValue

    def refund_user_limiteds( userObj : User ):
        WipedAssets : list = []
        AllLimitedUserAssets : list [UserAsset] = UserAsset.query.filter_by(userid=userObj.id).join(Asset, UserAsset.assetid == Asset.id).filter(Asset.is_limited == True).all()
        AmountOwed : int = 0

        for UserAssetObj in AllLimitedUserAssets:
            AssetObj : Asset = UserAssetObj.asset

            LimitedRAPValue : int = _get_limited_rap_value(UserAssetObj.assetid)
            AssetOriginalPrice : int = AssetObj.price_robux if AssetObj.price_robux > 0 else AssetObj.price_tix

            if ( not AssetObj.price_robux > 0 ) and AssetOriginalPrice > 0:
                AssetOriginalPrice = math.floor(AssetOriginalPrice / 10)
            
            RefundedAmount : int = max(AssetOriginalPrice if AssetOriginalPrice > LimitedRAPValue else LimitedRAPValue, 50)
            AmountOwed += RefundedAmount

            WipedAssets.append(f"   - {AssetObj.name} [UAID: {UserAssetObj.id} / Serial: {UserAssetObj.serial}] - R$ {RefundedAmount}")

            db.session.delete(UserAssetObj)
        db.session.commit()

        ActualAmountOwed = min(AmountOwed, refundCapAmount[GetUserMembership(userObj)])

        if ActualAmountOwed > 0:
            ItemListText : str = "\n".join(WipedAssets)

            IncrementTargetBalance(userObj, ActualAmountOwed, 0)
            CreateTransaction(
                Reciever = userObj,
                Sender = None,
                CurrencyAmount = ActualAmountOwed,
                CurrencyType = 0,
                TransactionType = TransactionType.BuildersClubStipend,
                AssetId = None,
                CustomText = f"Limited item refund",
            )

            CreateSystemMessage(
                subject = "Limited Item Refund",
                message = f"""Hello {userObj.username},

This is an automated message to inform you that all limited items are being refunded as we are resetting the economy. We have refunded you R$ {ActualAmountOwed} for the following items:
{ItemListText}

Item Refund Cap: R$ {refundCapAmount[GetUserMembership(userObj)]}
Total Value before Cap: R$ {AmountOwed}

Refunded Amount: R$ {ActualAmountOwed}

Please contact us on our Discord Server if you have any questions.

Sincerely,
The SYNTAX Team""",
                userid = userObj.id
            )

            logging.info(f"Refunded {len(AllLimitedUserAssets)} limited items for user {userObj.username}")
    
    AllUsersWithLimiteds : list[User] = User.query.join(UserAsset, User.id == UserAsset.userid).join(Asset, UserAsset.assetid == Asset.id).filter(Asset.is_limited == True).distinct(User.id).all()
    logging.info(f"Found {len(AllUsersWithLimiteds)} users with limiteds")

    for UserObj in AllUsersWithLimiteds:
        refund_user_limiteds(UserObj)

def delete_limited_assets():
    from app.models.asset import Asset
    from app.models.asset_version import AssetVersion
    from app.models.asset_thumbnail import AssetThumbnail

    # we have to delete these two table first as they have a relationship with Asset
    AllLimitedAssetVersions : list[AssetVersion] = AssetVersion.query.join(Asset, AssetVersion.asset_id == Asset.id).filter(Asset.is_limited == True).all()
    AllLimitedAssetThumbnails : list[AssetThumbnail] = AssetThumbnail.query.join(Asset, AssetThumbnail.asset_id == Asset.id).filter(Asset.is_limited == True).all()

    for AssetVersionObj in AllLimitedAssetVersions:
        db.session.delete(AssetVersionObj)
    for AssetThumbnailObj in AllLimitedAssetThumbnails:
        db.session.delete(AssetThumbnailObj)
    db.session.commit()

    AllLimitedAssets : list[Asset] = Asset.query.filter_by(is_limited=True).all()
    for AssetObj in AllLimitedAssets:
        db.session.delete(AssetObj)

    db.session.commit()

def clear_user_avatar_assets():
    from app.models.user_avatar_asset import UserAvatarAsset
    from app.models.asset import Asset
    from app.routes.thumbnailer import TakeUserThumbnail

    NeedReRender : list[int] = []

    AllUserAvatarAssets : list[UserAvatarAsset] = UserAvatarAsset.query.outerjoin(Asset, UserAvatarAsset.asset_id == Asset.id).filter(Asset.id == None).all()
    for UserAvatarAssetObj in AllUserAvatarAssets:
        if UserAvatarAssetObj.user_id not in NeedReRender:
            NeedReRender.append(UserAvatarAssetObj.user_id)
        db.session.delete(UserAvatarAssetObj)

    db.session.commit()

    for UserId in NeedReRender:
        logging.info(f"Re-rendering avatar for user {UserId}")
        TakeUserThumbnail(UserId)

def clear_bad_transactions():
    from app.models.user_transactions import UserTransaction
    from app.models.asset import Asset

    AllBadTransactions : list[UserTransaction] = UserTransaction.query.outerjoin(Asset, UserTransaction.assetId == Asset.id).filter(Asset.id == None).all()
    print(f"Found {len(AllBadTransactions)} bad transactions")
    
    while True:
        BatchTransactions : list[UserTransaction] = AllBadTransactions[:1000]
        if len(BatchTransactions) == 0:
            break
        for TransactionObj in BatchTransactions:
            db.session.delete(TransactionObj)
        db.session.commit()
        AllBadTransactions = AllBadTransactions[1000:]
        logging.info(f"Deleted 1000 bad transactions, {len(AllBadTransactions)} remaining")

def delete_asset( asset_id : int ):
    from app.models.asset import Asset
    from app.models.asset_version import AssetVersion
    from app.models.asset_thumbnail import AssetThumbnail
    
    AllAssetVersions : list[AssetVersion] = AssetVersion.query.filter_by(asset_id=asset_id).all()
    AllAssetThumbnails : list[AssetThumbnail] = AssetThumbnail.query.filter_by(asset_id=asset_id).all()

    for AssetVersionObj in AllAssetVersions:
        print(f"Deleting asset version {AssetVersionObj.id}")
        db.session.delete(AssetVersionObj)
    for AssetThumbnailObj in AllAssetThumbnails:
        print(f"Deleting asset thumbnail {AssetThumbnailObj.id}")
        db.session.delete(AssetThumbnailObj)
    
    db.session.commit()

    AssetObj : Asset = Asset.query.filter_by(id=asset_id).first()
    db.session.delete(AssetObj)

    db.session.commit()

def create_admin_user():
    """
        ! FIRST TIME SETUP ONLY !
        Creates a user with all admin permissions and a random password
        
        Note: will raise an exception if User ID 1 already exists
    """
    import datetime
    import random
    import string
    from app.models.user import User
    from app.models.admin_permissions import AdminPermissions
    from app.models.usereconomy import UserEconomy
    from app.models.user_avatar import UserAvatar
    from app.util.auth import SetPassword
    from app.pages.admin.permissionsdefinition import PermissionsDefinition

    if User.query.filter_by(id=1).first() is not None:
        raise Exception("User ID 1 already exists")
    
    NewUser : User = User(
        username = "Admin",
        password = "",
        created = datetime.datetime.utcnow(),
        lastonline = datetime.datetime.utcnow()
    )

    db.session.add(NewUser)
    db.session.commit()

    NewPassword : str = ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for _ in range(24))

    SetPassword(
        UserObj = NewUser,
        password = NewPassword
    )

    UserEconomyObj : UserEconomy = UserEconomy(
        userid = NewUser.id,
        robux = 0,
        tix = 0,
    )

    db.session.add(UserEconomyObj)

    UserAvatarObj : UserAvatar = UserAvatar(
        user_id = NewUser.id,
    )

    db.session.add(UserAvatarObj)
    
    for permission_name in PermissionsDefinition:
        permissionObj : AdminPermissions = AdminPermissions(
            userid = NewUser.id,
            permission = permission_name
        )
        db.session.add(permissionObj)

    db.session.commit()

    print(f"""
Successfully created Admin User
Username: Admin
Password: {NewPassword}""")
    
def convert_places_to_universes():
    from app.models.asset import Asset
    from app.models.place import Place
    from app.models.universe import Universe
    from app.models.place_datastore import PlaceDatastore
    from app.models.place_ordered_datastore import PlaceOrderedDatastore
    from app.models.legacy_data_persistence import LegacyDataPersistence
    from app.models.place_badge import PlaceBadge
    from app.models.gamepass_link import GamepassLink
    from app.models.place_developer_product import DeveloperProduct

    AllPlaces : list[Place] = Place.query.filter_by( parent_universe_id = 0 ).order_by(Place.placeid).all()
    logging.info(f"convert_places_to_universes > Found {len(AllPlaces)} places to convert")
    for PlaceObj in AllPlaces:
        PlaceObj : Place
        try:
            PlaceAssetObj : Asset = Asset.query.filter_by( id = PlaceObj.placeid ).first()
            UniverseObj : Universe = Universe(
                root_place_id = PlaceObj.placeid,
                creator_id = PlaceAssetObj.creator_id,
                creator_type = PlaceAssetObj.creator_type,
                place_rig_choice = PlaceObj.rig_choice,
                place_year = PlaceObj.placeyear,
                is_featured = PlaceObj.featured,
                minimum_account_age = PlaceObj.min_account_age,
                bc_required = PlaceObj.bc_required,
                allow_direct_join = False,
                is_public = PlaceObj.is_public,
                updated_at = PlaceAssetObj.updated_at,
                created_at = PlaceAssetObj.created_at
            )
            db.session.add(UniverseObj)
            db.session.commit()

            logging.info(f"convert_places_to_universes > Created universe {UniverseObj.id} from place {PlaceObj.placeid}")
            PlaceObj.parent_universe_id = UniverseObj.id
            db.session.commit()

            logging.info(f"convert_places_to_universes > Converting place {PlaceObj.placeid}'s items to universe {UniverseObj.id}")

            db.session.query(PlaceDatastore).filter_by( placeid = PlaceObj.placeid ).update({"universe_id": UniverseObj.id})
            db.session.query(PlaceOrderedDatastore).filter_by( placeid = PlaceObj.placeid ).update({"universe_id": UniverseObj.id})
            db.session.query(LegacyDataPersistence).filter_by( placeid = PlaceObj.placeid ).update({"universe_id": UniverseObj.id})
            db.session.query(PlaceBadge).filter_by( associated_place_id = PlaceObj.placeid ).update({"universe_id": UniverseObj.id})
            db.session.query(GamepassLink).filter_by( place_id = PlaceObj.placeid ).update({"universe_id": UniverseObj.id})
            db.session.query(DeveloperProduct).filter_by( placeid = PlaceObj.placeid ).update({"universe_id": UniverseObj.id})

            db.session.commit()

            logging.info(f"convert_places_to_universes > Successfully converted place {PlaceObj.placeid}'s items to universe {UniverseObj.id}")
        except Exception as e:
            logging.error(f"convert_places_to_universes > Failed to migrate place {PlaceObj.placeid}, error: {e}")

def recalculate_universe_visits():
    from app.models.place import Place
    from app.models.universe import Universe

    AllUniverses : list[Universe] = Universe.query.all()
    logging.info(f"recalculate_universe_visits > Found {len(AllUniverses)} universes to recalculate")

    for UniverseObj in AllUniverses:
        try:
            UniverseObj : Universe
            UniverseObj.visit_count = Place.query.filter_by( parent_universe_id = UniverseObj.id ).with_entities(func.sum(Place.visitcount)).scalar()
            db.session.commit()
            logging.info(f"recalculate_universe_visits > Successfully recalculated universe {UniverseObj.id}, new visit count: {UniverseObj.visit_count}")

        except Exception as e:
            logging.error(f"recalculate_universe_visits > Failed to recalculate universe {UniverseObj.id}, error: {e}")

def reverse_item_transfer():
    from app.models.limited_item_transfers import LimitedItemTransfer
    from app.models.asset import Asset
    from app.models.user import User
    from app.services.economy import IncrementTargetBalance, DecrementTargetBalance, GetAssetRap
    from app.models.asset_rap import AssetRap
    from app.models.userassets import UserAsset
    import math
    from datetime import datetime
    from sqlalchemy import and_
    from app.pages.messages.messages import CreateSystemMessage

    def reverse_transfer( ItemTransferRecordObj : LimitedItemTransfer ):
        logging.info(f"reverse_item_transfer > Reversing transfer {ItemTransferRecordObj.id}")
        RecievingUserObj : User = User.query.filter_by( id = ItemTransferRecordObj.new_owner_id ).first()
        SendingUserObj : User = User.query.filter_by( id = ItemTransferRecordObj.original_owner_id ).first()
        UserAssetObj : UserAsset = UserAsset.query.filter_by( id = ItemTransferRecordObj.user_asset_id ).first()

        if RecievingUserObj is None or SendingUserObj is None or UserAssetObj is None:
            logging.error(f"reverse_item_transfer > Unable to find user or asset for transfer {ItemTransferRecordObj.id}")
            return
        
        AssetObj : Asset = Asset.query.filter_by( id = ItemTransferRecordObj.asset_id ).first()
        AssetRapObj : AssetRap = AssetRap.query.filter_by( assetid = AssetObj.id ).first()
        CurrentRapValue : int = GetAssetRap( AssetObj )
        ReversedRapValue : int = math.floor( ( ( CurrentRapValue * 10 ) - ItemTransferRecordObj.purchased_price ) / 9 )

        RobuxGivenToOriginalOwner : int = math.floor( ItemTransferRecordObj.purchased_price * 0.7 )

        UserAssetObj.userid = ItemTransferRecordObj.original_owner_id
        UserAssetObj.updated = datetime.utcnow()
        UserAssetObj.is_for_sale = False
        AssetRapObj.rap = ReversedRapValue
        db.session.commit()

        IncrementTargetBalance( Target = RecievingUserObj, Amount = ItemTransferRecordObj.purchased_price, CurrencyType = 0 )
        DecrementTargetBalance( Target = SendingUserObj, Amount = RobuxGivenToOriginalOwner, CurrencyType = 0 )

        CreateSystemMessage( subject = "Item Transfer Reversed", message = f"""Hello {RecievingUserObj.username},
This is an automated message to inform you that a recent item transfer has been reversed. You have been refunded R$ {ItemTransferRecordObj.purchased_price} for the item {AssetObj.name} which has been taken from your inventory.
Please contact us on our Discord Server if you have any questions.

Sincerely,
The SYNTAX Team""", userid = RecievingUserObj.id )

        CreateSystemMessage( subject = "Item Transfer Reversed", message = f"""Hello {SendingUserObj.username},
This is an automated message to inform you that a recent item transfer has been reversed. R$ {RobuxGivenToOriginalOwner} has been taken from your account and your item ( {AssetObj.name} ) has been returned to your inventory.
Please contact us on our Discord Server if you have any questions.

Sincerely,
The SYNTAX Team""", userid = SendingUserObj.id )
        
        logging.info(f"reverse_item_transfer > Successfully reversed transfer {ItemTransferRecordObj.id} - R$ {ItemTransferRecordObj.purchased_price} given to {RecievingUserObj.username}, R$ {RobuxGivenToOriginalOwner} taken from {SendingUserObj.username}")
        logging.info(f"reverse_item_transfer > New RAP value for asset {AssetObj.id}: {CurrentRapValue} -> {ReversedRapValue}")

    FradulentTransfers : list[LimitedItemTransfer] = LimitedItemTransfer.query.filter(and_( LimitedItemTransfer.id > 453, LimitedItemTransfer.id < 472 )).order_by(LimitedItemTransfer.id.desc()).all()
    logging.info(f"reverse_item_transfer > Found {len(FradulentTransfers)} fradulent transfers to reverse")

    for TransferObj in FradulentTransfers:
        reverse_transfer( TransferObj )

