from flask import Blueprint, render_template, request, redirect, url_for, flash
from app.routes.asset import GetOriginalAssetInfo, AddAudioAssetToAudioMigrationQueue
from app.models.asset import Asset
from app.models.user import User
from app.services import economy
from app.util import auth, websiteFeatures, turnstile, transactions
from app.extensions import db, redis_controller
from app.enums.TransactionType import TransactionType

AudioMigratorRoute = Blueprint('assetmigrator', __name__, template_folder='pages')

@AudioMigratorRoute.route('/audiomigrator', methods=['GET'])
@auth.authenticated_required
def audiomigrator():
    return render_template('audiomigrator/index.html')

@AudioMigratorRoute.route('/audiomigrator', methods=['POST'])
@auth.authenticated_required
def audiomigrator_post():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if not websiteFeatures.GetWebsiteFeature("AudioMigrator"):
        flash("Audio migration is temporarily disabled", "error")
        return redirect("/audiomigrator")
    
    CFTurnstileResponse = request.form.get( key="cf-turnstile-response", default=None, type=str)
    if CFTurnstileResponse is None:
        flash("Invalid captcha", "error")
        return redirect("/audiomigrator")
    if not turnstile.VerifyToken(CFTurnstileResponse):
        flash("Invalid captcha", "error")
        return redirect("/audiomigrator")

    PlaceId = request.form.get( key = "placeid", default = None, type = int )
    if PlaceId is None:
        flash("Invalid place ID", "error")
        return redirect("/audiomigrator")
    RequestedAudioIds = request.form.get( key = "audio-ids", default = None, type = str )
    if RequestedAudioIds is None:
        flash("Invalid audio IDs", "error")
        return redirect("/audiomigrator")
    
    RequestedAudioIds = RequestedAudioIds.split("\n")
    for i in range(len(RequestedAudioIds)):
        RequestedAudioIds[i] = RequestedAudioIds[i].strip()
        if RequestedAudioIds[i].isdigit():
            RequestedAudioIds[i] = int(RequestedAudioIds[i])
        else:
            RequestedAudioIds.remove(RequestedAudioIds[i])
    
    if len(RequestedAudioIds) > 100:
        flash("You can only migrate 100 audios at a time", "error")
        return redirect("/audiomigrator")
    if len(RequestedAudioIds) < 1:
        flash("You must migrate at least 1 audio", "error")
        return redirect("/audiomigrator")
    
    if PlaceId < 1:
        flash("Invalid place ID", "error")
        return redirect("/audiomigrator")

    RobuxBalance, _ = economy.GetUserBalance(AuthenticatedUser)
    RequiredAmountRobux = 0
    AudioIdsToMigrate : list[int] = []
    for RequestedAudio in RequestedAudioIds:
        if Asset.query.filter_by(id = RequestedAudio ).first():
            continue
        if redis_controller.lrange("migrate_audio_assets_queue", 0, -1).count(str(RequestedAudio)) > 0:
            continue
        if RequestedAudio in AudioIdsToMigrate:
            continue
        AudioIdsToMigrate.append(RequestedAudio)
        RequiredAmountRobux += 5

    if len(AudioIdsToMigrate) == 0:
        flash(f"Queued 0 / {len(RequestedAudioIds)} audios to be migrated", "success")
        return redirect("/audiomigrator")

    if RobuxBalance < RequiredAmountRobux:
        flash(f"You don't have enough robux to migrate these audios, Required R${RequiredAmountRobux}", "error")
        return redirect("/audiomigrator")
    
    try:
        economy.DecrementTargetBalance( AuthenticatedUser, Amount = RequiredAmountRobux, CurrencyType = 0 )
    except economy.InsufficientFundsException:
        flash(f"You don't have enough robux to migrate these audios, Required R${RequiredAmountRobux}", "error")
        return redirect("/audiomigrator")
    except Exception as e:
        flash(f"An error occured while deducting robux", "error")
        return redirect("/audiomigrator")
    
    transactions.CreateTransaction(
        Reciever = User.query.filter_by(id = 1).first(),
        Sender = AuthenticatedUser,
        CurrencyAmount = RequiredAmountRobux,
        CurrencyType = 0,
        TransactionType = TransactionType.Purchase,
        CustomText = f"Audio migration"
    )

    for AudioId in AudioIdsToMigrate:
        AddAudioAssetToAudioMigrationQueue(AudioId, bypassQueueLimit = True ,placeId=PlaceId)

    flash(f"Queued {len(AudioIdsToMigrate)} / {len(RequestedAudioIds)} audios to be migrated", "success")
    return redirect("/audiomigrator")