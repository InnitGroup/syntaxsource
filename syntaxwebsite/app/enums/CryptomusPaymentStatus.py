from enum import Enum

class CryptomusPaymentStatus(Enum):
    Paid = 0
    PaidOver = 1
    WrongAmount = 2
    Process = 3
    ConfirmCheck = 4
    WrongAmountWaiting = 5
    Check = 6
    Fail = 7
    Cancel = 8
    SystemFail = 9
    RefundProcess = 10
    RefundFail = 11
    RefundPaid = 12
    Locked = 13