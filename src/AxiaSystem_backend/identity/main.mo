import IdentityModule "../identity/modules/identity_module";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import Principal "mo:base/Principal";
import Trie "mo:base/Trie";
import Result "mo:base/Result";
import Text "mo:base/Text";
import _Array "mo:base/Array";

actor IdentityCanister {
    private let eventManager = EventManager.EventManager();
    private let identityManager = IdentityModule.IdentityManager(eventManager);

    // Helper function to create a Trie from an array of key-value pairs
    func createTrie(entries: [(Text, Text)]) : Trie.Trie<Text, Text> {
        var trie = Trie.empty<Text, Text>();
        for ((k, v) in entries.vals()) {
            let key = { key = k; hash = Text.hash(k) };
            trie := Trie.put(trie, key, Text.equal, v).0;
        };
        trie
    };

    // Public API: Create a new identity
    public func createIdentity(userId: Principal, details: [(Text, Text)]): async Result.Result<IdentityModule.Identity, Text> {
        let metadata = createTrie(details);
        await identityManager.createIdentity(userId, metadata);
    };

    // Public API: Update an existing identity
    public func updateIdentity(userId: Principal, details: [(Text, Text)]): async Result.Result<IdentityModule.Identity, Text> {
        let metadata = createTrie(details);
        await identityManager.updateIdentity(userId, metadata);
    };

    // Public API: Delete an identity
    public func deleteIdentity(userId: Principal): async Result.Result<(), Text> {
        await identityManager.deleteIdentity(userId);
    };

    // Public API: Get an identity by user ID
    public func getIdentity(userId: Principal): async ?IdentityModule.Identity {
        await identityManager.getIdentity(userId);
    };

    // Public API: Get all identities
    public func getAllIdentities(): async [IdentityModule.Identity] {
        identityManager.getAllIdentities();
    };

    // Public API: Get stale identities
    public func getStaleIdentities(): async [IdentityModule.Identity] {
        await identityManager.getStaleIdentities();
    };

    // Public API: Find an identity by metadata
    public func findIdentityByMetadata(key: Text, value: Text): async ?IdentityModule.Identity {
        await identityManager.findIdentityByMetadata(key, value);
    };

    // Public API: Batch update metadata for multiple identities
    public func batchUpdateMetadata(updates: [(Principal, Text, Text)]): async Result.Result<(), Text> {
    await identityManager.batchUpdateMetadata(updates);
};

    // Public API: Search identities by metadata
    public func searchIdentitiesByMetadata(key: Text, value: Text): async [IdentityModule.Identity] {
        await identityManager.searchIdentitiesByMetadata(key, value);
    };

    // Public API: Export all identities
    public func exportAllIdentities(): async Text {
        await identityManager.exportAllIdentities();
    };

    // Public API: Trigger heartbeat for stale identity cleanup
    public func runHeartbeat(): async () {
        await identityManager.runHeartbeat();
    };

    // Event subscription for debugging and monitoring
    public func subscribeToEvents(eventType: EventTypes.EventType, listener: shared EventTypes.Event -> async ()): async () {
        await eventManager.subscribe(eventType, listener);
    };

    // Debug API: List all subscribed event types
    public func listSubscribedEventTypes(): async [EventTypes.EventType] {
        await eventManager.listSubscribedEventTypes();
    };
};