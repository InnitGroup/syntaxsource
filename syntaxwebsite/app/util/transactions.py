from app.extensions import db
from app.models.user_transactions import UserTransaction
from app.models.user import User
from app.models.groups import Group
from app.models.asset import Asset
from app.enums.TransactionType import TransactionType
import math

def CreateTransaction(
    Reciever : User | Group = None,
    Sender : User | Group = None,
    CurrencyAmount : int = 0,
    CurrencyType : int = 0, # 0 = Robux, 1 = Tix
    TransactionType : TransactionType = TransactionType.Purchase,
    AssetId : int = None,
    CustomText : str = None

) -> UserTransaction | None:
    """
        Creates a transaction between two users or group.
    
        Reciever: Defaults to UserId 1 (Roblox),
        Sender: Defaults to UserId 1 (Roblox)

        Note: If Reciever and Sender are both None an exception will be raised.
    """

    if Reciever is None and Sender is None:
        raise Exception("Reciever and Sender cannot both be None.")
    
    if Reciever is None:
        Reciever = User.query.filter_by(id=1).first()
    if Sender is None:
        Sender = User.query.filter_by(id=1).first()
    
    NewTransaction : UserTransaction = UserTransaction(
        reciever_id = Reciever.id,
        reciever_type = 0 if isinstance(Reciever, User) else 1,
        sender_id = Sender.id,
        sender_type = 0 if isinstance(Sender, User) else 1,

        currency_amount = CurrencyAmount,
        currency_type = CurrencyType,
        transaction_type = TransactionType,
        custom_text = CustomText,

        asset_id = AssetId
    )
    db.session.add(NewTransaction)
    db.session.commit()

    return NewTransaction

def CreateTransactionForSale(
    AssetObj : Asset,
    PurchasePrice : int,
    PurchaseCurrencyType : int, # 0 = Robux, 1 = Tix,
    Seller : User | Group,
    Buyer : User | Group,
    ApplyTaxAutomatically : bool = True
) -> tuple[UserTransaction, UserTransaction] | None:
    """
        Creates a transaction for a sale.
    """

    if ApplyTaxAutomatically:
        PurchaseProfit : int = math.floor(PurchasePrice * 0.7) # 70% of the purchase price goes to the seller
    else:
        PurchaseProfit : int = PurchasePrice
    
    SellerTransaction : UserTransaction = CreateTransaction(
        Reciever = Seller,
        Sender = Buyer,
        CurrencyAmount = PurchaseProfit,
        CurrencyType = PurchaseCurrencyType,
        TransactionType = TransactionType.Sale,
        AssetId = AssetObj.id
    )
    BuyerTransaction : UserTransaction = CreateTransaction(
        Reciever = Seller,
        Sender = Buyer,
        CurrencyAmount = PurchasePrice,
        CurrencyType = PurchaseCurrencyType,
        TransactionType = TransactionType.Purchase,
        AssetId = AssetObj.id
    )
    return (SellerTransaction, BuyerTransaction)