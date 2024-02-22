from flask import Blueprint, render_template, request, redirect, url_for, jsonify, make_response, flash
from app.models.user import User
from app.models.invite_key import InviteKey
from app.util import auth, transactions
from app.services import invitekeys, economy
from app.extensions import db, limiter, csrf
from datetime import datetime, timedelta

inviteKeyRoute = Blueprint("invitekey", __name__, url_prefix="/")

@inviteKeyRoute.route("/invite-keys", methods=["GET"])
@auth.authenticated_required
def inviteKeysPage():
    AuthenticatedUser : User = auth.GetCurrentUser()
    pageNumber = request.args.get("page", 1, int)
    if pageNumber < 1:
        pageNumber = 1
    createdKeys = InviteKey.query.filter_by(created_by=AuthenticatedUser.id).order_by(InviteKey.created_at.desc()).paginate( page = pageNumber, per_page = 10, error_out=False )
    
    return render_template("invitekeys/index.html", createdKeys=createdKeys)

@inviteKeyRoute.route("/invite-keys/create", methods=["POST"])
@auth.authenticated_required
@csrf.exempt
def createInviteKey():
    AuthenticatedUser : User = auth.GetCurrentUser()
    if AuthenticatedUser is None:
        return jsonify({"success": False, "message": "Unauthorized"}),401
    
    robuxBalance, _ = economy.GetUserBalance(AuthenticatedUser)
    if robuxBalance < 20:
        flash("You do not have enough robux to create an invite key.", "error")
        return redirect("/invite-keys")
    
    activeKeys = InviteKey.query.filter_by(created_by=AuthenticatedUser.id, used_by=None).count()
    if activeKeys >= 3 and AuthenticatedUser.id != 1:
        flash("You have reached the maximum amount of active invite keys, please wait until one of your invite keys are used.", "error")
        return redirect("/invite-keys")
    
    keysCreatedPast24Hours = InviteKey.query.filter(InviteKey.created_at > datetime.utcnow() - timedelta(hours=24)).filter_by(created_by=AuthenticatedUser.id).count()
    if keysCreatedPast24Hours >= 3 and AuthenticatedUser.id != 1:
        flash("You have reached the maximum amount of invite keys you can create in 24 hours.", "error")
        return redirect("/invite-keys")
    
    if AuthenticatedUser.created > datetime.utcnow() - timedelta(days=3):
        flash("Your account must be more than 3 days old to create a invite key.", "error")
        return redirect("/invite-keys")

    try:
        economy.DecrementTargetBalance(AuthenticatedUser, 20, 0)
    except economy.InsufficientFundsException:
        flash("You do not have enough robux to create an invite key.", "error")
        return redirect("/invite-keys")
    except economy.EconomyLockAcquireException:
        flash("There was an error creating your invite key, please try again later.", "error")
        return redirect("/invite-keys")
    
    newInviteKey : InviteKey = invitekeys.CreateInviteKey(AuthenticatedUser)
    transactions.CreateTransaction(
        Reciever = User.query.filter_by(id=1).first(),
        Sender = AuthenticatedUser,
        CurrencyAmount = 20,
        CurrencyType = 0,
        CustomText = "Created Invite Key"
    )
    
    flash("Invite key created successfully.", "success")
    return redirect("/invite-keys")
