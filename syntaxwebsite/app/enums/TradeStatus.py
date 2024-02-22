from enum import Enum

class TradeStatus( Enum ):
    Pending = 0
    Accepted = 1
    Declined = 2
    Expired = 3
    Cancelled = 4