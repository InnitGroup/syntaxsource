from flask import Blueprint, render_template, request, redirect, url_for, flash
from app.models.giftcard_key import GiftcardKey
from app.enums.GiftcardType import GiftcardType
from app.extensions import db, redis_controller, limiter
from app.util import auth, websiteFeatures, turnstile, redislock, membership
from datetime import datetime, timedelta
from app.models.user import User
from app.enums.MembershipType import MembershipType
from app.services import economy

GiftcardRedeemRoute = Blueprint('giftcardredeem', __name__, template_folder='pages')

@GiftcardRedeemRoute.errorhandler(429)
def ratelimit_handler(e):
    flash("Please slow down", "error")
    return redirect("/giftcard-redeem")

@GiftcardRedeemRoute.route('/giftcard-redeem', methods=['GET'])
@auth.authenticated_required
def giftcard_redeem():
    return render_template('giftcardredeem/index.html')

@GiftcardRedeemRoute.route('/giftcard-redeem', methods=['POST'])
@auth.authenticated_required
@limiter.limit("10/minute")
def giftcard_post():
    if not websiteFeatures.GetWebsiteFeature("GiftcardRedeem"):
        flash("Redeeming giftcards is temporarily disabled", "error")
        return redirect("/giftcard-redeem")
    GiftcardInput = request.form.get( key="giftcard-key", default=None, type=str)
    CFTurnstileResponse = request.form.get( key="cf-turnstile-response", default=None, type=str)
    if GiftcardInput is None or CFTurnstileResponse is None:
        flash("Please fill in all the fields", "error")
        return redirect("/giftcard-redeem")
    if not turnstile.VerifyToken(CFTurnstileResponse):
        flash("Invalid captcha", "error")
        return redirect("/giftcard-redeem")
    
    RedeemLock = redislock.acquire_lock( f"Giftcard_Redeem:{GiftcardInput}", acquire_timeout=20, lock_timeout=1)

    GiftcardKeyObject : GiftcardKey = GiftcardKey.query.filter_by(key=GiftcardInput).first()
    if GiftcardKeyObject is None:
        flash("Invalid giftcard key", "error")
        return redirect("/giftcard-redeem")
    if GiftcardKeyObject.redeemed_by is not None:
        flash("This giftcard has already been redeemed", "error")
        return redirect("/giftcard-redeem")
    AuthenticatedUser : User = auth.GetCurrentUser()
    
    if GiftcardKeyObject.type == GiftcardType.Outrageous_BuildersClub:
        UserCurrentMembership : MembershipType = membership.GetUserMembership(AuthenticatedUser)
        if UserCurrentMembership == MembershipType.OutrageousBuildersClub:
            membership.IncrementExpirationLength(
                AuthenticatedUser,
                timedelta(days=(31 * GiftcardKeyObject.value))
            )
            flash(f"Your OBC membership has been extended by {GiftcardKeyObject.value} months", "success")
        else:
            membership.GiveUserMembership(
                TargetUser = AuthenticatedUser,
                Membership = MembershipType.OutrageousBuildersClub,
                expiration = timedelta(days=(31 * GiftcardKeyObject.value))
            )
            flash(f"You have been given OBC membership for {GiftcardKeyObject.value} months", "success")
        GiftcardKeyObject.redeemed_by = AuthenticatedUser.id
        GiftcardKeyObject.redeemed_at = datetime.utcnow()
        db.session.commit()
        redislock.release_lock(f"Giftcard_Redeem:{GiftcardInput}", RedeemLock)
        return redirect("/giftcard-redeem")
    elif GiftcardKeyObject.type == GiftcardType.Turbo_BuildersClub:
        UserCurrentMembership : MembershipType = membership.GetUserMembership(AuthenticatedUser)
        if UserCurrentMembership == MembershipType.OutrageousBuildersClub:
            flash("You cannot downgrade your membership", "error")
            return redirect("/giftcard-redeem")
        elif UserCurrentMembership == MembershipType.TurboBuildersClub:
            membership.IncrementExpirationLength(
                AuthenticatedUser,
                timedelta(days=(7 * GiftcardKeyObject.value))
            )
            flash(f"Your TBC membership has been extended by {GiftcardKeyObject.value} weeks", "success")
        else:
            membership.GiveUserMembership(
                TargetUser = AuthenticatedUser,
                Membership = MembershipType.TurboBuildersClub,
                expiration = timedelta(days=(7 * GiftcardKeyObject.value))
            )
            flash(f"You have been given TBC membership for {GiftcardKeyObject.value} weeks", "success")
        GiftcardKeyObject.redeemed_by = AuthenticatedUser.id
        GiftcardKeyObject.redeemed_at = datetime.utcnow()
        db.session.commit()
        redislock.release_lock(f"Giftcard_Redeem:{GiftcardInput}", RedeemLock)
        return redirect("/giftcard-redeem")
    elif GiftcardKeyObject.type == GiftcardType.RobuxCurrency:
        economy.IncrementTargetBalance(AuthenticatedUser, GiftcardKeyObject.value, 0)
        flash(f"You have been given {GiftcardKeyObject.value} robux", "success")
        GiftcardKeyObject.redeemed_by = AuthenticatedUser.id
        GiftcardKeyObject.redeemed_at = datetime.utcnow()
        db.session.commit()
        redislock.release_lock(f"Giftcard_Redeem:{GiftcardInput}", RedeemLock)
        return redirect("/giftcard-redeem")
    elif GiftcardKeyObject.type == GiftcardType.TixCurrency:
        economy.IncrementTargetBalance(AuthenticatedUser, GiftcardKeyObject.value, 1)
        flash(f"You have been given {GiftcardKeyObject.value} tickets", "success")
        GiftcardKeyObject.redeemed_by = AuthenticatedUser.id
        GiftcardKeyObject.redeemed_at = datetime.utcnow()
        db.session.commit()
        redislock.release_lock(f"Giftcard_Redeem:{GiftcardInput}", RedeemLock)
        return redirect("/giftcard-redeem")
    elif GiftcardKeyObject.type == GiftcardType.Item:
        from app.models.userassets import UserAsset
        from app.models.asset import Asset

        AssetObject : Asset = Asset.query.filter_by(id=GiftcardKeyObject.value).first()
        if AssetObject is None:
            flash("An issue occured when redeeming this giftcard, please contact support", "error")
            return redirect("/giftcard-redeem")
        if AssetObject.is_limited:
            flash("An issue occured when redeeming this giftcard, please contact support", "error")
            return redirect("/giftcard-redeem")
        UserAssetObject : UserAsset = UserAsset.query.filter_by(userid=AuthenticatedUser.id, assetid=AssetObject.id).first()
        if UserAssetObject is not None:
            flash("You already own this item", "error")
            return redirect("/giftcard-redeem")
        UserAssetObject : UserAsset = UserAsset(
            userid = AuthenticatedUser.id,
            assetid = AssetObject.id
        )
        db.session.add(UserAssetObject)
        db.session.commit()
        flash(f"You have been given the item {AssetObject.name}", "success")
        GiftcardKeyObject.redeemed_by = AuthenticatedUser.id
        GiftcardKeyObject.redeemed_at = datetime.utcnow()
        db.session.commit()
        redislock.release_lock(f"Giftcard_Redeem:{GiftcardInput}", RedeemLock)
        return redirect("/giftcard-redeem")
    else:
        flash("An issue occured when redeeming this giftcard, please contact support", "error")
        return redirect("/giftcard-redeem")
        