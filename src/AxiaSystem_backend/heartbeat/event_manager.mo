import EventTypes "../heartbeat/event_types";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import _Int "mo:base/Int";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";

module {
    public class EventManager() {
        // HashMap to store event listeners
        private let listeners = HashMap.HashMap<EventTypes.EventType, [shared EventTypes.Event -> async ()]>(10, EventTypes.equal, EventTypes.hash);

        // Queue for event emission (optional for decoupled execution)
        private var eventQueue: [EventTypes.Event] = [];

       public func subscribe(eventType: EventTypes.EventType, listener: shared EventTypes.Event -> async ()) : async () {
    let currentListeners = switch (listeners.get(eventType)) {
        case null { [] };
        case (?arr) { arr };
    };
    listeners.put(eventType, Array.append(currentListeners, [listener]));
};

        public func emit(eventType: EventTypes.Event) : async () {
    let registeredListeners = switch (listeners.get(eventType.eventType)) {
        case null { [] };
        case (?arr) { arr };
    };
    for (listener in registeredListeners.vals()) {
        await listener(eventType);
    };
};

        // Enqueue an event for later processing
        public func enqueueEvent(event: EventTypes.Event) : async () {
            eventQueue := Array.append(eventQueue, [event]);
        };

        // Process all enqueued events (can be invoked periodically via heartbeat)
        public func processQueuedEvents() : async () {
            let queueCopy = eventQueue;
            eventQueue := []; // Clear the queue before processing
            for (event in queueCopy.vals()) {
                await emit(event);
            };
        };

// Emit wallet-related events
public func emitWalletEvent(
    walletId: Principal,
    eventType: EventTypes.EventType,
    details: Text,
    balance: Nat
) : async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now()); // Correct timestamp conversion
        eventType = eventType;
        payload = switch (eventType) {
            case (#WalletUpdated) {
                #WalletUpdated({
                    walletId = Principal.toText(walletId);
                    balance = balance; // Actual balance passed
                })
            };
            case (#WalletDeleted) {
                #WalletDeleted({
                    walletId = Principal.toText(walletId);
                    ownerId = walletId; // Ensure ownerId is set properly
                })
            };
            case (_) {
                #WalletEventGeneric({
                    walletId = Principal.toText(walletId);
                    details = details;
                })
            };
        };
    };
    await emit(event);
};

        public func emitWalletCreated(userId: Principal, _details: Text) : async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now()); // Convert Time to Nat64
        eventType = #WalletCreated;
        payload = #WalletCreated({
            walletId = Principal.toText(userId);
            ownerId = userId; // Add ownerId field
            initialBalance = 0; // Replace with the actual initial balance
        });
    };
    await emit(event);
};

        public func emitWalletUpdated(userId: Principal, _details: Text) : async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now()); // Convert Time to Nat64
        eventType = #WalletUpdated;
        payload = #WalletUpdated({
            walletId = Principal.toText(userId);
            balance = 0; // Replace with the actual wallet balance
        });
    };
    await emit(event);
};

        public func emitWalletDeleted(userId: Principal, _details: Text) : async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now()); // Convert Time to Nat64
        eventType = #WalletDeleted;
        payload = #WalletDeleted({
            walletId = Principal.toText(userId);
            ownerId = userId; // Add ownerId field
        });
    };
    await emit(event);
};

        // Utility function to log all subscribed event types (for debugging)
        public func listSubscribedEventTypes(): async [EventTypes.EventType] {
            Iter.toArray(listeners.keys());
        };

        // Emit event for subscription creation
public func emitSubscriptionCreated(userId: Principal, subscriptionId: Nat): async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = #SubscriptionCreated;
        payload = #SubscriptionCreated({
            userId = Principal.toText(userId);
            subscriptionId = Nat.toText(subscriptionId);
        });
    };
    await emit(event);
};

// Emit event for subscription removal
public func emitSubscriptionRemoved(subscriptionId: Nat): async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = #SubscriptionRemoved;
        payload = #SubscriptionRemoved({
            subscriptionId = Nat.toText(subscriptionId);
        });
    };
    await emit(event);
};


// Emit event for payment status retrieval
public func emitPaymentStatusRetrieved(paymentId: Nat, status: Text): async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = #PaymentStatusRetrieved;
        payload = #PaymentStatusRetrieved({
            paymentId = Nat.toText(paymentId);
            status = status;
        });
    };
    await emit(event);
};

// Emit event for payment updates
public func emitPaymentUpdated(userId: Principal, paymentId: Nat, status: Text): async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = #PaymentUpdated;
        payload = #PaymentUpdated({
            userId = Principal.toText(userId);
            paymentId = Nat.toText(paymentId);
            status = status;
        });
    };
    await emit(event);
};

// Emit payment-related events
public func emitPaymentEvent(
    eventType: EventTypes.EventType,
    payload: EventTypes.EventPayload
): async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = eventType;
        payload = payload;
    };
    await emit(event);
};

// Emit event when funds are deposited
    public func emitFundsDeposited(userId: Principal, amount: Nat, tokenId: ?Nat): async () {
        let event: EventTypes.Event = {
            id = Nat64.fromIntWrap(Time.now());
            eventType = #FundsDeposited;
            payload = #FundsDeposited({
                userId = Principal.toText(userId);
                amount = amount;
                tokenId = tokenId;
                timestamp = Nat64.fromIntWrap(Time.now());
            });
        };
        await emit(event);
    };

    // Emit event when funds are withdrawn
    public func emitFundsWithdrawn(userId: Principal, amount: Nat, tokenId: ?Nat): async () {
        let event: EventTypes.Event = {
            id = Nat64.fromIntWrap(Time.now());
            eventType = #FundsWithdrawn;
            payload = #FundsWithdrawn({
                userId = Principal.toText(userId);
                amount = amount;
                tokenId = tokenId;
                timestamp = Nat64.fromIntWrap(Time.now());
            });
        };
        await emit(event);
    };

    // Emit event when rewards are distributed
    public func emitRewardsDistributed(
    recipients: [(Principal, Nat)],
    tokenId: ?Nat,
    totalAmount: Nat
): async () {
    let event: EventTypes.Event = {
        id = Nat64.fromIntWrap(Time.now());
        eventType = #RewardsDistributed;
        payload = #RewardsDistributed({
            recipients = Array.map<(Principal, Nat), (Text, Nat)>(
                recipients, 
                func ((recipient: Principal, amount: Nat)): (Text, Nat) {
                    (Principal.toText(recipient), amount)
                }
            );
            tokenId = tokenId;
            totalAmount = totalAmount;
            timestamp = Nat64.fromIntWrap(Time.now());
        });
    };
    await emit(event);
};

    // Emit event when treasury balance is checked
    public func emitTreasuryBalanceChecked(tokenId: ?Nat, balance: Nat): async () {
        let event: EventTypes.Event = {
            id = Nat64.fromIntWrap(Time.now());
            eventType = #TreasuryBalanceChecked;
            payload = #TreasuryBalanceChecked({
                tokenId = tokenId;
                balance = balance;
                timestamp = Nat64.fromIntWrap(Time.now());
            });
        };
        await emit(event);
    };

    // Emit event when a treasury transaction is logged
    public func emitTreasuryTransactionLogged(
        transactionId: Nat,
        description: Text,
        transactionType: Text
    ): async () {
        let event: EventTypes.Event = {
            id = Nat64.fromIntWrap(Time.now());
            eventType = #TreasuryTransactionLogged;
            payload = #TreasuryTransactionLogged({
                transactionId = transactionId;
                description = description;
                transactionType = transactionType;
                timestamp = Nat64.fromIntWrap(Time.now());
            });
        };
        await emit(event);
    };
    public func processQueuedEventsSync() : async () {
    for (event in eventQueue.vals()) {
        // Construct a string representation of the event
        let eventText = "Event ID: " # Nat64.toText(event.id) # 
                        ", Type: " # debug_show(event.eventType) # 
                        ", Payload: " # debug_show(event.payload);
        
        Debug.print("Processing event: " # eventText);
    };
    eventQueue := []; // Clear the queue
};

public func emitUserCreated(userId: Principal, username: Text, email: Text): async Result.Result<(), Text> {
    try {
        await emit({
            id = Nat64.fromIntWrap(Time.now());
            eventType = #UserCreated;
            payload = #UserCreated({
                UserId = Principal.toText(userId);
                username = username;
                email = email;
            });
        });
        return #ok(());
    } catch (e) {
        return #err("Failed to emit event: " # Error.message(e));
    }
};

public func emitUserUpdated(userId: Principal, username: ?Text, email: ?Text): async Result.Result<(), Text> {
    try {
        await emit({
            id = Nat64.fromIntWrap(Time.now());
            eventType = #UserUpdated;
            payload = #UserUpdated({
                UserId = Principal.toText(userId);
                username = username;
                email = email;
            });
        });
        return #ok(());
    } catch (e) {
        return #err("Failed to emit UserUpdated event: " # Error.message(e));
    }
};

// Emit a UserDeactivated event
public func emitUserDeactivated(userId: Principal): async Result.Result<(), Text> {
    try {
        await emit({
            id = Nat64.fromIntWrap(Time.now());
            eventType = #UserDeactivated;
            payload = #UserDeactivated({
                UserId = Principal.toText(userId);
            });
        });
        return #ok(());
    } catch (e) {
        return #err("Failed to emit UserDeactivated event: " # Error.message(e));
    }
};

// Emit a UserDeleted event
public func emitUserDeleted(userId: Principal): async Result.Result<(), Text> {
    try {
        await emit({
            id = Nat64.fromIntWrap(Time.now());
            eventType = #UserDeleted;
            payload = #UserDeleted({
                UserId = Principal.toText(userId);
            });
        });
        return #ok(());
    } catch (e) {
        return #err("Failed to emit UserDeleted event: " # Error.message(e));
    }
};

// Emit an event to log all users (Optional for debugging purposes)
public func emitListAllUsers(totalUsers: Nat): async Result.Result<(), Text> {
    try {
        await emit({
            id = Nat64.fromIntWrap(Time.now());
            eventType = #ListAllUsers;
            payload = #ListAllUsers({
                TotalUsers = totalUsers;
            });
        });
        return #ok(());
    } catch (e) {
        return #err("Failed to emit ListAllUsers event: " # Error.message(e));
    }
};

// Emit a PasswordReset event
public func emitPasswordReset(userId: Principal): async Result.Result<(), Text> {
    try {
        await emit({
            id = Nat64.fromIntWrap(Time.now());
            eventType = #PasswordReset;
            payload = #PasswordReset({
                UserId = Principal.toText(userId);
            });
        });
        return #ok(());
    } catch (e) {
        return #err("Failed to emit PasswordReset event: " # Error.message(e));
    }
};

};

    };
