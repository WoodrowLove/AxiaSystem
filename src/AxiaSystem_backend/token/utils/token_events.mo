import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import LoggingUtils "..../../../../utils/logging_utils";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";

module {
    public type EventType = {
        #Creation;
        #Transfer;
        #Minting;
        #Burning;
        #MetadataUpdate;
        #Locking;
        #Unlocking;
        #Deactivation;
        #Reactivation;
    };

    public type Event = {
        id: Nat;
        timestamp: Nat;
        tokenId: Nat;
        eventType: EventType;
        details: Text;
        initiator: ?Principal;
    };

    public class TokenEvents() {
        private var events: [Event] = [];
        private var nextEventId: Nat = 1;

        public func addEvent(
            tokenId: Nat,
            eventType: EventType,
            details: Text,
            initiator: ?Principal
        ): Event {
            let newEvent: Event = {
                id = nextEventId;
                timestamp = Nat64.toNat(Nat64.fromIntWrap(Time.now()));
                tokenId = tokenId;
                eventType = eventType;
                details = details;
                initiator = initiator;
            };

            events := Array.append(events, [newEvent]);
            nextEventId += 1;

            LoggingUtils.log(
                LoggingUtils.init(),
                #Info,
                "[TokenEvents]",
                "Event logged: " # details,
                initiator
            );

            newEvent
        };

        public func getEventsByTokenId(tokenId: Nat): [Event] {
            Array.filter(events, func(event: Event): Bool {
                event.tokenId == tokenId
            })
        };

        public func getEventsByType(eventType: EventType): [Event] {
            Array.filter(events, func(event: Event): Bool {
                event.eventType == eventType
            })
        };

        public func getAllEvents(): [Event] {
            events
        };

        public func clearEvents() {
            events := [];
            LoggingUtils.log(
                LoggingUtils.init(),
                #Warning,
                "[TokenEvents]",
                "All events cleared",
                null
            );
        };

        public func logEvent(eventType: Text, tokenId: Nat, details: ?Text) : Text {
            let timestamp = Time.now();
            let _event = {
                timestamp = Nat64.toNat(Nat64.fromIntWrap(timestamp));
                eventType = eventType;
                tokenId = tokenId;
                details = details;

    };

    // convert event to a log message
    let logMessage = "Event: " # eventType # " | TokenID: " # Nat.toText(tokenId);
    switch (details) {
        case (?detail) { logMessage # " | Details: " # detail };
        case null { logMessage };
    }

        };

    }
}