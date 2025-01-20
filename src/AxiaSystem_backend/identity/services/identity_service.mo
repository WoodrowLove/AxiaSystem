import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Trie "mo:base/Trie";
import Result "mo:base/Result";
import LoggingUtils "../../utils/logging_utils";
import IdentityModule "../modules/identity_module";

module {
  public class IdentityService(identityManager: IdentityModule.IdentityManager) {
    private let logStore = LoggingUtils.init();

    // Register a new identity
    public func registerIdentity(
      userId: Principal,
      metadata: Trie.Trie<Text, Text>
    ): async Result.Result<IdentityModule.Identity, Text> {
      switch (await identityManager.createIdentity(userId, metadata)) {
        case (#ok(identity)) {
          LoggingUtils.logInfo(
            logStore,
            "IdentityService",
            "Successfully registered identity for user: " # Principal.toText(userId),
            null
          );
          #ok(identity)
        };
        case (#err(error)) {
          LoggingUtils.logError(
            logStore,
            "IdentityService",
            "Failed to register identity: " # error,
            null
          );
          #err(error)
        };
      }
    };

    // Update an existing identity
    public func updateIdentity(
      userId: Principal,
      newMetadata: Trie.Trie<Text, Text>
    ): async Result.Result<IdentityModule.Identity, Text> {
      switch (await identityManager.updateIdentity(userId, newMetadata)) {
        case (#ok(updatedIdentity)) {
          LoggingUtils.logInfo(
            logStore,
            "IdentityService",
            "Successfully updated identity for user: " # Principal.toText(userId),
            null
          );
          #ok(updatedIdentity)
        };
        case (#err(error)) {
          LoggingUtils.logError(
            logStore,
            "IdentityService",
            "Failed to update identity: " # error,
            null
          );
          #err(error)
        };
      }
    };

    // Fetch an identity by user ID
    public func getIdentity(userId: Principal): async ?IdentityModule.Identity {
      let identityOpt = await identityManager.getIdentity(userId);
      switch (identityOpt) {
        case null {
          LoggingUtils.logWarning(
            logStore,
            "IdentityService",
            "No identity found for user: " # Principal.toText(userId),
            null
          );
        };
        case (?identity) {
          LoggingUtils.logInfo(
            logStore,
            "IdentityService",
            "Retrieved identity for user: " # Principal.toText(userId),
            null
          );
        };
      };
      identityOpt
    };

    // Retrieve all identities
    public func getAllIdentities(): async [IdentityModule.Identity] {
      LoggingUtils.logInfo(
        logStore,
        "IdentityService",
        "Fetching all identities.",
        null
      );
      identityManager.getAllIdentities()
    };

    // Delete an identity
    public func deleteIdentity(userId: Principal): async Result.Result<(), Text> {
      switch (await identityManager.deleteIdentity(userId)) {
        case (#ok(())) {
          LoggingUtils.logInfo(
            logStore,
            "IdentityService",
            "Successfully deleted identity for user: " # Principal.toText(userId),
            null
          );
          #ok(())
        };
        case (#err(error)) {
          LoggingUtils.logError(
            logStore,
            "IdentityService",
            "Failed to delete identity: " # error,
            null
          );
          #err(error)
        };
      }
    };

    // Find an identity by metadata
    public func findIdentityByMetadata(
      key: Text,
      value: Text
    ): async ?IdentityModule.Identity {
      LoggingUtils.logInfo(
        logStore,
        "IdentityService",
        "Searching for identity with metadata key: " # key # ", value: " # value,
        null
      );
      await identityManager.findIdentityByMetadata(key, value)
    };

    // Batch update metadata for multiple identities
    public func batchUpdateMetadata(
      updates: [(Principal, Trie.Trie<Text, Text>)]
    ): async [Result.Result<(), Text>] {
      LoggingUtils.logInfo(
        logStore,
        "IdentityService",
        "Starting batch metadata update for identities.",
        null
      );
      await identityManager.bulkUpdateMetadata(updates)
    };

    // Export all identities as JSON
    public func exportAllIdentities(): async Text {
      LoggingUtils.logInfo(
        logStore,
        "IdentityService",
        "Exporting all identities.",
        null
      );
      await identityManager.exportAllIdentities()
    };

    // Retrieve stale identities
    public func getStaleIdentities(): async [IdentityModule.Identity] {
      LoggingUtils.logInfo(
        logStore,
        "IdentityService",
        "Fetching stale identities.",
        null
      );
      await identityManager.getStaleIdentities()
    };
  };
};