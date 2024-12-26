import EventTypes "../heartbeat/event_types";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import _Time "mo:base/Time";
import Iter "mo:base/Iter";

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

        // Utility function to log all subscribed event types (for debugging)
        public query func listSubscribedEventTypes(): async [EventTypes.EventType] {
            Iter.toArray(listeners.keys());
        };
    };
};