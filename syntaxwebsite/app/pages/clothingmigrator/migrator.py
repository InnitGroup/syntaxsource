from flask import Blueprint, render_template, request, redirect, url_for, flash
from app.extensions import db, redis_controller, limiter
from app.util import auth, turnstile, websiteFeatures
from app.models.asset import Asset
from app.models.asset_version import AssetVersion
from app.routes.asset import migrateAsset
from datetime import datetime
import re

ClothingMigratorRoute = Blueprint('clothingmigrator', __name__, template_folder='pages')

@ClothingMigratorRoute.route('/clothing-migrator', methods=['GET'])
@auth.authenticated_required
def clothing_migrator():
    return render_template('clothingmigrator/index.html')

@ClothingMigratorRoute.route('/clothing-migrator', methods=['POST'])
@auth.authenticated_required
@limiter.limit("1/second")
def clothing_migrator_post():
    if not websiteFeatures.GetWebsiteFeature("ClothingMigrator"):
        flash("Clothing migration is temporarily disabled", "error")
        return redirect("/clothing-migrator")

    if "asseturl" not in request.form or "cf-turnstile-response" not in request.form:
        flash("Please fill in all the fields", "error")
        return redirect("/clothing-migrator")
    AssetRegex = re.compile(r".com\/catalog\/(\d+)\/")
    AssetMatch = AssetRegex.search(request.form.get("asseturl"))
    if AssetMatch is None:
        flash("Invalid asset URL", "error")
        return redirect("/clothing-migrator")
    AssetID = AssetMatch.group(1)
    if not turnstile.VerifyToken(request.form.get("cf-turnstile-response")):
        flash("Invalid captcha", "error")
        return redirect("/clothing-migrator")
    AssetObject : Asset = Asset.query.filter_by(roblox_asset_id=AssetID).first()
    if AssetObject is not None:
        return redirect(f"/catalog/{AssetID}/")
    AuthenticatedUser = auth.GetCurrentUser()
    DayOfYear = datetime.utcnow().timetuple().tm_yday
    RedisResult = redis_controller.get(f"clothingmigrator:{str(AuthenticatedUser.id)}:{str(DayOfYear)}")
    if RedisResult is None:
        redis_controller.setex(f"clothingmigrator:{str(AuthenticatedUser.id)}:{str(DayOfYear)}", 86400, "1")
    else:
        Count = int(RedisResult)
        if Count >= 5:
            flash("You have reached the daily limit of 5 per day, please try again tommorow.", "error")
            return redirect("/clothing-migrator")
        redis_controller.setex(f"clothingmigrator:{str(AuthenticatedUser.id)}:{str(DayOfYear)}", 86400, str(Count + 1))
    MigratedAsset : Asset = migrateAsset(AssetID, forceMigration=False, allowedTypes=[2, 11, 12], creatorId=2, keepRobloxId=False, migrateInfo=True)
    if MigratedAsset is None:
        flash("Unable to migrate asset", "error")
        return redirect("/clothing-migrator")
    if MigratedAsset.creator_id == 2 and MigratedAsset.creator_type == 0:
        if (datetime.utcnow() - MigratedAsset.created_at).total_seconds() < 2:
            MigratedAsset.is_for_sale = True
            MigratedAsset.price_robux = 5
            MigratedAsset.description = f"This item was taken from the Roblox Catalog using the Clothing Migrator. This item was requested by {AuthenticatedUser.username} ({AuthenticatedUser.id})."
            db.session.commit()
    return redirect(f"/catalog/{str(MigratedAsset.id)}/")
