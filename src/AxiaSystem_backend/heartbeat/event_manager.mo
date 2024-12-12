import EventTypes "../heartbeat/event_types";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import _Hash "mo:base/Hash";
import _Nat "mo:base/Nat";

module {
    public class EventManager() {
        private let listeners = HashMap.HashMap<EventTypes.EventType, [EventTypes.Event -> async ()]>(10, EventTypes.equal, EventTypes.hash);

        public func subscribe(eventType: EventTypes.EventType, listener: EventTypes.Event -> async ()) : async () {
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
    };
};