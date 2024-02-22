from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, after_this_request
from app.util import auth, friends, websiteFeatures, transactions, redislock
import logging
from app.services import economy
from app.extensions import db, limiter, csrf, redis_controller, user_limiter
from app.models.asset import Asset
from app.models.user import User
from app.models.userassets import UserAsset
from app.models.package_asset import PackageAsset
from app.models.place_developer_product import DeveloperProduct
from app.models.product_receipt import ProductReceipt
from app.models.groups import Group
from app.enums.AssetType import AssetType
from app.enums.TransactionType import TransactionType
from app.pages.catalog.catalog import IncrementAssetCreator, CreateTransactionForSale
import math

MarketPlaceRoute = Blueprint("marketplace", __name__, url_prefix="/marketplace")
EconomyV1Route = Blueprint("economyv1", __name__, url_prefix="/")

@MarketPlaceRoute.route("/game-pass-product-info", methods=["GET"])
@MarketPlaceRoute.route("/productinfo", methods=["GET"])
def productinfo():
    assetid = request.args.get("assetId") or request.args.get("gamePassId")
    if assetid is None:
        return "Invalid request",400
    asset : Asset = Asset.query.filter_by(id=assetid).first()
    if asset is None:
        return "Asset not found",404
    AssetCreator : User | Group = User.query.filter_by(id=asset.creator_id).first() if asset.creator_type == 0 else Group.query.filter_by(id=asset.creator_id).first()
    if AssetCreator is None:
        AssetCreatorName = "Unknown"
    else:
        AssetCreatorName = AssetCreator.username if isinstance(AssetCreator, User) else AssetCreator.name
    return jsonify({
        "Name": asset.name,
        "Description": asset.description,
        "Created": asset.created_at,
        "Updated": asset.updated_at,
        "PriceInRobux": asset.price_robux,
        "PriceInTickets": asset.price_tix,
        "AssetId": asset.id,
        "ProductId": asset.id,
        "AssetTypeId": asset.asset_type.value,
        "Creator": {
            "Id": asset.creator_id,
            "Name": AssetCreatorName,
            "CreatorType": asset.creator_type
        },
        "MinimumMembershipLevel": 0,
        "IsForSale": asset.is_for_sale
    })

@MarketPlaceRoute.route("/productDetails", methods=["GET"])
def productDetails():
    productId = request.args.get( key = "productId", default = None, type = int )
    if productId is None:
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400
    TargetDeveloperProduct : DeveloperProduct = DeveloperProduct.query.filter_by( productid = productId ).first()
    if TargetDeveloperProduct is None:
        return jsonify({
            "success": False,
            "message": "Invalid request"
        }), 400
    
    return jsonify({
        "TargetId" : 1,
        "ProductType": "Developer Product",
        "AssetId": 0,
        "ProductId": TargetDeveloperProduct.productid,
        "Name": TargetDeveloperProduct.name,
        "Description": TargetDeveloperProduct.description,
        "AssetTypeId": 0,
        "Creator": {
            "Id": 0,
            "Name": None,
            "CreatorType": None,
            "CreatorTargetId": 0
        },
        "IconImageAssetId": TargetDeveloperProduct.iconimage_assetid,
        "Created": TargetDeveloperProduct.created_at.strftime('%Y-%m-%dT%H:%M:%S.%fZ'),
        "Updated": TargetDeveloperProduct.updated_at.strftime('%Y-%m-%dT%H:%M:%S.%fZ'),
        "PriceInRobux": TargetDeveloperProduct.robux_price,
        "PremiumPriceInRobux": 0,
        "PriceInTickets": 0,
        "IsNew": False,
        "IsForSale": TargetDeveloperProduct.is_for_sale,
        "IsPublicDomain": False,
        "IsLimited": False,
        "IsLimitedUnique": False,
        "Remaining": None,
        "Sales": None,
        "MinimumMembershipLevel": 0
    })

@MarketPlaceRoute.route("/purchase", methods=["POST"])
@csrf.exempt
@auth.authenticated_required_api
@limiter.limit("20/minute")
@limiter.limit("1/second")
@user_limiter.limit("20/minute")
@user_limiter.limit("1/second")
def inGamePurchaseHandler():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    
    productId = request.form.get("productId", None, int)
    currencyTypeId = request.form.get("currencyTypeId", None, int)
    expectedPrice = request.form.get("purchasePrice", None, int)

    if not websiteFeatures.GetWebsiteFeature("EconomyPurchase"):
        return jsonify({"success": False, "status": "EconomyDisabled"}),400
    if productId is None or currencyTypeId is None or expectedPrice is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    currencyType = 0 if currencyTypeId == 1 else 1
    AssetObj : Asset = Asset.query.filter_by(id=productId).first()
    if AssetObj is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    if AssetObj.is_limited or not AssetObj.is_for_sale:
        return jsonify({"success": False, "status": "NotForSale"}),400
    
    LockAssetName = f"asset:{str(AssetObj.id)}"
    AssetLock = redislock.acquire_lock(LockAssetName, acquire_timeout=15, lock_timeout=1)
    if AssetLock is False:
        return jsonify({"success": False, "status": "InternalServerError"}),500
    
    @after_this_request
    def release_asset_lock(response):
        if AssetLock:
            redislock.release_lock(LockAssetName, AssetLock)

    UserRobuxBalance, UserTixBalance = economy.GetUserBalance(AuthenticatedUser)
    if currencyType == 0:
        if AssetObj.price_robux == 0 and AssetObj.price_tix != 0:
            return jsonify({"success": False, "status": "CurrencyNotAccepted"}),400
        if AssetObj.price_robux != expectedPrice:
            return jsonify({"success": False, "status": "PriceChanged"}),400
        if UserRobuxBalance < expectedPrice:
            return jsonify({"success": False, "status": "InsufficientFunds"}),400
    else:
        if AssetObj.price_tix == 0 and AssetObj.price_robux != 0:
            return jsonify({"success": False, "status": "CurrencyNotAccepted"}),400
        if AssetObj.price_tix != expectedPrice:
            return jsonify({"success": False, "status": "PriceChanged"}),400
        if UserTixBalance < expectedPrice:
            return jsonify({"success": False, "status": "InsufficientFunds"}),400
        
    UserAssetObj : UserAsset = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=productId).first()
    if UserAssetObj is not None:
        return jsonify({"success": False, "status": "AlreadyOwned"}),400
    try:
        economy.DecrementTargetBalance(AuthenticatedUser, expectedPrice, currencyType)
    except economy.InsufficientFundsException:
        return jsonify({"success": False, "status": "InsufficientFunds"}),400
    UserAssetObj = UserAsset(
        userid = AuthenticatedUser.id,
        assetid = productId
    )

    if AssetObj.asset_type == AssetType.Package:
        PackageAssets = PackageAsset.query.filter_by(package_asset_id=AssetObj.id).all()
        for PackageAssetObj in PackageAssets:
            NewPackageAssetObj = UserAsset(userid=AuthenticatedUser.id, assetid=PackageAssetObj.asset_id)
            db.session.add(NewPackageAssetObj)
    
    IncrementAssetCreator(AssetObj, expectedPrice, currencyType)

    AssetObj.sale_count += 1
    db.session.add(UserAssetObj)
    db.session.commit()

    try:
        if AssetObj.creator_type == 0:
            SellerUserObj : User = User.query.filter_by(id=AssetObj.creator_id).first()
            CreateTransactionForSale(
                AssetObj = AssetObj,
                PurchasePrice = expectedPrice,
                PurchaseCurrencyType = currencyType,
                Seller = SellerUserObj,
                Buyer = AuthenticatedUser,
                ApplyTaxAutomatically = True
            )
        elif AssetObj.creator_type == 1:
            SellerGroupObj : Group = Group.query.filter_by(id=AssetObj.creator_id).first()
            CreateTransactionForSale(
                AssetObj = AssetObj,
                PurchasePrice = expectedPrice,
                PurchaseCurrencyType = currencyType,
                Seller = SellerGroupObj,
                Buyer = AuthenticatedUser,
                ApplyTaxAutomatically = True
            )
    except Exception as e:
        logging.warn(f"Failed to create transaction log for sale of asset {str(AssetObj.id)}, message: {str(e)}")
        pass

    return jsonify({"success": True}),200

@EconomyV1Route.route("/v1/purchases/products/<int:assetid>", methods=["POST"])
@csrf.exempt
@auth.authenticated_required_api
@user_limiter.limit("30/minute")
@user_limiter.limit("1/second")
def SubmitItemPurchaseEconomy( assetid : int ):
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"purchased": False, "reason": "Unauthorized"}),401
    
    if "expectedPrice" not in request.json or "expectedCurrency" not in request.json:
        return jsonify({"purchased": False, "reason": "Invalid request", "errorMsg": "Invalid Request"}),400

    productId = assetid
    currencyTypeId = request.json["expectedCurrency"]
    expectedPrice = request.json["expectedPrice"]

    if not websiteFeatures.GetWebsiteFeature("EconomyPurchase"):
        return jsonify({"purchased": False, "reason": "EconomyDisabled", "errorMsg": "Purchasing is temporarily disabled, try again later."}),400
    if productId is None or currencyTypeId is None or expectedPrice is None:
        return jsonify({"purchased": False, "reason": "Invalid request", "errorMsg": "Invalid Request"}),400
    currencyType = 0 if currencyTypeId == 1 else 1
    AssetObj : Asset = Asset.query.filter_by(id=productId).first()
    if AssetObj is None:
        return jsonify({"purchased": False, "reason": "Invalid request", "errorMsg": "Invalid Request"}),400
    if AssetObj.is_limited or not AssetObj.is_for_sale:
        return jsonify({"purchased": False, "reason": "NotForSale", "errorMsg": "This item is not for sale"}),400
    
    LockAssetName = f"asset:{str(AssetObj.id)}"
    AssetLock = redislock.acquire_lock(LockAssetName, acquire_timeout=15, lock_timeout=1)
    if AssetLock is False:
        return jsonify({"success": False, "status": "InternalServerError"}),500
    
    @after_this_request
    def release_asset_lock(response):
        if AssetLock:
            redislock.release_lock(LockAssetName, AssetLock)

    UserRobuxBalance, UserTixBalance = economy.GetUserBalance(AuthenticatedUser)
    if currencyType == 0:
        if AssetObj.price_robux == 0 and AssetObj.price_tix != 0:
            return jsonify({"purchased": False, "reason": "CurrencyNotAccepted", "errorMsg": "This currency is not accepted for this item"}),400
        if AssetObj.price_robux != expectedPrice:
            return jsonify({"purchased": False, "reason": "PriceChanged", "errorMsg": "The price has changed"}),400
        if UserRobuxBalance < expectedPrice:
            return jsonify({"purchased": False, "reason": "InsufficientFunds", "errorMsg": "You do not have enough Robux to purchase this item."}),400
    else:
        if AssetObj.price_tix == 0 and AssetObj.price_robux != 0:
            return jsonify({"purchased": False, "reason": "CurrencyNotAccepted", "errorMsg": "This currency is not accepted for this item"}),400
        if AssetObj.price_tix != expectedPrice:
            return jsonify({"purchased": False, "reason": "PriceChanged", "errorMsg": "The price has changed"}),400
        if UserTixBalance < expectedPrice:
            return jsonify({"purchased": False, "reason": "InsufficientFunds", "errorMsg": "You do not have enough Robux to purchase this item."}),400
    # Check if the user already owns the asset
    UserAssetObj : UserAsset = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=productId).first()
    if UserAssetObj is not None:
        return jsonify({"purchased": False, "reason": "AlreadyOwned", "errorMsg": "You already own this item."}),400
    try:
        economy.DecrementTargetBalance(AuthenticatedUser, expectedPrice, currencyType)
    except economy.InsufficientFundsException:
        return jsonify({"purchased": False, "reason": "InsufficientFunds", "errorMsg": "You do not have enough Robux to purchase this item."}),400
    UserAssetObj = UserAsset(
        userid = AuthenticatedUser.id,
        assetid = productId
    )

    if AssetObj.asset_type == AssetType.Package:
        PackageAssets = PackageAsset.query.filter_by(package_asset_id=AssetObj.id).all()
        for PackageAssetObj in PackageAssets:
            NewPackageAssetObj = UserAsset(userid=AuthenticatedUser.id, assetid=PackageAssetObj.asset_id)
            db.session.add(NewPackageAssetObj)
    
    IncrementAssetCreator(AssetObj, expectedPrice, currencyType)

    AssetObj.sale_count += 1
    db.session.add(UserAssetObj)
    db.session.commit()

    try:
        if AssetObj.creator_type == 0:
            SellerUserObj : User = User.query.filter_by(id=AssetObj.creator_id).first()
            CreateTransactionForSale(
                AssetObj = AssetObj,
                PurchasePrice = expectedPrice,
                PurchaseCurrencyType = currencyType,
                Seller = SellerUserObj,
                Buyer = AuthenticatedUser,
                ApplyTaxAutomatically = True
            )
        elif AssetObj.creator_type == 1:
            SellerGroupObj : Group = Group.query.filter_by(id=AssetObj.creator_id).first()
            CreateTransactionForSale(
                AssetObj = AssetObj,
                PurchasePrice = expectedPrice,
                PurchaseCurrencyType = currencyType,
                Seller = SellerGroupObj,
                Buyer = AuthenticatedUser,
                ApplyTaxAutomatically = True
            )
    except Exception as e:
        logging.warn(f"Failed to create transaction log for sale of asset {str(AssetObj.id)}, message: {str(e)}")
        pass

    if AssetObj.creator_type == 0:
        CreatorObj : User = User.query.filter_by(id = AssetObj.creator_id).first()
        sellerName = CreatorObj.username
    else:
        CreatorObj : Group = Group.query.filter_by(id = AssetObj.creator_id).first()
        sellerName = CreatorObj.name

    return jsonify({
        "purchased": True,
        "reason": "Success",
        "productId": assetid,
        "currency": currencyTypeId,
        "assetId": assetid,
        "assetName": AssetObj.name,
        "assetType": AssetObj.asset_type.name,
        "assetTypeDisplayName": AssetObj.asset_type.name,
        "assetIsWearable": False,
        "sellerName": sellerName,
        "transactionVerb": "bought",
        "isMultiPrivateSale": False
    })

@MarketPlaceRoute.route("/submitpurchase", methods=["POST"])
@csrf.exempt
@auth.authenticated_required_api
@user_limiter.limit("20/minute")
@user_limiter.limit("1/second")
def SubmitProductPurchase():
    productId : int = request.form.get( key = "productId", default = None, type = int )
    currencyTypeId : int = request.form.get( key = "currencyTypeId", default = None, type = int )
    expectedUnitPrice : int = request.form.get( key = "expectedUnitPrice", default = None, type = int )
    placeId : int = request.form.get( key = "placeId", default = None, type = int )
    requestId : str = request.form.get( key = "requestId", default = None, type = str )

    if not websiteFeatures.GetWebsiteFeature("EconomyPurchase"):
        return jsonify({"success": False, "status": "EconomyDisabled"}),400
    if productId is None or currencyTypeId is None or expectedUnitPrice is None or placeId is None or requestId is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    currencyType = 0 if currencyTypeId == 1 else 1
    TargetDeveloperProduct : DeveloperProduct = DeveloperProduct.query.filter_by( productid = productId, placeid = placeId ).first()
    if TargetDeveloperProduct is None:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    PlaceAssetObj : Asset = Asset.query.filter_by( id = TargetDeveloperProduct.placeid ).first()

    if TargetDeveloperProduct.is_for_sale == False:
        return jsonify({"success": False, "message": "Invalid request"}),400
    if TargetDeveloperProduct.robux_price != expectedUnitPrice:
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    if redis_controller.exists(f"purchase_request:{requestId}"):
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    if currencyType != 0: # Developer Products can only be purchased with Robux
        return jsonify({"success": False, "message": "Invalid request"}),400
    
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    UserRobuxBalance, _ = economy.GetUserBalance(AuthenticatedUser)
    if UserRobuxBalance < expectedUnitPrice:
        return jsonify({"success": False, "status": "InsufficientFunds"}),400
    
    try:
        economy.DecrementTargetBalance(AuthenticatedUser, expectedUnitPrice, currencyType)
    except economy.InsufficientFundsException:
        return jsonify({"success": False, "status": "InsufficientFunds"}),400
    OwnerObj : User | Group = User.query.filter_by( id = PlaceAssetObj.creator_id ).first() if PlaceAssetObj.creator_type == 0 else Group.query.filter_by( id = PlaceAssetObj.creator_id ).first()

    transactions.CreateTransaction(
        Reciever = OwnerObj,
        Sender = AuthenticatedUser,
        CurrencyAmount = expectedUnitPrice,
        CurrencyType = currencyType,
        TransactionType = TransactionType.Purchase,
        CustomText = f"Purchase of Product({TargetDeveloperProduct.name}) from {PlaceAssetObj.name}"
    )
    GrossProfitAfterTax = math.floor(expectedUnitPrice * 0.7)

    economy.IncrementTargetBalance(OwnerObj, GrossProfitAfterTax, currencyType)
    transactions.CreateTransaction(
        Reciever = OwnerObj,
        Sender = AuthenticatedUser,
        CurrencyAmount = GrossProfitAfterTax,
        CurrencyType = currencyType,
        TransactionType = TransactionType.Sale,
        CustomText = f"Sale of Product({TargetDeveloperProduct.name}) from {PlaceAssetObj.name}"
    )
    redis_controller.set(f"purchase_request:{requestId}", "1", ex = 60 * 10)

    DeveloperProductReceiptObj : ProductReceipt = ProductReceipt(
        user_id = AuthenticatedUser.id,
        product_id = TargetDeveloperProduct.productid,
        robux_amount = expectedUnitPrice
    )
    TargetDeveloperProduct.sales_count += 1
    db.session.add(DeveloperProductReceiptObj)
    db.session.commit()

    return jsonify({
        "success": True,
        "receipt": DeveloperProductReceiptObj.receipt_id
    }),200