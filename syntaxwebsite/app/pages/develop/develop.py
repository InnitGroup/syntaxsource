from flask import Blueprint, render_template, request, redirect, url_for, flash, abort, after_this_request, Response
from app.util import auth, redislock, websiteFeatures, s3helper, transactions
from app.util.assetvalidation import ValidateClothingImage, ValidatePlaceFile, ValidateMP3File, ValidateMP3AndConvertToOGG
from app.routes.thumbnailer import TakeThumbnail
from app.models.userassets import UserAsset
from app.util.assetversion import CreateNewAssetVersion, GetLatestAssetVersion
from app.util.textfilter import FilterText
from app.util.membership import GetUserMembership
from app.util.placeinfo import ClearUniversePlayingCountCache, ClearPlayingCountCache
from app.enums.MembershipType import MembershipType
from app.enums.ChatStyle import ChatStyle
from app.models.place import Place
from app.models.asset_version import AssetVersion
from app.models.asset import Asset
from app.models.user import User
from app.models.placeservers import PlaceServer
from app.models.placeserver_players import PlaceServerPlayer
from app.models.gameservers import GameServer
from app.models.asset_moderation_link import AssetModerationLink
from app.extensions import db, limiter, csrf, user_limiter
from app.models.place_icon import PlaceIcon
from app.models.asset_thumbnail import AssetThumbnail
from app.models.gamepass_link import GamepassLink
from app.models.place_developer_product import DeveloperProduct
from app.models.product_receipt import ProductReceipt
from app.models.groups import Group, GroupRole, GroupRolePermission, GroupMember
from app.models.place_badge import PlaceBadge, UserBadge
from app.models.universe import Universe
from app.enums.AssetType import AssetType
from app.enums.TransactionType import TransactionType
from app.enums.PlaceYear import PlaceYear
from app.enums.PlaceRigChoice import PlaceRigChoice
from app.services import economy, groups
from datetime import datetime, timedelta
from io import BytesIO
from config import Config
import requests
import logging
import hashlib
import os
import random
import time
import math

config = Config()

DevelopPagesRoute = Blueprint('DevelopPagesRoute', __name__, template_folder='pages')

def CountAlphanumericCharacters( string : str ):
    count = 0
    for char in string:
        if char.isalnum():
            count += 1
    return count

@DevelopPagesRoute.errorhandler( 429 )
def handle_ratelimit_reached(e):
    flash("You are being rate limited, please try again later", "error")
    return redirect(request.referrer)

@DevelopPagesRoute.route('/develop')
@auth.authenticated_required
def develop():
    PageType = request.args.get('type', default = 9, type = int)
    PageNumber = request.args.get('page', default = 1, type = int)
    GroupIdContext = request.args.get('groupId', default = None, type = int)

    AuthenticatedUser : User = auth.GetCurrentUser()

    CreatorId : int = AuthenticatedUser.id
    CreatorType : int = 0

    if GroupIdContext is not None and GroupIdContext > 0:
        GroupContext : Group = Group.query.filter_by(id=GroupIdContext).first()
        if GroupContext is None:
            return abort(404)
        ViewerGroupRole : GroupRole | None = groups.GetUserRolesetInGroup( AuthenticatedUser, GroupContext )
        if ViewerGroupRole is None:
            return abort(403)
        ViewerRolePermissions : GroupRolePermission = groups.GetRolesetPermission( ViewerGroupRole )
        if not ViewerRolePermissions.manage_items:
            return abort(403)

        CreatorId = GroupContext.id
        CreatorType = 1
    else:
        GroupIdContext = None
    
    UserGroups : list[Group] = Group.query.join(GroupMember, GroupMember.group_id == Group.id).filter(GroupMember.user_id == AuthenticatedUser.id).join(GroupRolePermission, GroupRolePermission.group_role_id == GroupMember.group_role_id).filter(GroupRolePermission.manage_items == True).all()

    PreviousPage = -1
    if PageNumber > 1:
        PreviousPage = PageNumber - 1
    NextPage = -1
    if PageType == 9:
        # Get all the places
        UserPlaces : list[Asset] = Asset.query.filter_by( creator_id=CreatorId, creator_type = CreatorType, asset_type=AssetType.Place ).join( Universe, Universe.root_place_id == Asset.id ).filter( Universe.id != None ).order_by( Universe.updated_at.desc() ).paginate(page = PageNumber, per_page = 10, error_out = False)
        if UserPlaces.has_next:
            NextPage = PageNumber + 1
        def GetPlaceUniverse( AssetObj : Asset ):
            return Universe.query.filter_by( root_place_id = AssetObj.id ).first()
        return render_template('develop/subpages/games.html', PageType=PageType, UserPlaces=UserPlaces.items, PreviousPage=PreviousPage, NextPage=NextPage, PageNumber= PageNumber, GroupIdContext = GroupIdContext, UserGroups = UserGroups, GetPlaceUniverse = GetPlaceUniverse)
    elif PageType == 11:
        # Get all the clothing
        UserClothing : list[Asset] = Asset.query.filter_by( creator_id=CreatorId, creator_type = CreatorType, asset_type=AssetType.Shirt ).order_by( Asset.updated_at.desc() ).paginate(page = PageNumber, per_page = 10, error_out = False)
        if UserClothing.has_next:
            NextPage = PageNumber + 1
        return render_template('develop/subpages/shirts.html', PageType=PageType, UserClothing=UserClothing.items, PreviousPage=PreviousPage, NextPage=NextPage, PageNumber= PageNumber, GroupIdContext = GroupIdContext, UserGroups = UserGroups)
    elif PageType == 12:
        UserClothing : list[Asset] = Asset.query.filter_by( creator_id=CreatorId, creator_type = CreatorType, asset_type=AssetType.Pants ).order_by( Asset.updated_at.desc() ).paginate(page = PageNumber, per_page = 10, error_out = False)
        if UserClothing.has_next:
            NextPage = PageNumber + 1
        return render_template('develop/subpages/pants.html', PageType=PageType, UserClothing=UserClothing.items, PreviousPage=PreviousPage, NextPage=NextPage, PageNumber= PageNumber, GroupIdContext = GroupIdContext, UserGroups = UserGroups)
    elif PageType == 2:
        UserClothing = Asset.query.filter_by( creator_id=CreatorId, creator_type = CreatorType, asset_type=AssetType.TShirt ).order_by( Asset.updated_at.desc() ).paginate(page = PageNumber, per_page = 10, error_out = False)
        if UserClothing.has_next:
            NextPage = PageNumber + 1
        return render_template('develop/subpages/tshirt.html', PageType=PageType, UserClothing=UserClothing, PreviousPage=PreviousPage, NextPage=NextPage, PageNumber= PageNumber, GroupIdContext = GroupIdContext, UserGroups = UserGroups)
    elif PageType == 3:
        UserSounds = Asset.query.filter_by( creator_id=CreatorId, creator_type = CreatorType, asset_type=AssetType.Audio ).order_by( Asset.updated_at.desc() ).paginate(page = PageNumber, per_page = 10, error_out = False)
        if UserSounds.has_next:
            NextPage = PageNumber + 1
        return render_template('develop/subpages/sound.html', PageType=PageType, UserSounds=UserSounds, PreviousPage=PreviousPage, NextPage=NextPage, PageNumber= PageNumber, GroupIdContext = GroupIdContext, UserGroups = UserGroups)
    elif PageType == 1:
        UserImages = Asset.query.filter_by( creator_id=CreatorId, creator_type = CreatorType, asset_type=AssetType.Image ).order_by( Asset.updated_at.desc() ).paginate(page = PageNumber, per_page = 10, error_out = False)
        if UserImages.has_next:
            NextPage = PageNumber + 1
        return render_template('develop/subpages/image.html', PageType=PageType, UserImages=UserImages, PreviousPage=PreviousPage, NextPage=NextPage, PageNumber= PageNumber, GroupIdContext = GroupIdContext, UserGroups = UserGroups)
    else:
        return redirect(url_for("DevelopPagesRoute.develop"))

@DevelopPagesRoute.route("/develop/create/<int:ReqAssetType>", methods=["POST"])
@auth.authenticated_required
@limiter.limit("15/minute")
@user_limiter.limit("15/minute")
def create(ReqAssetType):
    if ReqAssetType not in [9, 11, 12, 2, 3, 1]:
        flash("Invalid asset type", "error")
        return redirect(url_for("DevelopPagesRoute.develop"))
    if not websiteFeatures.GetWebsiteFeature("AssetCreation"):
        flash("Asset creation is temporarily disabled", "error")
        return redirect(url_for("DevelopPagesRoute.develop"))
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    TargetCreatorObj : User | Group = AuthenticatedUser
    CreatorType = 0

    groupIdContext = request.form.get(key = "groupIdContext", default = None, type = int)
    if groupIdContext is not None and groupIdContext > 0:
        GroupContext : Group = Group.query.filter_by(id=groupIdContext).first()
        if GroupContext is None:
            return abort(404)
        ViewerGroupRole : GroupRole | None = groups.GetUserRolesetInGroup( AuthenticatedUser, GroupContext )
        if ViewerGroupRole is None:
            return abort(403)
        ViewerRolePermissions : GroupRolePermission = groups.GetRolesetPermission( ViewerGroupRole )
        if not ViewerRolePermissions.manage_items:
            return abort(403)
        if not ViewerRolePermissions.create_items:
            flash("You do not have permission to create assets in this group", "error")
            return redirect(url_for("DevelopPagesRoute.develop", groupId=groupIdContext, type=ReqAssetType))
        if ReqAssetType == 9 and not ViewerRolePermissions.manage_group_games:
            flash("You do not have permission to create places in this group", "error")
            return redirect(url_for("DevelopPagesRoute.develop", groupId=groupIdContext, type=ReqAssetType))
        
        TargetCreatorObj = GroupContext
        CreatorType = 1
    
    CreateLockName = f"createasset_{TargetCreatorObj.id}"
    CreateLock = redislock.acquire_lock(CreateLockName, acquire_timeout=10, lock_timeout=1)
    if CreateLock is None:
        flash("You are creating too many assets at once", "error")
        return redirect(url_for("DevelopPagesRoute.develop"))

    @after_this_request
    def handle_group_context( response : Response ):
        if groupIdContext is not None and groupIdContext > 0:
            response = redirect(url_for("DevelopPagesRoute.develop", groupId=groupIdContext, type=ReqAssetType))
        return response

    if ReqAssetType == 9:
        # Check for the amount of places the user has
        AmountOfPlaces = Universe.query.filter_by( creator_id = TargetCreatorObj.id, creator_type = CreatorType ).count()
        MaxPlaces = 2
        if CreatorType == 0:
            UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser)
            if UserCurrentMembership == MembershipType.BuildersClub:
                MaxPlaces = 6
            elif UserCurrentMembership == MembershipType.TurboBuildersClub:
                MaxPlaces = 12
            elif UserCurrentMembership == MembershipType.OutrageousBuildersClub:
                MaxPlaces = 32
        else:
            MaxPlaces = 10
        
        if AmountOfPlaces >= MaxPlaces:
            redislock.release_lock(CreateLockName, CreateLock)
            flash(f"You can only have {str(MaxPlaces)} places max", "error")
            return redirect(url_for("DevelopPagesRoute.develop"))
        
        HasCreatedPlaceRecently : bool = Universe.query.filter_by( creator_id = TargetCreatorObj.id, creator_type = CreatorType ).filter(Universe.created_at > datetime.utcnow() - timedelta( hours = 1 )).first() is not None
        if HasCreatedPlaceRecently:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("You can only create one place every hour", "error")
            return redirect(url_for("DevelopPagesRoute.develop"))

        NewAsset : Asset = Asset(
            name = f"Untitled Place",
            description = "Check out my new place!",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Place,
            moderation_status=0,
            created_at=datetime.utcnow()
        )
        db.session.add(NewAsset)
        db.session.commit()

        NewPlace : Place = Place(
            placeid = NewAsset.id,
        )
        db.session.add(NewPlace)
        db.session.commit()

        DefaultPlaceFile = open("./app/files/Baseplate.rbxlx", "rb")
        PlaceFileContent = DefaultPlaceFile.read()
        DefaultPlaceFile.close()
        DefaultPlaceFileHash = hashlib.sha512(PlaceFileContent).hexdigest()
        if not s3helper.DoesKeyExist(DefaultPlaceFileHash):
            s3helper.UploadBytesToS3(PlaceFileContent, DefaultPlaceFileHash)
        
        NewAssetVersion : AssetVersion = CreateNewAssetVersion( NewAsset, DefaultPlaceFileHash, UploadedBy = AuthenticatedUser)
        if NewAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewAsset)
            db.session.delete(NewPlace)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop"))

        TakeThumbnail( AssetId=NewAsset.id, isIcon=False )
        TakeThumbnail( AssetId=NewAsset.id, isIcon=True )

        NewUniverse : Universe = Universe(
            root_place_id = NewAsset.id,
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            place_rig_choice = PlaceRigChoice.UserChoice,
            place_year = PlaceYear.Sixteen
        )
        db.session.add(NewUniverse)
        db.session.commit()

        NewPlace.parent_universe_id = NewUniverse.id
        db.session.commit()

        return redirect(url_for("DevelopPagesRoute.develop"))

    if ReqAssetType == 1: #Image
        ImageName = request.form.get("name", default = "Image", type = str)
        if ImageName is None:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=1))
        if ImageName == "":
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=1))
        if len(ImageName) > 50:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Name is too long, max: 50 characters", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=1))
        ImageName = FilterText(ImageName)
        ImageFile = request.files.get("file", default = None)
        ImageObj = ValidateClothingImage( ImageFile, verifyResolution=False, validateFileSize=False, returnImage=True )
        if ImageObj == False:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Invalid image file, Please make sure it is a PNG file and lesser than 3MB", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=1))
        if ImageFile.content_length > 1024 * 1024 * 3:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Image file is too large, max: 3MB", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=1))
        if ImageObj.size[0] > 2048 or ImageObj.size[1] > 2048:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Image resolution is too large, max: 2048 x 2048", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=1))
        
        NewImageAsset : Asset = Asset(
            name = ImageName,
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Image,
            created_at=datetime.utcnow()
        )
        db.session.add(NewImageAsset)
        db.session.commit()

        ImageFile = BytesIO()
        ImageObj.save(ImageFile, format="PNG")

        ImageFile.seek(0)
        ImageFileContent = ImageFile.read()
        ImageFileHash = hashlib.sha512(ImageFileContent).hexdigest()
        if not s3helper.DoesKeyExist(ImageFileHash):
            s3helper.UploadBytesToS3(ImageFileContent, ImageFileHash, contentType="image/png")
        
        NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAsset, ImageFileHash, UploadedBy = AuthenticatedUser)
        if NewImageAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewImageAsset)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=1))
        
        TakeThumbnail( AssetId=NewImageAsset.id, isIcon=False )

        return redirect(url_for("DevelopPagesRoute.develop", type=1))

    if ReqAssetType == 11: #shirt
        ShirtName = request.form.get("name", default = "Shirt", type = str)
        if ShirtName is None:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=11))
        if ShirtName == "":
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=11))
        if len(ShirtName) > 50:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Name is too long, max: 50 characters", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=11))
        ShirtName = FilterText(ShirtName)

        ShirtFile = request.files.get("file", default = None)
        isValidClothingFile = ValidateClothingImage( ShirtFile, returnImage = True )
        if not isValidClothingFile:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Invalid shirt file, Please make sure it is a PNG file 585 x 559 and lesser than 1mb", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=11))
        
        NewImageAsset : Asset = Asset(
            name = "Image",
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Image,
            created_at=datetime.utcnow()
        )
        db.session.add(NewImageAsset)
        db.session.commit()

        ShirtFile = BytesIO()
        isValidClothingFile.save(ShirtFile, format="PNG")

        ShirtFile.seek(0)
        ImageFileContent = ShirtFile.read()
        ShirtFileHash = hashlib.sha512(ImageFileContent).hexdigest()
        if not s3helper.DoesKeyExist(ShirtFileHash):
            s3helper.UploadBytesToS3(ImageFileContent, ShirtFileHash, contentType="image/png")
        
        NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAsset, ShirtFileHash, UploadedBy = AuthenticatedUser)
        if NewImageAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewImageAsset)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=11))
        
        TakeThumbnail( AssetId=NewImageAsset.id, isIcon=False )

        ShirtTemplateFile = open("./app/files/Shirt.rbxmx", "r")
        ShirtTemplateFileContent = ShirtTemplateFile.read()
        ShirtTemplateFile.close()
        ShirtTemplateFileContent = ShirtTemplateFileContent.format(ShirtImageId = str(NewImageAsset.id))
        ShirtTemplateFileHash = hashlib.sha512(ShirtTemplateFileContent.encode()).hexdigest()
        if not s3helper.DoesKeyExist(ShirtTemplateFileHash):
            s3helper.UploadBytesToS3(ShirtTemplateFileContent, ShirtTemplateFileHash)
        
        NewShirtAsset : Asset = Asset(
            name = ShirtName,
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Shirt,
            created_at=datetime.utcnow()
        )
        db.session.add(NewShirtAsset)
        db.session.commit()

        NewShirtAssetVersion : AssetVersion = CreateNewAssetVersion( NewShirtAsset, ShirtTemplateFileHash, UploadedBy = AuthenticatedUser)
        if NewShirtAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewShirtAsset)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=11))
        
        NewAssetModerationLink : AssetModerationLink = AssetModerationLink(
            ParentAssetId = NewShirtAsset.id,
            ChildAssetId = NewImageAsset.id
        )
        db.session.add(NewAssetModerationLink)

        NewUserAsset : UserAsset = UserAsset(
            userid = AuthenticatedUser.id,
            assetid = NewShirtAsset.id
        )
        db.session.add(NewUserAsset)
        db.session.commit()
        TakeThumbnail( AssetId=NewShirtAsset.id )
        return redirect(url_for("DevelopPagesRoute.develop", type=11))
    
    if ReqAssetType == 12: #pants
        PantsName = request.form.get("name", default = "Pants", type = str)
        if PantsName is None:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=12))
        if PantsName == "":
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=12))
        if len(PantsName) > 50:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Name is too long, max: 50 characters", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=12))
        PantsName = FilterText(PantsName)

        PantsFile = request.files.get("file", default = None)
        isValidClothingFile = ValidateClothingImage( PantsFile, returnImage = True )
        if not isValidClothingFile:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Invalid pants file, Please make sure it is a PNG file 585 x 559 and lesser than 1mb", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=12))
        
        NewImageAsset : Asset = Asset(
            name = "Image",
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Image,
            created_at=datetime.utcnow()
        )
        db.session.add(NewImageAsset)
        db.session.commit()

        PantsFile = BytesIO()
        isValidClothingFile.save(PantsFile, format="PNG")

        PantsFile.seek(0)
        ImageFileContent = PantsFile.read()
        PantsFileHash = hashlib.sha512(ImageFileContent).hexdigest()
        if not s3helper.DoesKeyExist(PantsFileHash):
            s3helper.UploadBytesToS3(ImageFileContent, PantsFileHash, contentType="image/png")
        
        NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAsset, PantsFileHash, UploadedBy = AuthenticatedUser)
        if NewImageAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewImageAsset)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=12))
        
        TakeThumbnail( AssetId=NewImageAsset.id, isIcon=False )

        PantsTemplateFile = open("./app/files/Pants.rbxmx", "r")
        PantsTemplateFileContent = PantsTemplateFile.read()
        PantsTemplateFile.close()
        PantsTemplateFileContent = PantsTemplateFileContent.format(PantsImageId = str(NewImageAsset.id))
        PantsTemplateFileHash = hashlib.sha512(PantsTemplateFileContent.encode()).hexdigest()
        if not s3helper.DoesKeyExist(PantsTemplateFileHash):
            s3helper.UploadBytesToS3(PantsTemplateFileContent, PantsTemplateFileHash)
        
        NewPantsAsset : Asset = Asset(
            name = PantsName,
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Pants,
            created_at=datetime.utcnow()
        )
        db.session.add(NewPantsAsset)
        db.session.commit()

        NewPantsAssetVersion : AssetVersion = CreateNewAssetVersion( NewPantsAsset, PantsTemplateFileHash, UploadedBy = AuthenticatedUser)
        if NewPantsAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewPantsAsset)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=12))
        
        NewAssetModerationLink : AssetModerationLink = AssetModerationLink(
            ParentAssetId = NewPantsAsset.id,
            ChildAssetId = NewImageAsset.id
        )
        db.session.add(NewAssetModerationLink)

        NewUserAsset : UserAsset = UserAsset(
            userid = AuthenticatedUser.id,
            assetid = NewPantsAsset.id
        )
        db.session.add(NewUserAsset)
        db.session.commit()
        TakeThumbnail( AssetId=NewPantsAsset.id )
        return redirect(url_for("DevelopPagesRoute.develop", type=12))
    
    if ReqAssetType == 2: #tshirt
        TShirtName = request.form.get("name", default = "T-Shirt", type = str)
        if TShirtName is None:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=2))
        if TShirtName == "":
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=2))
        if len(TShirtName) > 50:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Name is too long, max: 50 characters", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=2))
        TShirtName = FilterText(TShirtName)

        TShirtFile = request.files.get("file", default = None)
        isValidClothingFile = ValidateClothingImage( TShirtFile, verifyResolution = False, returnImage = True )
        if not isValidClothingFile:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Invalid TShirt file, Please make sure it is a PNG file and lesser than 1mb", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=2))
        
        NewImageAsset : Asset = Asset(
            name = "Image",
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Image,
            created_at=datetime.utcnow()
        )
        db.session.add(NewImageAsset)
        db.session.commit()

        TShirtFile = BytesIO()
        isValidClothingFile.save(TShirtFile, format="PNG")

        TShirtFile.seek(0)
        ImageFileContent = TShirtFile.read()
        TShirtFileHash = hashlib.sha512(ImageFileContent).hexdigest()
        if not s3helper.DoesKeyExist(TShirtFileHash):
            s3helper.UploadBytesToS3(ImageFileContent, TShirtFileHash, contentType="image/png")
        
        NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAsset, TShirtFileHash, UploadedBy = AuthenticatedUser)
        if NewImageAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewImageAsset)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=12))
        
        TakeThumbnail( AssetId=NewImageAsset.id, isIcon=False )

        TShirtTemplateFile = open("./app/files/TShirt.rbxmx", "r")
        TShirtTemplateFileContent = TShirtTemplateFile.read()
        TShirtTemplateFile.close()
        TShirtTemplateFileContent = TShirtTemplateFileContent.format(TShirtImageId = str(NewImageAsset.id))
        TShirtTemplateFileHash = hashlib.sha512(TShirtTemplateFileContent.encode()).hexdigest()
        if not s3helper.DoesKeyExist(TShirtTemplateFileHash):
            s3helper.UploadBytesToS3(TShirtTemplateFileContent, TShirtTemplateFileHash)
        
        NewTShirtAsset : Asset = Asset(
            name = TShirtName,
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.TShirt,
            created_at=datetime.utcnow()
        )
        db.session.add(NewTShirtAsset)
        db.session.commit()

        NewTShirtAssetVersion : AssetVersion = CreateNewAssetVersion( NewTShirtAsset, TShirtTemplateFileHash, UploadedBy = AuthenticatedUser)
        if NewTShirtAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewTShirtAsset)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=2))
        
        NewAssetModerationLink : AssetModerationLink = AssetModerationLink(
            ParentAssetId = NewTShirtAsset.id,
            ChildAssetId = NewImageAsset.id
        )
        db.session.add(NewAssetModerationLink)

        NewUserAsset : UserAsset = UserAsset(
            userid = AuthenticatedUser.id,
            assetid = NewTShirtAsset.id
        )
        db.session.add(NewUserAsset)
        db.session.commit()
        TakeThumbnail( AssetId=NewTShirtAsset.id )
        return redirect(url_for("DevelopPagesRoute.develop", type=2))


    if ReqAssetType == 3: #sound
        SoundName = request.form.get("name", default = "Sound", type = str)
        if SoundName is None:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        if SoundName == "":
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No name was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        if len(SoundName) > 50:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Name is too long, max: 50 characters", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        SoundName = FilterText(SoundName)
        
        SoundFile = request.files.get("file", default = None)
        if SoundFile is None:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No file was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        if SoundFile.filename == "":
            redislock.release_lock(CreateLockName, CreateLock)
            flash("No file was provided", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        
        # soundDuration = ValidateMP3File( SoundFile )
        # if soundDuration is None:
        #     redislock.release_lock(CreateLockName, CreateLock)
        #     flash("Invalid sound file, Please make sure it is a MP3 file and lesser than 4mb", "error")
        #     return redirect(url_for("DevelopPagesRoute.develop", type=3))


        if SoundFile.content_length > 1024 * 1024 * 8:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Sound file is too large, max: 8MB", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))

        try:
            ConvertedSoundData, soundDuration = ValidateMP3AndConvertToOGG( SoundFile )
        except Exception as e:
            redislock.release_lock(CreateLockName, CreateLock)
            flash(f"Failed to validate file: {str(e)}", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))

        if soundDuration > 60 * 8:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Sound is too long, max: 8 minutes", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))

        soundDurationHalfed = soundDuration
        if soundDuration > 20:
            soundDurationHalfed = 20 +  ((soundDuration - 20) * 0.5)

        
        
        creationCost = math.floor(max(20, soundDurationHalfed))
        robuxBalance, _ = economy.GetUserBalance(AuthenticatedUser)
        if robuxBalance < creationCost:
            redislock.release_lock(CreateLockName, CreateLock)
            flash(f"You do not have enough robux to create this sound, Required: R${str(creationCost)}", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        
        try:
            economy.DecrementTargetBalance(AuthenticatedUser, creationCost, 0)
        except economy.EconomyLockAcquireException:
            redislock.release_lock(CreateLockName, CreateLock)
            flash("Failed to create sound, Please try again later", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        except economy.InsufficientFundsException:
            redislock.release_lock(CreateLockName, CreateLock)
            flash(f"You do not have enough robux to create this sound, Required: R${str(creationCost)}", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        except Exception as e:
            redislock.release_lock(CreateLockName, CreateLock)
            logging.error(f"Failed to create sound, {str(e)}")
            flash("Failed to create sound, Please try again later", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        
        #transactions.CreateTransaction(User.query.filter_by(id=1).first(), AuthenticatedUser, creationCost, 0, TransactionType.Purchase, None, "Created Sound")
        transactions.CreateTransaction(
            Sender = AuthenticatedUser,
            CurrencyAmount = creationCost,
            CurrencyType = 0,
            TransactionType = TransactionType.Purchase,
            CustomText = "Created Sound"
        )

        #SoundFile.seek(0)
        SoundFileContent = ConvertedSoundData
        SoundFileHash = hashlib.sha512(SoundFileContent).hexdigest()

        if not s3helper.DoesKeyExist(SoundFileHash):
            s3helper.UploadBytesToS3(SoundFileContent, SoundFileHash, contentType="audio/ogg")
        
        NewSoundAsset : Asset = Asset(
            name = SoundName,
            description = "",
            creator_id = TargetCreatorObj.id,
            creator_type = CreatorType,
            asset_type = AssetType.Audio,
            created_at=datetime.utcnow()
        )
        db.session.add(NewSoundAsset)
        db.session.commit()

        NewSoundAssetVersion : AssetVersion = CreateNewAssetVersion( NewSoundAsset, SoundFileHash, UploadedBy = AuthenticatedUser)
        if NewSoundAssetVersion is None:
            redislock.release_lock(CreateLockName, CreateLock)
            db.session.delete(NewSoundAsset)
            db.session.commit()
            flash("Failed to create a new asset version, please report this error to our discord server", "error")
            return redirect(url_for("DevelopPagesRoute.develop", type=3))
        
        NewUserAsset : UserAsset = UserAsset(
            userid = AuthenticatedUser.id,
            assetid = NewSoundAsset.id
        )
        db.session.add(NewUserAsset)
        db.session.commit()
        TakeThumbnail( AssetId=NewSoundAsset.id )
        return redirect(url_for("DevelopPagesRoute.develop", type=3))

def isUserAllowedtoViewPage( ViewerUser : User, RelatedObj : Asset | Universe, abortOnFail : bool = True, isGameContext : bool = True ):
    if RelatedObj is None:
        if abortOnFail:
            abort(404)
        else:
            return False
    if RelatedObj.creator_id != ViewerUser.id and RelatedObj.creator_type == 0:
        if abortOnFail:
            abort(404)
        else:
            return False
    elif RelatedObj.creator_type == 1:
        ViewerGroupRole : GroupRole | None = groups.GetUserRolesetInGroup( ViewerUser, RelatedObj.creator_id )
        if ViewerGroupRole is None:
            if abortOnFail:
                abort(404)
            else:
                return False
        ViewerRolePermissions : GroupRolePermission = groups.GetRolesetPermission( ViewerGroupRole )
        if not ViewerRolePermissions.manage_items:
            if abortOnFail:
                abort(404)
            else:
                return False
        if not ViewerRolePermissions.manage_group_games:
            if abortOnFail:
                abort(404)
            else:
                return False
    if type(RelatedObj) != Universe:
        if RelatedObj.asset_type != AssetType.Place and isGameContext:
            if abortOnFail:
                abort(404)
            else:
                return False
    if RelatedObj.moderation_status != 0:
        if abortOnFail:
            abort(403)
        else:
            return False
    
    return True

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/manage", methods=["GET", "POST"])
@auth.authenticated_required
def ManageUniversePage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    if request.method == "GET":
        return render_template("develop/universes/manage.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj)
    else:
        PlaceName : str = request.form.get("name", default="", type=str)
        PlaceDescription : str = request.form.get("description", default="", type=str)
        try:
            AssetYear : PlaceYear = PlaceYear(request.form.get("place_year", default=2016, type=int))
        except ValueError:
            flash("Invalid year", "error")
            return redirect(f"/develop/universes/{universeid}/manage")
        if AssetYear not in [ PlaceYear.Sixteen, PlaceYear.Eighteen, PlaceYear.Twenty, PlaceYear.Fourteen, PlaceYear.TwentyOne ]:
            flash("Invalid year", "error")
            return redirect(f"/develop/universes/{universeid}/manage")

        if len(PlaceName) < 3 or len(PlaceName) > 50:
            flash("Place name has to be between 3 to 50 characters long", "error")
            return redirect(f"/develop/universes/{universeid}/manage")
        if len(PlaceDescription) < 3 or len(PlaceDescription) > 700:
            flash("Place description has to be between 3 to 700 characters long", "error")
            return redirect(f"/develop/universes/{universeid}/manage")

        if PlaceDescription.count("\n") > 10:
            flash("Place description can only have 10 or less newlines", "error")
            return redirect(f"/develop/universes/{universeid}/manage")

        if UniverseObj.place_year != AssetYear:
            TotalServersActive : int = PlaceServer.query.join(Place, Place.placeid == PlaceServer.serverPlaceId).join( Universe, Place.parent_universe_id == Universe.id ).filter( Universe.id == universeid ).count()
            if TotalServersActive > 0:
                flash("You cannot change the place year of the universe while there are active servers", "error")
                return redirect(f"/develop/universes/{universeid}/manage")
            UniverseObj.place_year = AssetYear
            flash("Successfully updated place year", "success")

        PlaceName = FilterText(PlaceName)
        PlaceDescription = FilterText(PlaceDescription)

        RootPlaceAssetObj.name = PlaceName
        RootPlaceAssetObj.description = PlaceDescription
        RootPlaceAssetObj.updated_at = datetime.utcnow()
        UniverseObj.updated_at = datetime.utcnow()

        db.session.commit()

        flash("Successfully updated place", "success")
        return redirect(f"/develop/universes/{universeid}/manage")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/access", methods=["GET", "POST"])
@auth.authenticated_required
def ManageUniverseAccessPage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    if request.method == "GET":
        return render_template("develop/universes/access.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj)
    else:
        MinimumAccountAge : int = request.form.get("minaccountage", default=0, type=int)
        if MinimumAccountAge < 0 or MinimumAccountAge > 365:
            flash("Minimum account age has to be between 0 to 365", "error")
            return redirect(f"/develop/universes/{universeid}/access")
        isPublic : bool = request.form.get("ispublic") == "on"
        BuildersClubRequired : bool = request.form.get("bcrequired") == "on"
        
        UniverseObj.minimum_account_age = MinimumAccountAge
        UniverseObj.is_public = isPublic
        UniverseObj.bc_required = BuildersClubRequired
        UniverseObj.updated_at = datetime.utcnow()
        db.session.commit()

        flash("Successfully updated place access", "success")
        return redirect(f"/develop/universes/{universeid}/access")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/places", methods=["GET"])
@auth.authenticated_required
def ManageUniversePlacesPage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    TotalAmountPlacesCreated : int = Place.query.filter_by(parent_universe_id = universeid).count()

    universePlaces : list[Place] = Place.query.filter_by(parent_universe_id = universeid).order_by(Place.placeid.asc()).all()

    return render_template("develop/universes/places.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, universePlaces=universePlaces, TotalAmountPlacesCreated=TotalAmountPlacesCreated)

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/create-place", methods=["GET", "POST"])
@auth.authenticated_required
def CreateUniversePlacePage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    TotalAmountPlacesCreated : int = Place.query.filter_by(parent_universe_id = universeid).count()

    if request.method == "GET":
        return render_template("develop/universes/create-place.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, TotalAmountPlacesCreated=TotalAmountPlacesCreated)
    else:
        if TotalAmountPlacesCreated >= 10:
            flash("You can only have 10 places in a universe", "error")
            return redirect(f"/develop/universes/{universeid}/places")
        
        place_creation_lock_name = f"place_creation_lock_{universeid}"
        place_creation_lock = redislock.acquire_lock( lock_name = place_creation_lock_name, acquire_timeout = 5, lock_timeout = 3 )
        if place_creation_lock is None:
            flash("Failed to create place, please try again later", "error")
            return redirect(f"/develop/universes/{universeid}/places")
        
        NewPlaceAsset : Asset = Asset(
            name = f"Untitled Place",
            description = "Check out my new place!",
            creator_id = UniverseObj.creator_id,
            creator_type = UniverseObj.creator_type,
            asset_type = AssetType.Place,
            moderation_status = 0,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        db.session.add(NewPlaceAsset)
        db.session.commit()

        NewPlace : Place = Place(
            placeid = NewPlaceAsset.id,
            parent_universe_id = universeid
        )
        db.session.add(NewPlace)
        db.session.commit()

        DefaultPlaceFile = open("./app/files/Baseplate.rbxlx", "rb")
        PlaceFileContent = DefaultPlaceFile.read()
        DefaultPlaceFile.close()
        DefaultPlaceFileHash = hashlib.sha512(PlaceFileContent).hexdigest()
        if not s3helper.DoesKeyExist(DefaultPlaceFileHash):
            s3helper.UploadBytesToS3(PlaceFileContent, DefaultPlaceFileHash)

        redislock.release_lock(place_creation_lock_name, place_creation_lock)

        NewAssetVersion : AssetVersion = CreateNewAssetVersion( NewPlaceAsset, DefaultPlaceFileHash, UploadedBy = AuthenticatedUser)
        if NewAssetVersion is None:
            db.session.delete(NewPlaceAsset)
            db.session.delete(NewPlace)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(f"/develop/universes/{universeid}/places")
        
        TakeThumbnail( AssetId=NewPlaceAsset.id, isIcon=False )
        TakeThumbnail( AssetId=NewPlaceAsset.id, isIcon=True )

        flash("Successfully created a new place", "success")

        return redirect(f"/develop/universes/{universeid}/places")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/gamepasses", methods=["GET"])
@auth.authenticated_required
def ManageUniverseGamepassesPage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    Gamepasses : list[GamepassLink] = GamepassLink.query.filter_by(universe_id = UniverseObj.id).all()

    return render_template("develop/universes/gamepasses.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, Gamepasses=Gamepasses)

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/gamepass/<int:gamepassid>", methods=["GET", "POST"])
@auth.authenticated_required
def ManageUniverseGamepassPage( universeid : int, gamepassid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    GamepassObj : GamepassLink = GamepassLink.query.filter_by( gamepass_id = gamepassid, universe_id = UniverseObj.id ).first()
    if GamepassObj is None:
        abort(404)

    if request.method == "GET":
        return render_template("develop/universes/edit-gamepass.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, GamepassObj=GamepassObj)
    else:
        AssetName = request.form.get("pass-name", default = "", type = str)
        AssetDescription = request.form.get("pass-description", default = "", type = str)
        isForSale = request.form.get("is-for-sale", default = "off") == "on"
        AssetRobuxPrice = request.form.get("robux-cost", default = 0, type = int)

        if AssetName == "":
            flash("Name cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
        if len(AssetName) > 35:
            flash("Name cannot be longer than 35 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
        if CountAlphanumericCharacters(AssetName) < 3:
            flash("Name must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
        
        if AssetDescription == "":
            flash("Description cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
        if len(AssetDescription) > 200:
            flash("Description cannot be longer than 200 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
        
        if (AssetRobuxPrice < 1 or AssetRobuxPrice > 1000000 ):
            flash("Robux price has to be between 1 to 1,000,000", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
        UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser)
        if UserCurrentMembership == MembershipType.NonBuildersClub and isForSale:
            flash("You must be Builders Club to sell items", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
        
        AssetName = FilterText(AssetName)
        AssetDescription = FilterText(AssetDescription)

        NewIconFile = request.files.get("icon-file", default = None)
        if NewIconFile is not None:
            if NewIconFile.filename != "":
                if NewIconFile.content_length > 1024 * 1024:
                    flash("File size is too big", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
                IconImage = ValidateClothingImage( NewIconFile, verifyResolution=False, validateFileSize=False, returnImage=True )
                if IconImage is False or IconImage is None:
                    flash("Invalid image", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
                if IconImage.width != IconImage.height:
                    flash("Image is not square", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
                if IconImage.width < 128 or IconImage.width > 1024:
                    flash("Image is not between 128x128 and 1024x1024", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
                NewIconFile = BytesIO()
                IconImage.save(NewIconFile, format="PNG")

                NewIconFile.seek(0)
                IconImageHash = hashlib.sha512(NewIconFile.read()).hexdigest()
                if not s3helper.DoesKeyExist(IconImageHash):
                    NewIconFile.seek(0)
                    s3helper.UploadBytesToS3(NewIconFile.read(), IconImageHash, contentType="image/png")
                LatestAssetThumbnail : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=GamepassObj.gamepass_id).order_by(AssetThumbnail.asset_version_id.desc()).first()
                if LatestAssetThumbnail is None:
                    flash("Failed to get latest asset thumbnail", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
                LatestAssetThumbnail.content_hash = IconImageHash
                LatestAssetThumbnail.created_at = datetime.utcnow()
                LatestAssetThumbnail.moderation_status = 1
                db.session.commit()
                flash("Successfully updated gamepass icon", "success")
    
        GamepassObj.gamepass.name = AssetName
        GamepassObj.gamepass.description = AssetDescription
        GamepassObj.gamepass.is_for_sale = isForSale
        GamepassObj.gamepass.price_robux = AssetRobuxPrice
        GamepassObj.gamepass.updated_at = datetime.utcnow()
        db.session.commit()
        flash("Successfully updated gamepass settings", "success")

        return redirect(f"/develop/universes/{UniverseObj.id}/gamepass/{GamepassObj.gamepass_id}")
    
@DevelopPagesRoute.route("/develop/universes/<int:universeid>/create-gamepass", methods=["GET", "POST"])
@auth.authenticated_required
def CreateUniverseGamepassPage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    if request.method == "GET":
        return render_template("develop/universes/create-gamepass.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj)
    else:
        gamepassName = request.form.get("name", default="", type=str)
        gamepassDescription = request.form.get("description", default="", type=str)
        file = request.files.get("file", default=None)

        if gamepassName == "":
            flash("Name cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        if len(gamepassName) > 35:
            flash("Name cannot be longer than 35 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        if CountAlphanumericCharacters(gamepassName) < 3:
            flash("Name must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")

        if gamepassDescription == "":
            flash("Description cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        if len(gamepassDescription) > 200:
            flash("Description cannot be longer than 200 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        
        if file is None:
            flash("No file was provided", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        if file.filename == "":
            flash("No file was provided", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        if file.content_length > 1024 * 1024:
            flash("File size is too big", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        
        GamepassCount : int = GamepassLink.query.filter_by(universe_id = UniverseObj.id).count()
        if GamepassCount >= 15:
            flash("You cannot create more than 15 gamepasses for a place", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        
        FileImage = ValidateClothingImage(file, verifyResolution=False, validateFileSize=False, returnImage=True)
        if FileImage is False or FileImage is None:
            flash("Invalid image", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        if FileImage.width != FileImage.height:
            flash("Image is not square", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        if FileImage.width < 128 or FileImage.width > 1024:
            flash("Image is not between 128x128 and 1024x1024", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        
        gamepassName = FilterText(gamepassName)
        gamepassDescription = FilterText(gamepassDescription)

        file = BytesIO()
        FileImage.save(file, format="png")

        file.seek(0)
        FileImageHash = hashlib.sha512(file.read()).hexdigest()
        if not s3helper.DoesKeyExist(FileImageHash):
            file.seek(0)
            s3helper.UploadBytesToS3(file.read(), FileImageHash, contentType="image/png")
        
        NewGamepassObj : Asset = Asset(
            name = gamepassName,
            description = gamepassDescription,
            creator_id = UniverseObj.creator_id,
            creator_type = UniverseObj.creator_type,
            asset_type = AssetType.GamePass,
            created_at = datetime.utcnow(),
            updated_at = datetime.utcnow(),
            moderation_status = 0
        )
        db.session.add(NewGamepassObj)
        db.session.commit()

        NewGamepassLink : GamepassLink = GamepassLink(
            place_id = UniverseObj.root_place_id,
            universe_id = UniverseObj.id,
            gamepass_id = NewGamepassObj.id,
            creator_id = AuthenticatedUser.id
        )
        db.session.add(NewGamepassLink)
        db.session.commit()

        EmptyHash = hashlib.sha512(b"").hexdigest()
        NewGamepassVersion : AssetVersion = CreateNewAssetVersion( NewGamepassObj, EmptyHash, ForceNewVersion = True, UploadedBy = AuthenticatedUser)
        if NewGamepassVersion is None:
            db.session.delete(NewGamepassObj)
            db.session.delete(NewGamepassLink)
            db.session.commit()
            flash("Failed to create a new asset version", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-gamepass")
        
        NewGamepassThumbnail : AssetThumbnail = AssetThumbnail(
            asset_id = NewGamepassObj.id,
            asset_version_id = NewGamepassVersion.version,
            content_hash = FileImageHash,
            created_at = datetime.utcnow(),
            moderation_status = 1
        )
        db.session.add(NewGamepassThumbnail)
        db.session.commit()

        flash("Successfully created gamepass", "success")
        return redirect(f"/develop/universes/{UniverseObj.id}/gamepasses")
    
@DevelopPagesRoute.route("/develop/universes/<int:universeid>/developer-products", methods=["GET"])
@auth.authenticated_required
def ManageUniverseDeveloperProductsPage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    DeveloperProducts : list[DeveloperProduct] = DeveloperProduct.query.filter_by(universe_id = UniverseObj.id).all()

    return render_template("develop/universes/developerproducts.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, DeveloperProducts=DeveloperProducts)

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/create-product", methods=["GET", "POST"])
@auth.authenticated_required
def CreateUniveseDeveloperProductPage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    if request.method == "GET":
        return render_template("develop/universes/create-product.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj)
    else:
        productName = request.form.get("name", default="", type=str)
        productDescription = request.form.get("description", default="", type=str)
        file = request.files.get("file", default=None)

        if productName == "":
            flash("Name cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        if len(productName) > 35:
            flash("Name cannot be longer than 35 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        if CountAlphanumericCharacters(productName) < 3:
            flash("Name must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")

        if productDescription == "":
            flash("Description cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        if len(productDescription) > 200:
            flash("Description cannot be longer than 200 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        
        if file is None:
            flash("No file was provided", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        if file.filename == "":
            flash("No file was provided", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        if file.content_length > 1024 * 1024:
            flash("File size is too big", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        
        FileImage = ValidateClothingImage(file, verifyResolution=False, validateFileSize=False, returnImage=True)
        if FileImage is False or FileImage is None:
            flash("Invalid image", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        if FileImage.width != FileImage.height:
            flash("Image is not square", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        if FileImage.width < 128 or FileImage.width > 1024:
            flash("Image is not between 128x128 and 1024x1024", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        
        productName = FilterText(productName)
        productDescription = FilterText(productDescription)

        file = BytesIO()
        FileImage.save(file, format="png")

        file.seek(0)
        FileImageHash = hashlib.sha512(file.read()).hexdigest()
        if not s3helper.DoesKeyExist(FileImageHash):
            file.seek(0)
            s3helper.UploadBytesToS3(file.read(), FileImageHash, contentType="image/png")
        
        NewImageAssetObj : Asset = Asset(
            name = "DeveloperProductImage",
            description = "DeveloperProduct icon",
            creator_id = AuthenticatedUser.id,
            creator_type = 0,
            asset_type = AssetType.Image,
            created_at = datetime.utcnow(),
            updated_at = datetime.utcnow(),
            moderation_status = 1
        )
        db.session.add(NewImageAssetObj)
        db.session.commit()

        NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAssetObj, FileImageHash, ForceNewVersion = True, UploadedBy = AuthenticatedUser)
        if NewImageAssetVersion is None:
            db.session.delete(NewImageAssetObj)
            db.session.commit()
            flash("Failed to create a new asset version, please contact support", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-product")
        
        NewDeveloperProductObj : DeveloperProduct = DeveloperProduct(
            placeid = UniverseObj.root_place_id,
            name = productName,
            description = productDescription,
            iconimage_assetid = NewImageAssetObj.id,
            creator_id = AuthenticatedUser.id,
            universe_id = UniverseObj.id
        )
        TakeThumbnail( AssetId=NewImageAssetObj.id, isIcon=False )

        db.session.add(NewDeveloperProductObj)
        db.session.commit()

        flash("Successfully created developer product", "success")
        return redirect(f"/develop/universes/{UniverseObj.id}/developer-products")
    
@DevelopPagesRoute.route("/develop/universes/<int:universeid>/developer-products/<int:productid>", methods=["GET", "POST"])
@auth.authenticated_required
def ManageUniverseDeveloperProductPage( universeid : int, productid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    DeveloperProductObj : DeveloperProduct = DeveloperProduct.query.filter_by(universe_id = UniverseObj.id, productid = productid).first()
    if DeveloperProductObj is None:
        abort(404)
    
    if request.method == "GET":
        return render_template("develop/universes/edit-product.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, ProductObj=DeveloperProductObj)
    else:
        productName = request.form.get("product-name", default="", type=str)
        productDescription = request.form.get("product-description", default="", type=str)
        file = request.files.get("icon-file", default=None)
        is_for_sale = request.form.get("is-for-sale", default="off") == "on"
        robux_price = request.form.get("robux-cost", default=0, type=int)

        if productName == "":
            flash("Name cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
        if len(productName) > 35:
            flash("Name cannot be longer than 35 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
        if CountAlphanumericCharacters(productName) < 3:
            flash("Name must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
        
        if productDescription == "":
            flash("Description cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
        if len(productDescription) > 200:
            flash("Description cannot be longer than 200 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
        
        if (robux_price < 1 or robux_price > 1000000 ):
            flash("Robux price has to be between 1 to 1,000,000", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
        UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser)
        if UserCurrentMembership == MembershipType.NonBuildersClub and is_for_sale:
            flash("You must be a Builders Club member to sell items", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
        
        productName = FilterText(productName)
        productDescription = FilterText(productDescription)

        if file is not None:
            if file.filename != "":
                if file.content_length > 1024 * 1024:
                    flash("File size is too big", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
                FileImage = ValidateClothingImage(file, verifyResolution=False, validateFileSize=False, returnImage=True)
                if FileImage is False or FileImage is None:
                    flash("Invalid image", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
                if FileImage.width != FileImage.height:
                    flash("Image is not square", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
                if FileImage.width < 128 or FileImage.width > 1024:
                    flash("Image is not between 128x128 and 1024x1024", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
                file = BytesIO()
                FileImage.save(file, format="PNG")
                
                file.seek(0)
                FileImageHash = hashlib.sha512(file.read()).hexdigest()
                if not s3helper.DoesKeyExist(FileImageHash):
                    file.seek(0)
                    s3helper.UploadBytesToS3(file.read(), FileImageHash, contentType="image/png")

                NewImageAssetObj : Asset = Asset(
                    name = "DeveloperProductImage",
                    description = "DeveloperProduct icon",
                    creator_id = AuthenticatedUser.id,
                    creator_type = 0,
                    asset_type = AssetType.Image,
                    created_at = datetime.utcnow(),
                    updated_at = datetime.utcnow(),
                    moderation_status = 1
                )
                db.session.add(NewImageAssetObj)
                db.session.commit()

                NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAssetObj, FileImageHash, ForceNewVersion = True, UploadedBy = AuthenticatedUser)
                if NewImageAssetVersion is None:
                    db.session.delete(NewImageAssetObj)
                    db.session.commit()
                    flash("Failed to create a new asset version, please contact support", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")

                TakeThumbnail( AssetId = NewImageAssetObj.id, isIcon=False )
                DeveloperProductObj.iconimage_assetid = NewImageAssetObj.id

                flash("Successfully updated developer product icon", "success")
        
        DeveloperProductObj.name = productName
        DeveloperProductObj.description = productDescription
        DeveloperProductObj.is_for_sale = is_for_sale
        DeveloperProductObj.robux_price = robux_price
        DeveloperProductObj.updated_at = datetime.utcnow()
        db.session.commit()
        flash("Successfully updated developer product settings", "success")

        return redirect(f"/develop/universes/{UniverseObj.id}/developer-products/{DeveloperProductObj.productid}")
    
@DevelopPagesRoute.route("/develop/universes/<int:universeid>/badges", methods=["GET"])
@auth.authenticated_required
def ManageUniverseBadgesPage( universeid : int ):
    from app.pages.games.games import GetTotalBadgeAwardedCount, GetBadgeAwardedPastDay # Avoid circular import

    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    Badges : list[PlaceBadge] = PlaceBadge.query.filter_by(universe_id = UniverseObj.id).all()

    return render_template("develop/universes/badges.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, Badges=Badges, GetTotalBadgeAwardedCount=GetTotalBadgeAwardedCount, GetBadgeAwardedPastDay=GetBadgeAwardedPastDay)

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/create-badge", methods=["GET", "POST"])
@auth.authenticated_required
def CreateUniverseBadgePage( universeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    if request.method == "GET":
        return render_template("develop/universes/create-badge.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj)
    else:
        BadgeName = request.form.get("name", default = "", type = str)
        BadgeDescription = request.form.get("description", default = "", type = str)
        file = request.files.get("icon-file", default=None)

        if BadgeName == "":
            flash("Badge name cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if len(BadgeName) > 35:
            flash("Badge name cannot be longer than 35 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if CountAlphanumericCharacters(BadgeName) < 3:
            flash("Badge name must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        
        if BadgeDescription == "":
            flash("Badge description cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if len(BadgeDescription) > 128:
            flash("Badge description cannot be longer than 128 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if CountAlphanumericCharacters(BadgeDescription) < 3:
            flash("Badge description must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")

        BadgeName = FilterText(BadgeName)
        BadgeDescription = FilterText(BadgeDescription)

        TotalBadgeCount : int = PlaceBadge.query.filter_by(universe_id = UniverseObj.id).count()
        if TotalBadgeCount >= 25:
            flash("You cannot create more than 25 badges for a place", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")

        if file is None:
            flash("No file was provided", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if file.filename == "":
            flash("No file was provided", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if file.content_length > 1024 * 1024:
            flash("File size is too big", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        FileImage = ValidateClothingImage(file, verifyResolution=False, validateFileSize=False, returnImage=True)
        if FileImage is False or FileImage is None:
            flash("Invalid image", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if FileImage.width != FileImage.height:
            flash("Image is not square", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        if FileImage.width < 128 or FileImage.width > 1024:
            flash("Image is not between 128x128 and 1024x1024", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")
        file = BytesIO()
        FileImage.save(file, format="PNG")

        file.seek(0)
        FileImageHash = hashlib.sha512(file.read()).hexdigest()
        if not s3helper.DoesKeyExist(FileImageHash):
            file.seek(0)
            s3helper.UploadBytesToS3(file.read(), FileImageHash, contentType="image/png")

        NewImageAssetObj : Asset = Asset(
            name = "BadgeImage",
            description = "Badge icon",
            creator_id = AuthenticatedUser.id,
            creator_type = 0,
            asset_type = AssetType.Image,
            created_at = datetime.utcnow(),
            updated_at = datetime.utcnow(),
            moderation_status = 1
        )
        db.session.add(NewImageAssetObj)
        db.session.commit()

        NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAssetObj, FileImageHash, ForceNewVersion = True, UploadedBy = AuthenticatedUser)

        if NewImageAssetVersion is None:
            db.session.delete(NewImageAssetObj)
            db.session.commit()
            flash("Failed to create a new asset version, please contact support", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/create-badge")

        TakeThumbnail( AssetId = NewImageAssetObj.id, isIcon=False )
        NewBadgeObj : PlaceBadge = PlaceBadge(
            associated_place_id = UniverseObj.root_place_id,
            name = BadgeName,
            description = BadgeDescription,
            icon_image_id = NewImageAssetObj.id,
            universe_id = UniverseObj.id
        )
        db.session.add(NewBadgeObj)
        db.session.commit()

        flash("Successfully created badge", "success")
        return redirect(f"/develop/universes/{UniverseObj.id}/badges")
    
@DevelopPagesRoute.route("/develop/universes/<int:universeid>/badges/<int:badgeid>", methods=["GET", "POST"])
@auth.authenticated_required
def ManageUniverseBadgePage( universeid : int, badgeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()

    BadgeObj : PlaceBadge = PlaceBadge.query.filter_by( universe_id = UniverseObj.id, id = badgeid ).first()
    if BadgeObj is None:
        abort(404)

    if request.method == "GET":
        return render_template("develop/universes/edit-badge.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, BadgeObj=BadgeObj)
    else:
        BadgeName = request.form.get("badge-name", default = "", type = str)
        BadgeDescription = request.form.get("badge-description", default = "", type = str)

        if BadgeName == "":
            flash("Badge name cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
        if len(BadgeName) > 35:
            flash("Badge name cannot be longer than 35 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
        if CountAlphanumericCharacters(BadgeName) < 3:
            flash("Badge name must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
        
        if BadgeDescription == "":
            flash("Badge description cannot be empty", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
        if len(BadgeDescription) > 128:
            flash("Badge description cannot be longer than 128 characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
        if CountAlphanumericCharacters(BadgeDescription) < 3:
            flash("Badge description must contain at least 3 alphanumeric characters", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")

        BadgeName = FilterText(BadgeName)
        BadgeDescription = FilterText(BadgeDescription)
        file = request.files.get("icon-file", default=None)

        if file is not None:
            if file.filename != "":
                if file.content_length > 1024 * 1024:
                    flash("File size is too big", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
                FileImage = ValidateClothingImage(file, verifyResolution=False, validateFileSize=False, returnImage=True)
                if FileImage is False or FileImage is None:
                    flash("Invalid image", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
                if FileImage.width != FileImage.height:
                    flash("Image is not square", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
                if FileImage.width < 128 or FileImage.width > 1024:
                    flash("Image is not between 128x128 and 1024x1024", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")
                file = BytesIO()
                FileImage.save(file, format="PNG")
                
                file.seek(0)
                FileImageHash = hashlib.sha512(file.read()).hexdigest()
                if not s3helper.DoesKeyExist(FileImageHash):
                    file.seek(0)
                    s3helper.UploadBytesToS3(file.read(), FileImageHash, contentType="image/png")

                NewImageAssetObj : Asset = Asset(
                    name = "BadgeImage",
                    description = "Badge icon",
                    creator_id = AuthenticatedUser.id,
                    creator_type = 0,
                    asset_type = AssetType.Image,
                    created_at = datetime.utcnow(),
                    updated_at = datetime.utcnow(),
                    moderation_status = 1
                )
                db.session.add(NewImageAssetObj)
                db.session.commit()

                NewImageAssetVersion : AssetVersion = CreateNewAssetVersion( NewImageAssetObj, FileImageHash, ForceNewVersion = True, UploadedBy = AuthenticatedUser)
                if NewImageAssetVersion is None:
                    db.session.delete(NewImageAssetObj)
                    db.session.commit()
                    flash("Failed to create a new asset version, please contact support", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")

                TakeThumbnail( AssetId = NewImageAssetObj.id, isIcon=False )
                BadgeObj.icon_image_id = NewImageAssetObj.id

                flash("Successfully updated developer product icon", "success")
        
        BadgeObj.name = BadgeName
        BadgeObj.description = BadgeDescription
        BadgeObj.updated_at = datetime.utcnow()

        db.session.commit()
        flash("Successfully updated badge", "success")

        return redirect(f"/develop/universes/{UniverseObj.id}/badges/{BadgeObj.id}")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/place/<int:placeid>/manage", methods=["GET", "POST"])
@auth.authenticated_required
def ManageUniversePlacePage( universeid : int, placeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    PlaceObj : Place = Place.query.filter_by(placeid = placeid, parent_universe_id = UniverseObj.id ).first()
    if PlaceObj is None:
        abort(404)
    PlaceAssetObj : Asset = Asset.query.filter_by(id = PlaceObj.placeid).first() if placeid != UniverseObj.root_place_id else RootPlaceAssetObj

    if request.method == "GET":
        return render_template("develop/games/manage.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, PlaceObj=PlaceObj, PlaceAssetObj=PlaceAssetObj)
    else:
        PlaceName : str = request.form.get("name", default="", type=str)
        PlaceDescription : str = request.form.get("description", default="", type=str)
        try:
            ChatStyleType : ChatStyle = ChatStyle(request.form.get("chat-style-type", default = 2, type = int))
        except ValueError:
            flash("Invalid chat style", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/manage")

        if UniverseObj.place_year in [ PlaceYear.Eighteen, PlaceYear.Twenty, PlaceYear.TwentyOne ]:
            try:
                AvatarRigType : PlaceRigChoice = PlaceRigChoice(request.form.get("avatar-rig-type", default=0, type=int))
            except ValueError:
                flash("Invalid avatar rig type", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/manage")

        if len(PlaceName) < 3 or len(PlaceName) > 50:
            flash("Place name has to be between 3 to 50 characters long", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/manage")
        if len(PlaceDescription) < 3 or len(PlaceDescription) > 700:
            flash("Place description has to be between 3 to 700 characters long", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/manage")
        if PlaceDescription.count("\n") > 10:
            flash("Place description can only have 10 or less newlines", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/manage")
        
        PlaceName : str = FilterText(PlaceName)
        PlaceDescription : str = FilterText(PlaceDescription)
        PlaceAssetObj.name = PlaceName
        PlaceAssetObj.description = PlaceDescription
        PlaceObj.chat_style = ChatStyleType
        if UniverseObj.place_year in [ PlaceYear.Eighteen, PlaceYear.Twenty, PlaceYear.TwentyOne ]:
            PlaceObj.rig_choice = AvatarRigType

        PlaceAssetObj.updated_at = datetime.utcnow()
        UniverseObj.updated_at = datetime.utcnow()

        db.session.commit()
        flash("Successfully updated place settings", "success")

        return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/manage")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/place/<int:placeid>/access", methods=["GET", "POST"])
@auth.authenticated_required
def ManageUniversePlaceAccessPage( universeid : int, placeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    PlaceObj : Place = Place.query.filter_by(placeid = placeid, parent_universe_id = UniverseObj.id ).first()
    if PlaceObj is None:
        abort(404)
    PlaceAssetObj : Asset = Asset.query.filter_by(id = PlaceObj.placeid).first() if placeid != UniverseObj.root_place_id else RootPlaceAssetObj

    if request.method == "GET":
        return render_template("develop/games/access.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, PlaceObj=PlaceObj, PlaceAssetObj=PlaceAssetObj)
    else:
        MaxPlayers : int = request.form.get("maxplayers", default=10, type=int)
        if MaxPlayers < 2 or MaxPlayers > 50:
            flash("Max players has to be between 2 to 50", "error")
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/access")
        PlaceObj.maxplayers = MaxPlayers
        db.session.commit()

        flash("Successfully updated place access settings", "success")
        return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/access")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/place/<int:placeid>/upload-version", methods=["GET", "POST"])
@auth.authenticated_required
def UploadUniversePlaceVersionPage( universeid : int, placeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    PlaceObj : Place = Place.query.filter_by(placeid = placeid, parent_universe_id = UniverseObj.id ).first()
    if PlaceObj is None:
        abort(404)
    PlaceAssetObj : Asset = Asset.query.filter_by(id = PlaceObj.placeid).first() if placeid != UniverseObj.root_place_id else RootPlaceAssetObj

    if request.method == "GET":
        return render_template("develop/games/upload-version.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, PlaceObj=PlaceObj, PlaceAssetObj=PlaceAssetObj)
    else:
        with limiter.limit("5/minute"):
            AssetFile = request.files.get("file", default = None)
            if AssetFile is None:
                flash("No file was provided", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/upload-version")
            CreateLockName = f"UploadAssetVersion:{str(PlaceAssetObj.id)}"
            CreateLock = redislock.acquire_lock(CreateLockName, acquire_timeout=20, lock_timeout=5)
            
            AssetFile.seek(0)
            AssetFileContent = AssetFile.read()
            AssetFileHash = hashlib.sha512(AssetFileContent).hexdigest()

            CurrentAssetVersion : AssetVersion = GetLatestAssetVersion( PlaceAssetObj )
            if CurrentAssetVersion is not None:
                if CurrentAssetVersion.content_hash == AssetFileHash:
                    redislock.release_lock(CreateLockName, CreateLock)
                    flash("File is the same as the current version", "error")
                    return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/upload-version")
                
            PlaceObj : Place = Place.query.filter_by(placeid=PlaceAssetObj.id).first()

            isValidPlaceFile = ValidatePlaceFile( AssetFile, keepFileWhenInvalid=False, TestPlaceYear = PlaceObj.placeyear ) # if it returns a bool its valid, if it returns a string its invalid and the string is the error
            if type(isValidPlaceFile) == str:
                redislock.release_lock(CreateLockName, CreateLock)
                flash(f"Validation Failed: {isValidPlaceFile}", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/upload-version")
            
            if not s3helper.DoesKeyExist(AssetFileHash):
                s3helper.UploadBytesToS3(AssetFileContent, AssetFileHash)
            
            NewAssetVersion : AssetVersion = CreateNewAssetVersion( PlaceAssetObj, AssetFileHash, ForceNewVersion = True, UploadedBy = AuthenticatedUser)
            if NewAssetVersion is None:
                redislock.release_lock(CreateLockName, CreateLock)
                flash("Failed to create a new asset version", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/upload-version")
            PlaceAssetObj.updated_at = datetime.utcnow()
            UniverseObj.updated_at = datetime.utcnow()
            db.session.commit()

            redislock.release_lock(CreateLockName, CreateLock)
            flash("Successfully updated place file", "success")
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/upload-version")
    
@DevelopPagesRoute.route("/develop/universes/<int:universeid>/place/<int:placeid>/placeicon", methods=["GET","POST"])
@auth.authenticated_required
def ManageUniversePlaceIconPage( universeid : int, placeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    PlaceObj : Place = Place.query.filter_by(placeid = placeid, parent_universe_id = UniverseObj.id ).first()
    if PlaceObj is None:
        abort(404)
    PlaceAssetObj : Asset = Asset.query.filter_by(id = PlaceObj.placeid).first() if placeid != UniverseObj.root_place_id else RootPlaceAssetObj

    if request.method == "GET":
        return render_template("develop/games/upload-icon.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, PlaceObj=PlaceObj, PlaceAssetObj=PlaceAssetObj, RandomNumber=random.randint(0, 10000000))
    else:
        with limiter.limit("5/minute"):
            useGenerated = request.form.get("usegenerated") == "on"
            if useGenerated:
                PlaceAssetObj.updated_at = datetime.utcnow()
                CurrentPlaceIcon : PlaceIcon = PlaceIcon.query.filter_by(placeid=PlaceAssetObj.id).first()
                if CurrentPlaceIcon is not None:
                    db.session.delete(CurrentPlaceIcon)
                db.session.commit()
                TakeThumbnail( AssetId=PlaceAssetObj.id, isIcon=True )
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/placeicon")
            
            AssetFile = request.files.get("file", default = None)
            if AssetFile is None:
                flash("No file was provided", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/placeicon")
            if AssetFile.content_length > 2097152:
                flash("File size is too big", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/placeicon")
            IconImage = ValidateClothingImage( AssetFile, verifyResolution=False, validateFileSize=False, returnImage=True )
            if IconImage is False or IconImage is None:
                flash("Invalid image", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/placeicon")
            if IconImage.width != IconImage.height:
                flash("Image is not square", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/placeicon")
            if IconImage.width < 256 or IconImage.width > 1024:
                flash("Image is not between 256x256 and 1024x1024", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/placeicon")
            
            AssetFile = BytesIO()
            IconImage.save(AssetFile, format="PNG")

            AssetFile.seek(0)
            IconImageHash = hashlib.sha512(AssetFile.read()).hexdigest()
            if not s3helper.DoesKeyExist(IconImageHash):
                AssetFile.seek(0)
                s3helper.UploadBytesToS3(AssetFile.read(), IconImageHash, contentType="image/png")
            
            CurrentPlaceIcon : PlaceIcon = PlaceIcon.query.filter_by(placeid=PlaceAssetObj.id).first()
            if CurrentPlaceIcon is None:
                CurrentPlaceIcon = PlaceIcon(placeid=PlaceAssetObj.id, contenthash=IconImageHash, updated_at=datetime.utcnow(), moderation_status=1)
                db.session.add(CurrentPlaceIcon)
            else:
                CurrentPlaceIcon.contenthash = IconImageHash
                CurrentPlaceIcon.updated_at = datetime.utcnow()
                CurrentPlaceIcon.moderation_status = 1
            PlaceAssetObj.updated_at = datetime.utcnow()
            UniverseObj.updated_at = datetime.utcnow()
            db.session.commit()

            flash("Successfully updated place icon", "success")
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/placeicon")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/place/<int:placeid>/thumbnails", methods=["GET","POST"])
@auth.authenticated_required
def ManageUniversePlaceThumbnailsPage( universeid : int, placeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    PlaceObj : Place = Place.query.filter_by(placeid = placeid, parent_universe_id = UniverseObj.id ).first()
    if PlaceObj is None:
        abort(404)
    PlaceAssetObj : Asset = Asset.query.filter_by(id = PlaceObj.placeid).first() if placeid != UniverseObj.root_place_id else RootPlaceAssetObj

    if request.method == "GET":
        return render_template("develop/games/upload-thumbnail.html", UniverseObj=UniverseObj, RootPlaceAssetObj=RootPlaceAssetObj, PlaceObj=PlaceObj, PlaceAssetObj=PlaceAssetObj, RandomNumber=random.randint(0, 10000000))
    else:
        with limiter.limit("5/minute"):
            useGenerated = request.form.get("usegenerated") == "on"
            if useGenerated:
                PlaceAssetObj.updated_at = datetime.utcnow()
                CurrentAssetThumbnail : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=PlaceAssetObj.id).order_by(AssetThumbnail.asset_version_id.desc()).first()
                if CurrentAssetThumbnail is not None:
                    db.session.delete(CurrentAssetThumbnail)
                db.session.commit()
                TakeThumbnail( AssetId=PlaceAssetObj.id, isIcon=False )
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")
            
            AssetFile = request.files.get("file", default = None)
            if AssetFile is None:
                flash("No file was provided", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")
            
            if AssetFile.content_length > 2097152:
                flash("File size is too big", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")
            ThumbnailImage = ValidateClothingImage( AssetFile, verifyResolution=False, validateFileSize=False, returnImage=True )
            if ThumbnailImage is False or ThumbnailImage is None:
                flash("Invalid image", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")
            
            if ThumbnailImage.width / ThumbnailImage.height != 16 / 9:
                flash("Image is not 16:9 aspect ratio", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")
            
            if ThumbnailImage.width < 640 or ThumbnailImage.width > 1920:
                flash("Image is not between 640x360 and 1920x1080", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")
            if ThumbnailImage.height < 360 or ThumbnailImage.height > 1080:
                flash("Image is not between 640x360 and 1920x1080", "error")
                return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")
            
            AssetFile = BytesIO()
            ThumbnailImage.save(AssetFile, format="PNG")

            AssetFile.seek(0)
            ThumbnailImageHash = hashlib.sha512(AssetFile.read()).hexdigest()
            if not s3helper.DoesKeyExist(ThumbnailImageHash):
                AssetFile.seek(0)
                s3helper.UploadBytesToS3(AssetFile.read(), ThumbnailImageHash, contentType="image/png")
            
            CurrentAssetThumbnail : AssetThumbnail = AssetThumbnail.query.filter_by(asset_id=PlaceAssetObj.id).order_by(AssetThumbnail.asset_version_id.desc()).first()
            LatestAssetVersion : AssetVersion = GetLatestAssetVersion(PlaceAssetObj)
            if LatestAssetVersion is None:
                flash("No asset version found", "error")
                return redirect(f"/develop/{str(PlaceAssetObj.id)}/thumbnails")
            if CurrentAssetThumbnail is None:
                CurrentAssetThumbnail = AssetThumbnail(asset_id=PlaceAssetObj.id, asset_version_id=LatestAssetVersion.version, content_hash=ThumbnailImageHash, created_at=datetime.utcnow(), moderation_status=1)
                db.session.add(CurrentAssetThumbnail)
            else:
                CurrentAssetThumbnail.content_hash = ThumbnailImageHash
                CurrentAssetThumbnail.created_at = datetime.utcnow()
                CurrentAssetThumbnail.moderation_status = 1
                CurrentAssetThumbnail.asset_version_id = LatestAssetVersion.version
            PlaceAssetObj.updated_at = datetime.utcnow()
            UniverseObj.updated_at = datetime.utcnow()
            db.session.commit()
            return redirect(f"/develop/universes/{UniverseObj.id}/place/{PlaceObj.placeid}/thumbnails")

@DevelopPagesRoute.route("/develop/universes/<int:universeid>/place/<int:placeid>/version-history", methods=["GET"])
@auth.authenticated_required
def ManageUniversePlaceVersionHistoryPage( universeid : int, placeid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    UniverseObj : Universe = Universe.query.filter_by(id=universeid).first()
    isUserAllowedtoViewPage(AuthenticatedUser, UniverseObj, abortOnFail=True)
    RootPlaceAssetObj : Asset = Asset.query.filter_by(id = UniverseObj.root_place_id).first()
    PlaceObj : Place = Place.query.filter_by(placeid = placeid, parent_universe_id = UniverseObj.id ).first()
    if PlaceObj is None:
        abort(404)
    PlaceAssetObj : Asset = Asset.query.filter_by(id = PlaceObj.placeid).first() if placeid != UniverseObj.root_place_id else RootPlaceAssetObj

    PageNumber : int = max( 1, request.args.get("page", default = 1, type = int) )
    AssetVersions : list[AssetVersion] = AssetVersion.query.filter_by(asset_id=PlaceAssetObj.id).order_by(AssetVersion.version.desc()).paginate( page = PageNumber, per_page = 10, error_out = False )
    return render_template(
        "/develop/games/version-history.html",
        UniverseObj = UniverseObj,
        PlaceAssetObj = PlaceAssetObj,
        AssetVersions = AssetVersions,
        CDN_URL = config.CDN_URL
    )

@DevelopPagesRoute.route("/develop/<int:assetid>/edit", methods=["GET"])
@auth.authenticated_required
def EditItemPage( assetid : int ):
    AuthenticatedUser = auth.GetCurrentUser()
    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        abort(404)
    if AssetObj.asset_type not in [AssetType.Shirt, AssetType.TShirt, AssetType.Pants, AssetType.Audio, AssetType.Image]:
        abort(404)
    isUserAllowedtoViewPage(AuthenticatedUser, AssetObj, abortOnFail=True, isGameContext=False)
    return render_template("develop/edit.html", AssetObj=AssetObj)

@DevelopPagesRoute.route("/develop/<int:assetid>/edit", methods=["POST"])
@auth.authenticated_required
@limiter.limit("5/minute")
def EditItem( assetid : int ):
    AuthenticatedUser = auth.GetCurrentUser()
    AssetObj : Asset = Asset.query.filter_by(id=assetid).first()
    if AssetObj is None:
        abort(404)
    if AssetObj.asset_type not in [AssetType.Shirt, AssetType.TShirt, AssetType.Pants, AssetType.Audio, AssetType.Image]:
        abort(404)
    isUserAllowedtoViewPage(AuthenticatedUser, AssetObj, abortOnFail=True, isGameContext=False)

    if not websiteFeatures.GetWebsiteFeature("AssetEditing"):
        flash("Asset editing is currently disabled", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")

    AssetName = request.form.get("item-name", default = "", type = str)
    AssetDescription = request.form.get("item-description", default = "", type = str)
    isForSale = request.form.get("is-for-sale", default = "off") == "on"
    AssetRobuxPrice = request.form.get("robux-cost", default = 0, type = int)
    AssetTixPrice = request.form.get("tix-cost", default = 0, type = int)

    if AssetName == "":
        flash("Item name cannot be empty", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    if len(AssetName) > 35:
        flash("Item name cannot be longer than 35 characters", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    if len(AssetDescription) > 200:
        flash("Item description cannot be longer than 200 characters", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    if AssetRobuxPrice < 0 or AssetRobuxPrice > 1000000:
        flash("Robux price must be between 0 and 1,000,000", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    if AssetTixPrice < 0 or AssetTixPrice > 10000000:
        flash("Tix price must be between 0 and 10,000,000", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    if isForSale and AssetObj.moderation_status != 0:
        flash("You cannot sell an item that is not approved yet", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    if isForSale and (AssetObj.asset_type == AssetType.Audio or AssetObj.asset_type == AssetType.Image):
        flash("You cannot sell this type of asset", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    
    UserCurrentMembership : MembershipType = GetUserMembership(AuthenticatedUser)
    if UserCurrentMembership == MembershipType.NonBuildersClub and isForSale:
        flash("You must be Builders Club to sell items", "error")
        return redirect(f"/develop/{str(AssetObj.id)}/edit")
    
    AssetName = FilterText(AssetName)
    AssetDescription = FilterText(AssetDescription)

    AssetObj.name = AssetName
    AssetObj.description = AssetDescription
    AssetObj.is_for_sale = isForSale
    AssetObj.price_robux = AssetRobuxPrice
    AssetObj.price_tix = AssetTixPrice
    AssetObj.updated_at = datetime.utcnow()
    db.session.commit()
    return redirect(f"/develop/{str(AssetObj.id)}/edit")

def ShutdownServer(JobId):
    from app.routes.jobreporthandler import HandleUserTimePlayed
    from app.services.gameserver_comm import perform_post
    TargetPlaceServer : PlaceServer | None = PlaceServer.query.filter_by(serveruuid=JobId).first()
    if TargetPlaceServer is None:
        return
    MasterServer : GameServer | None = GameServer.query.filter_by(serverId=TargetPlaceServer.originServerId).first()
    if MasterServer is None:
        return
    PlaceObj : Place = Place.query.filter_by(placeid=TargetPlaceServer.serverPlaceId).first()
    UniverseObj : Universe = Universe.query.filter_by(id=PlaceObj.parent_universe_id).first()
    logging.info(f"CloseJob : ShutdownServer func : Closing job {str(JobId)} for place {str(PlaceObj.placeid)}")
    try:
        CloseJobRequest = perform_post(
            TargetGameserver = MasterServer,
            Endpoint = "CloseJob",
            JSONData = {
                "jobid": str(JobId)
            }
        )
        PlaceServerPlayersList : list[PlaceServerPlayer] = PlaceServerPlayer.query.filter_by(serveruuid=JobId).all()
        for player in PlaceServerPlayersList:
            TotalTimePlayed = (datetime.utcnow() - player.joinTime).total_seconds()
            HandleUserTimePlayed(player.user, TotalTimePlayed, serverUUID=str(JobId), placeId=PlaceObj.placeid)
            db.session.delete(player)
        db.session.delete(TargetPlaceServer)
        db.session.commit()

        ClearPlayingCountCache( PlaceObj = PlaceObj )
        ClearUniversePlayingCountCache( UniverseObj = UniverseObj )
    except Exception as e:
        logging.error(f"CloseJob : ShutdownServer func : Failed to close job {str(JobId)} for place {str(PlaceObj.placeid)} : {str(e)}")

    return
