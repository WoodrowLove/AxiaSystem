import EventTypes "../heartbeat/event_types";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Int "mo:base/Int";

module {
    public class EventManager() {
        // HashMap to store event listeners
        private let listeners = HashMap.HashMap<EventTypes.EventType, [EventTypes.Event -> async ()]>(10, EventTypes.equal, EventTypes.hash);

        // Queue for event emission (optional for decoupled execution)
        private var eventQueue: [EventTypes.Event] = [];

        // Subscribe to a specific event type
        public func subscribe(eventType: EventTypes.EventType, listener: EventTypes.Event -> async ()) : async () {
            let currentListeners = switch (listeners.get(eventType)) {
                case null { [] };
                case (?arr) { arr };
            };
            listeners.put(eventType, Array.append(currentListeners, [listener]));
        };

        // Emit an event immediately to all registered listeners
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
    timestamp: ?Nat64
) : async () {
    let event: EventTypes.Event = {
        id = Nat64.fromNat(Int.abs(Time.now()));
        eventType = eventType;
        payload = switch (eventType) {
            case (#WalletUpdated) {
                #WalletUpdated({
                    walletId = Principal.toText(walletId);
                    balance = 0; // Replace with actual balance
                })
            };
            case (#WalletDeleted) {
                #WalletDeleted({
                    walletId = Principal.toText(walletId);
                    ownerId = walletId;
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

        public func emitWalletCreated(userId: Principal, details: Text) : async () {
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

        public func emitWalletUpdated(userId: Principal, details: Text) : async () {
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

        public func emitWalletDeleted(userId: Principal, details: Text) : async () {
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
        public query func listSubscribedEventTypes(): async [EventTypes.EventType] {
            Iter.toArray(listeners.keys());
        };
    };
};