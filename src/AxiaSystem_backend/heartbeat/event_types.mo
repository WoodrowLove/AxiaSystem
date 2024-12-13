import Hash "mo:base/Hash";
import Nat "mo:base/Nat";

module {
    public type EventType = {
        #PaymentProcessed;
        #PaymentReversed;
        #WalletUpdated;
        #PaymentHistoryRetrieved;
        #AllPaymentsRetrieved;
        #PaymentTimedOut;
        #BalancesSynchronized;
    };

    public type Event = {
        id: Nat;
        eventType: EventType;
        payload: EventPayload;
    };

    public type EventPayload = {
        #PaymentProcessed : { userId: Principal; amount: Nat; walletId: Text };
        #PaymentReversed : { userId: Principal; amount: Nat; walletId: Text };
        #WalletUpdated : { walletId: Text; balance: Nat };
        #PaymentHistoryRetrieved : { userId: Principal; transactionCount: Nat };
        #AllPaymentsRetrieved : { totalTransactions: Nat };
        #PaymentTimedOut : { userId: Principal; amount: Nat; walletId: Text };
        #BalancesSynchronized : { senderId: Principal; receiverId: Principal; amount: Nat; tokenId: Nat };
    };

    public func equal(x: EventType, y: EventType): Bool {
        x == y
    };

    public func hash(x: EventType): Hash.Hash {
        switch(x) {
            case (#PaymentProcessed) { 0 };
            case (#PaymentReversed) { 1 };
            case (#WalletUpdated) { 2 };
            case (#PaymentHistoryRetrieved) { 3 };
            case (#AllPaymentsRetrieved) { 4 };
            case (#PaymentTimedOut) { 5 };
            case (#BalancesSynchronized) { 6 };
        }
    };
}