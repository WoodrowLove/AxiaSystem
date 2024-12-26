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
        #TokenCreated;
        #TokenMetadataUpdated;
        #TokenDeactivated;
        #TokenReactivated;
        #TokensLocked;
        #TokensUnlocked;
        #TokensBurned;
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
        #TokenCreated : { tokenId: Nat; name: Text; symbol: Text; owner: Principal };
        #TokenMetadataUpdated : { tokenId: Nat; name: Text; symbol: Text; owner: Principal };
        #TokenDeactivated : { tokenId: Nat; owner: Principal };
        #TokenReactivated : { tokenId: Nat; owner: Principal };
        #TokensLocked : { tokenId: Nat; amount: Nat; owner: Principal};
        #TokensUnlocked : { tokenId: Nat; amount: Nat; owner: Principal };
        #TokensBurned : { tokenId: Nat; amount: Nat };



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
            case (#TokenCreated) { 7 };
            case (#TokenMetadataUpdated) { 8 };
            case (#TokenDeactivated) { 9 };
            case (#TokenReactivated) { 10 };
            case (#TokensLocked) { 11 };
            case (#TokensUnlocked) { 12 };
            case (#TokensBurned) { 13 }; 
        }
    };
}