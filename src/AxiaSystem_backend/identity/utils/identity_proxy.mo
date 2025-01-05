import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Trie "mo:base/Trie";
import _Nat64 "mo:base/Nat64";

module {
  public type Identity = {
    id: Principal;
    metadata: Trie.Trie<Text, Text>;
    createdAt: Int;
    updatedAt: Int;
  };

  // Define the interface for the identity canister
  public type IdentityCanisterInterface = actor {
    createIdentity: (userId: Principal, metadata: Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
    updateIdentity: (userId: Principal, metadata: Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
    getIdentity: (userId: Principal) -> async ?Identity;
    getAllIdentities: () -> async [Identity];
    deleteIdentity: (userId: Principal) -> async Result.Result<(), Text>;
    getStaleIdentities: () -> async [Identity];
    exportAllIdentities: () -> async Text;
    findIdentityByMetadata: (key: Text, value: Text) -> async ?Identity;
    batchUpdateMetadata: (updates: [(Principal, Trie.Trie<Text, Text>)]) -> async [Result.Result<(), Text>];
  };

  public func createIdentityCanisterProxy(identityCanisterId: Principal): IdentityCanisterInterface {
    actor(Principal.toText(identityCanisterId)) : IdentityCanisterInterface
  };

  public class IdentityCanisterProxy(identityCanisterId: Principal) {
    private let identityCanister: IdentityCanisterInterface = createIdentityCanisterProxy(identityCanisterId);

    public func createIdentity(userId: Principal, metadata: Trie.Trie<Text, Text>): async Result.Result<Identity, Text> {
      try {
        await identityCanister.createIdentity(userId, metadata)
      } catch (e) {
        #err("Failed to create identity: " # Error.message(e))
      }
    };

    public func updateIdentity(userId: Principal, metadata: Trie.Trie<Text, Text>): async Result.Result<Identity, Text> {
      try {
        await identityCanister.updateIdentity(userId, metadata)
      } catch (e) {
        #err("Failed to update identity: " # Error.message(e))
      }
    };

    public func getIdentity(userId: Principal): async ?Identity {
      try {
        await identityCanister.getIdentity(userId)
      } catch (_e) {
        null
      }
    };

    public func getAllIdentities(): async [Identity] {
      try {
        await identityCanister.getAllIdentities()
      } catch (_e) {
        []
      }
    };

    public func deleteIdentity(userId: Principal): async Result.Result<(), Text> {
      try {
        await identityCanister.deleteIdentity(userId)
      } catch (e) {
        #err("Failed to delete identity: " # Error.message(e))
      }
    };

    public func getStaleIdentities(): async [Identity] {
      try {
        await identityCanister.getStaleIdentities()
      } catch (_e) {
        []
      }
    };

    public func exportAllIdentities(): async Text {
      try {
        await identityCanister.exportAllIdentities()
      } catch (_e) {
        "[]"
      }
    };

    public func findIdentityByMetadata(key: Text, value: Text): async ?Identity {
      try {
        await identityCanister.findIdentityByMetadata(key, value)
      } catch (_e) {
        null
      }
    };

    public func batchUpdateMetadata(
      updates: [(Principal, Trie.Trie<Text, Text>)]
    ): async [Result.Result<(), Text>] {
      try {
        await identityCanister.batchUpdateMetadata(updates)
      } catch (e) {
        [#err("Failed to batch update metadata: " # Error.message(e))]
      }
    };
  };
};