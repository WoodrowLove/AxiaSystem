import Hash "mo:base/Hash";
import Nat "mo:base/Nat";

module {
    public type EventType = {
        #PaymentProcessed;
        #PaymentReversed;
        #WalletUpdated;
        // Add more types as needed
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
    };

    public func equal(x: EventType, y: EventType): Bool {
        x == y
    };

    public func hash(x: EventType): Hash.Hash {
        switch(x) {
            case (#PaymentProcessed) { 0 };
            case (#PaymentReversed) { 1 };
            case (#WalletUpdated) { 2 };
            // Add more cases as needed
        }
    };
}