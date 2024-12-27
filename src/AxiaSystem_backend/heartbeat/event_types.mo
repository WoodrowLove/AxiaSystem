import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";

module {
    public type EventType = {
        #PaymentProcessed;
        #PaymentReversed;
        #WalletCreated;
        #WalletUpdated;
        #WalletDeleted;
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
        #WalletEventGeneric; // Added this new variant
    };

    public type Event = {
        id: Nat64; // Changed from Nat to Nat64
        eventType: EventType;
        payload: EventPayload;
    };

    public type EventPayload = {
        #PaymentProcessed : { userId: Principal; amount: Nat; walletId: Text };
        #PaymentReversed : { userId: Principal; amount: Nat; walletId: Text };
        #WalletCreated : { walletId: Text; ownerId: Principal; initialBalance: Nat };
        #WalletUpdated : { walletId: Text; balance: Nat };
        #WalletDeleted : { walletId: Text; ownerId: Principal };
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
        #WalletEventGeneric : { walletId: Text; details: Text }; // Added this new variant
    };

    public func equal(x: EventType, y: EventType): Bool {
        x == y
    };

    public func hash(x: EventType): Hash.Hash {
        switch(x) {
            case (#PaymentProcessed) { 0 };
            case (#PaymentReversed) { 1 };
            case (#WalletCreated) { 2 };
            case (#WalletUpdated) { 3 };
            case (#WalletDeleted) { 4 };
            case (#PaymentHistoryRetrieved) { 5 };
            case (#AllPaymentsRetrieved) { 6 };
            case (#PaymentTimedOut) { 7 };
            case (#BalancesSynchronized) { 8 };
            case (#TokenCreated) { 9 };
            case (#TokenMetadataUpdated) { 10 };
            case (#TokenDeactivated) { 11 };
            case (#TokenReactivated) { 12 };
            case (#TokensLocked) { 13 };
            case (#TokensUnlocked) { 14 };
            case (#TokensBurned) { 15 }; 
            case (#WalletEventGeneric) { 16 }; // Added this new case
        }
    };
}