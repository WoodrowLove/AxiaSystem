import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import LoggingUtils "../../utils/logging_utils";
import EventManager "../../heartbeat/event_manager";
import _EventTypes "../../heartbeat/event_types";
import JSON "mo:json/JSON";

module {
    public type Identity = {
        id: Principal;
        deviceKeys: [Principal]; 
        metadata: Trie.Trie<Text, Text>;
        createdAt: Int;
        updatedAt: Int;
    };

    public type IdentityManagerInterface = {
        createIdentity: (Principal, Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
        updateIdentity: (Principal, Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
        getIdentity: (Principal) -> async ?Identity;
        getAllIdentities: () -> [Identity];
    };

    public class IdentityManager(eventManager: EventManager.EventManager) : IdentityManagerInterface {
        private var identities: [Identity] = [];
        private let logStore = LoggingUtils.init();

        public func createIdentity(userId: Principal, details: Trie.Trie<Text, Text>): async Result.Result<Identity, Text> {
    if (Array.find<Identity>(identities, func(identity) { identity.id == userId }) != null) {
        LoggingUtils.logError(
            logStore,
            "IdentityModule",
            "Identity already exists for user: " # Principal.toText(userId),
            null
        );
        return #err("Identity already exists for this user.");
    };

    let newIdentity: Identity = {
        id = userId;
        deviceKeys = [];
        metadata = details;
        createdAt = Time.now();
        updatedAt = Time.now();
    };

    identities := Array.append<Identity>(identities, [newIdentity]);

    // Emit event for identity creation
    await eventManager.emit({
        eventType = #IdentityCreated;
        id = Nat64.fromIntWrap(Time.now());
        payload = #IdentityCreated({
            id = userId;
            metadata = details;
            createdAt = newIdentity.createdAt;
        });
    });

    LoggingUtils.logInfo(
        logStore,
        "IdentityModule",
        "Created new identity for user: " # Principal.toText(userId),
        null
    );

    #ok(newIdentity)
};

// Add a method to register new device keys
public func addDeviceKey(userId: Principal, newDeviceKey: Principal): async Result.Result<(), Text> {
    var updatedIdentity: ?Identity = null;

    identities := Array.map<Identity, Identity>(identities, func(identity) {
        if (identity.id == userId) {
            // Explicitly check the result of Array.find
            let keyExists: ?Principal = Array.find(identity.deviceKeys, func(key: Principal) : Bool {
                key == newDeviceKey
            });
            if (keyExists != null) {
                return identity; // Key already exists; no changes needed
            };
            let updated = {
                identity with
                deviceKeys = Array.append(identity.deviceKeys, [newDeviceKey]);
                updatedAt = Time.now();
            };
            updatedIdentity := ?updated;
            return updated;
        };
        return identity;
    });

    switch updatedIdentity {
        case null { #err("User not found or device key already exists."); };
        case (?_) { #ok(()); };
    }
};

        public func updateIdentity(userId: Principal, details: Trie.Trie<Text, Text>): async Result.Result<Identity, Text> {
    var updatedIdentity: ?Identity = null;
    identities := Array.map<Identity, Identity>(identities, func(identity) {
        if (identity.id == userId) {
            let updated: Identity = {
                id = identity.id;
                deviceKeys = [];
                metadata = details;
                createdAt = identity.createdAt;
                updatedAt = Time.now();
            };
            updatedIdentity := ?updated;
            updated
        } else {
            identity
        }
    });

    switch updatedIdentity {
        case null {
            LoggingUtils.logError(
                logStore,
                "IdentityModule",
                "Failed to update identity for user: " # Principal.toText(userId),
                null
            );
            #err("Identity not found for user.")
        };
        case (?identity) {
            // Emit event for identity update
            await eventManager.emit({
                eventType = #IdentityUpdated;
                id = Nat64.fromIntWrap(Time.now());
                payload = #IdentityUpdated({
                    id = userId;
                    metadata = details;
                    updatedAt = identity.updatedAt;
                });
            });

            LoggingUtils.logInfo(
                logStore,
                "IdentityModule",
                "Updated identity for user: " # Principal.toText(userId),
                null
            );
            #ok(identity)
        };
    }
};

        // Get an identity by ID
        public func getIdentity(userId: Principal): async ?Identity {
            Array.find<Identity>(identities, func(identity) { identity.id == userId })
        };

        // Retrieve all identities
        public func getAllIdentities(): [Identity] {
            identities;
        };

        // Heartbeat maintenance task
public func runHeartbeat(): async () {
    let now = Time.now();
    let stalePeriod = 30 * 24 * 60 * 60 * 1_000_000; // 30 days in microseconds

    let staleIdentities = Array.filter<Identity>(identities, func(identity) {
    now - identity.updatedAt > stalePeriod
});

let activeIdentities = Array.filter<Identity>(identities, func(identity) {
    now - identity.updatedAt <= stalePeriod
});

// Update the identities array
identities := activeIdentities;

    // Emit events for stale identity removals
    for (identity in staleIdentities.vals()) {
        LoggingUtils.logInfo(
            logStore,
            "IdentityModule",
            "Removing stale identity: " # Principal.toText(identity.id),
            null
        );

        await eventManager.emit({
            eventType = #IdentityStaleRemoved;
            id = Nat64.fromIntWrap(Time.now());
            payload = #IdentityStaleRemoved({
                id = identity.id;
                removedAt = now;
            });
        });
    };
};

public func deleteIdentity(userId: Principal): async Result.Result<(), Text> {
    let initialSize = identities.size();
    identities := Array.filter<Identity>(identities, func(identity) { identity.id != userId });

    if (initialSize == identities.size()) {
        LoggingUtils.logError(
            logStore,
            "IdentityModule",
            "Failed to delete identity for user: " # Principal.toText(userId),
            null
        );
        return #err("Identity not found for user.");
    };

    LoggingUtils.logInfo(
        logStore,
        "IdentityModule",
        "Deleted identity for user: " # Principal.toText(userId),
        null
    );

    await eventManager.emit({
        eventType = #IdentityDeleted;
        id = Nat64.fromIntWrap(Time.now());
        payload = #IdentityDeleted({
            id = userId;
            deletedAt = Time.now();
        });
    });

    return #ok(());
};

public func findIdentityByMetadata(key: Text, value: Text): async ?Identity {
    Array.find<Identity>(identities, func(identity) {
        switch (Trie.get(identity.metadata, { key = key; hash = Text.hash(key) }, Text.equal)) {
            case (?v) v == value;
            case null false;
        }
    });
};

public func bulkUpdateMetadata(updates: [(Principal, Trie.Trie<Text, Text>)]) : async [Result.Result<(), Text>] {
    let results = Buffer.Buffer<Result.Result<(), Text>>(updates.size());
    for ((userId, details) in updates.vals()) {
        let result = await updateIdentity(userId, details);
        switch (result) {
            case (#ok(_)) { results.add(#ok(())) };
            case (#err(e)) { results.add(#err(e)) };
        };
    };
    Buffer.toArray(results)
};


public func searchIdentitiesByMetadata(key: Text, value: Text): async [Identity] {
    Array.filter<Identity>(identities, func(identity) {
        switch (Trie.find(identity.metadata, { key = key; hash = Text.hash(key) }, Text.equal)) {
            case (?v) { v == value };
            case null { false };
        }
    })
};

public func batchUpdateMetadata(updates: [(Principal, Text, Text)]): async Result.Result<(), Text> {
    for ((userId, key, value) in updates.vals()) {
        let identityOpt = Array.find<Identity>(identities, func(identity) { identity.id == userId });
        switch (identityOpt) {
            case null {
                LoggingUtils.logError(
                    logStore,
                    "IdentityModule",
                    "Identity not found for user: " # Principal.toText(userId),
                    null
                );
                return #err("Identity not found for user: " # Principal.toText(userId));
            };
            case (?identity) {
                let (updatedMetadata, _) = Trie.put(
                    identity.metadata,
                    { key = key; hash = Text.hash(key) },
                    Text.equal,
                    value
                );
                let updatedIdentity = {
                    identity with
                    metadata = updatedMetadata;
                    updatedAt = Time.now();
                };
                identities := Array.map<Identity, Identity>(identities, func(id) {
                    if (id.id == userId) { updatedIdentity } else { id }
                });
            };
        };
    };

    LoggingUtils.logInfo(
        logStore,
        "IdentityModule",
        "Batch metadata update completed.",
        null
    );

    #ok(())
};

public func getStaleIdentities(): async [Identity] {
    let now = Time.now();
    let stalePeriod = 30 * 24 * 60 * 60 * 1_000_000; // 30 days in microseconds
    Array.filter<Identity>(identities, func(identity) {
        now - identity.updatedAt > stalePeriod
    });
};

public func exportAllIdentities(): async Text {
    let identitiesData = Array.map<Identity, Text>(identities, func(identity) {
        let metadataJson = JSON.show(#Object(
            Iter.toArray(
                Iter.map<(Text, Text), (Text, JSON.JSON)>(
                    Trie.iter(identity.metadata),
                    func((k, v)) { (k, #String(v)) }
                )
            )
        ));
        
        "{ \"id\": \"" # Principal.toText(identity.id) # "\", " #
        "\"metadata\": " # metadataJson # ", " #
        "\"createdAt\": " # Int.toText(identity.createdAt) # ", " #
        "\"updatedAt\": " # Int.toText(identity.updatedAt) # " }"
    });
    "[" # Text.join(", ", identitiesData.vals()) # "]"
};

    };
};