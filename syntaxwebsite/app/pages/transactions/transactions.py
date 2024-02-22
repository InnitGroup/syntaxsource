from flask import Blueprint, render_template, request, redirect, url_for, session, flash, redirect, make_response, abort
from datetime import datetime, timedelta

from app.models.user_transactions import UserTransaction
from app.util import auth
from app.extensions import db
from app.models.user import User
from app.models.groups import Group
from app.models.asset import Asset
from app.enums.TransactionType import TransactionType

TransactionsRoute = Blueprint('transactions', __name__, url_prefix='/transactions')

CategoryToEnum = {
    "purchase": TransactionType.Purchase,
    "sale": TransactionType.Sale,
    "group-payout": TransactionType.GroupPayout,
    "stipends": TransactionType.BuildersClubStipend,
}

@TransactionsRoute.route("/", methods=["GET"])
@auth.authenticated_required
def TransactionsPage():
    AuthenticatedUser : User = auth.GetCurrentUser()

    CategoryArg = request.args.get('category', default="purchase", type=str)
    if CategoryArg not in CategoryToEnum:
        Category : TransactionType = TransactionType.Purchase
    else:
        Category : TransactionType = CategoryToEnum[CategoryArg]
        
    PageNumber = request.args.get('page', default=1, type=int)
    if PageNumber < 1:
        PageNumber = 1

    TransactionQuery = UserTransaction.query.filter_by( transaction_type = Category)
    CategoryQueryDict = {
        TransactionType.Purchase: lambda queryObj: queryObj.filter_by(
            sender_id = AuthenticatedUser.id,
            sender_type = 0
        ),
        TransactionType.Sale: lambda queryObj: queryObj.filter_by(
            reciever_id = AuthenticatedUser.id,
            reciever_type = 0
        ),
        TransactionType.GroupPayout: lambda queryObj: queryObj.filter_by(
            reciever_id = AuthenticatedUser.id,
            reciever_type = 0
        ),
        TransactionType.BuildersClubStipend: lambda queryObj: queryObj.filter_by(
            reciever_id = AuthenticatedUser.id,
            reciever_type = 0
        ),
    }
    TransactionQuery = CategoryQueryDict[Category](TransactionQuery)
    TransactionQuery = TransactionQuery.order_by(UserTransaction.created_at.desc())
    TransactionQuery = TransactionQuery.paginate( page=PageNumber, per_page=15, error_out=False )

    FormattedTransactions = []
    for Transaction in TransactionQuery.items:
        Transaction : UserTransaction = Transaction
        TransactionInfo = {}
        TransactionInfo["source"] = {
            "id": Transaction.sender_id if Transaction.sender_id != AuthenticatedUser.id or Transaction.sender_type != 0 else Transaction.reciever_id,
            "type": Transaction.sender_type if Transaction.sender_id != AuthenticatedUser.id or Transaction.sender_type != 0 else Transaction.reciever_type, # VV I know this is bad but im too lazy to think of another way to do it
            "name": ( User.query.filter_by(id = Transaction.sender_id).first().username if Transaction.sender_type != 1 else Group.query.filter_by( id = Transaction.sender_id ).first().name ) if Transaction.sender_id != AuthenticatedUser.id or Transaction.sender_type != 0 else ( User.query.filter_by(id = Transaction.reciever_id).first().username if Transaction.reciever_type != 1 else Group.query.filter_by( id = Transaction.reciever_id ).first().name ),
        }
        TransactionInfo["currency_amount"] = Transaction.currency_amount
        TransactionInfo["currency_type"] = Transaction.currency_type
        TransactionInfo["created_at"] = Transaction.created_at.strftime("%d/%m/%Y %H:%M:%S UTC")
        TransactionInfo["custom_text"] = Transaction.custom_text
        if Transaction.assetId:
            TransactionInfo["asset"] = {
                "id": Transaction.assetId,
                "name": Asset.query.filter_by(id = Transaction.assetId).first().name,
            }
        else:
            TransactionInfo["asset"] = None
        FormattedTransactions.append(TransactionInfo)

    return render_template(
        "transactions/transactions.html",
        PageCategory = CategoryArg,
        TransactionInfo = FormattedTransactions,
        Pagination = TransactionQuery
    )