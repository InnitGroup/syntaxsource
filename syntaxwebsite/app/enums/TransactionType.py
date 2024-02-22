from enum import Enum

class TransactionType( Enum ):
    Purchase = 0
    Sale = 1
    GroupPayout = 2
    BuildersClubStipend = 3
    Commisions = 4
    Trade = 5