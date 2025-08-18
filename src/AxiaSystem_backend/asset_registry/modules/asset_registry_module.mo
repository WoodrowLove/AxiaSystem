import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Nat32 "mo:base/Nat32";

module AssetRegistryModule {
  // ---- Enhanced Asset type with Triad fields
  public type Asset = {
    id : Nat;
    nftId : Nat;  // NFT linkage
    ownerIdentity : Principal;
    userId : ?Principal;    // Triad
    walletId : ?Principal;  // Triad
    metadata : Text;
    registeredAt : Int;
    updatedAt : Int;
    isActive : Bool;
    triadVerified : Bool;   // Triad
    // Compacted history on-record
    prevOwnersCount : Nat;
    recentOwners : [Principal];
  };

  public class AssetRegistryManager() {

    // Storage
    private var byId           : Trie.Trie<Nat, Asset> = Trie.empty();
    private var byOwner        : Trie.Trie<Principal, [Nat]> = Trie.empty();
    private var byNFT          : Trie.Trie<Nat, [Nat]> = Trie.empty();
    private var active         : Trie.Trie<Nat, Bool> = Trie.empty();
    private var ownersHistory  : Trie.Trie<Nat, [Principal]> = Trie.empty(); // Full history
    private var nextId         : Nat = 1;

    // Key helpers
    private func nk(n : Nat) : Trie.Key<Nat> = { key = n; hash = Nat32.fromNat(n % (2**31-1)) };
    private func pk(p : Principal) : Trie.Key<Principal> = { key = p; hash = Principal.hash(p) };

    // Index maintenance
    private func appendIndex<K>(
      trie : Trie.Trie<K, [Nat]>,
      key : Trie.Key<K>,
      eq : (K, K) -> Bool,
      assetId : Nat
    ) : Trie.Trie<K, [Nat]> {
      let old = switch (Trie.get(trie, key, eq)) { case null [] ; case (?arr) arr };
      let new = Array.append(old, [assetId]);
      Trie.put(trie, key, eq, new).0
    };

    private func removeFromIndex<K>(
      trie : Trie.Trie<K, [Nat]>,
      key : Trie.Key<K>,
      eq : (K, K) -> Bool,
      assetId : Nat
    ) : Trie.Trie<K, [Nat]> {
      let old = switch (Trie.get(trie, key, eq)) { case null [] ; case (?arr) arr };
      let new = Array.filter<Nat>(old, func (id) { id != assetId });
      Trie.put(trie, key, eq, new).0
    };

    private func now() : Int = Time.now();

    // Keep only the last K owners on-record to cap memory
    let K : Nat = 8;

    // ---- Core ops
    public func create(
      ownerIdentity : Principal,
      nftId_        : Nat,
      metadata_     : Text,
      userId_       : ?Principal,
      walletId_     : ?Principal,
      triadVerified_: Bool
    ) : Asset {
      assert (Text.size(metadata_) > 0);
      let id = nextId; nextId += 1;
      let t = now();
      let a : Asset = {
        id; nftId = nftId_; ownerIdentity; userId = userId_; walletId = walletId_;
        metadata = metadata_; registeredAt = t; updatedAt = t; isActive = true;
        triadVerified = triadVerified_;
        prevOwnersCount = 0;
        recentOwners = [];
      };

      byId := Trie.put(byId, nk(id), Nat.equal, a).0;
      byOwner := appendIndex(byOwner, pk(ownerIdentity), Principal.equal, id);
      byNFT   := appendIndex(byNFT, nk(nftId_), Nat.equal, id);
      active  := Trie.put(active, nk(id), Nat.equal, true).0;
      ownersHistory := Trie.put(ownersHistory, nk(id), Nat.equal, [ownerIdentity]).0;

      a
    };

    public func transfer(assetId : Nat, newOwnerIdentity : Principal) : ?Asset {
      switch (Trie.get(byId, nk(assetId), Nat.equal)) {
        case null null;
        case (?a) {
          if (a.isActive == false) return null;
          // update owner indexes
          byOwner := removeFromIndex(byOwner, pk(a.ownerIdentity), Principal.equal, assetId);
          byOwner := appendIndex(byOwner, pk(newOwnerIdentity), Principal.equal, assetId);

          // history (full)
          let hist = switch (Trie.get(ownersHistory, nk(assetId), Nat.equal)) {
            case null [] ; case (?xs) xs
          };
          ownersHistory := Trie.put(ownersHistory, nk(assetId), Nat.equal, Array.append(hist, [newOwnerIdentity])).0;

          // compact history on-record
          let recent = Array.append<Principal>(a.recentOwners, [newOwnerIdentity]);
          let recentBounded =
            if (Array.size(recent) > K) Array.tabulate<Principal>(K, func (i) { recent[Array.size(recent) - K + i] })
            else recent;

          let updated : Asset = {
            a with ownerIdentity = newOwnerIdentity;
            prevOwnersCount = a.prevOwnersCount + 1;
            recentOwners = recentBounded;
            updatedAt = now()
          };
          byId := Trie.put(byId, nk(assetId), Nat.equal, updated).0;
          ?updated
        }
      }
    };

    public func setActive(assetId : Nat, flag : Bool) : ?Asset {
      switch (Trie.get(byId, nk(assetId), Nat.equal)) {
        case null null;
        case (?a) {
          let updated : Asset = { a with isActive = flag; updatedAt = now() };
          byId := Trie.put(byId, nk(assetId), Nat.equal, updated).0;
          active := Trie.put(active, nk(assetId), Nat.equal, flag).0;
          ?updated
        }
      }
    };

    // ---- Reads
    public func get(assetId : Nat) : ?Asset = Trie.get(byId, nk(assetId), Nat.equal);

    public func getByOwner(ownerIdentity : Principal) : [Asset] {
      let ids = switch (Trie.get(byOwner, pk(ownerIdentity), Principal.equal)) { case null [] ; case (?xs) xs };
      Array.map<Nat, Asset>(ids, func (id) { 
        switch (get(id)) { 
          case (?a) a; 
          case null { // sparse guard
            { id; nftId = 0; ownerIdentity; userId = null; walletId = null; metadata = "(missing)"; 
              registeredAt = 0; updatedAt = 0; isActive = false; triadVerified = false; 
              prevOwnersCount = 0; recentOwners = [] }
          }
        }
      })
    };

    public func getByNFT(nftId_ : Nat) : [Asset] {
      let ids = switch (Trie.get(byNFT, nk(nftId_), Nat.equal)) { case null [] ; case (?xs) xs };
      Array.map<Nat, Asset>(ids, func (id) { 
        switch (get(id)) { 
          case (?a) a; 
          case null { // sparse guard
            { id; nftId = nftId_; ownerIdentity = Principal.fromText("aaaaa-aa"); userId = null; walletId = null; 
              metadata = "(missing)"; registeredAt = 0; updatedAt = 0; isActive = false; triadVerified = false; 
              prevOwnersCount = 0; recentOwners = [] }
          }
        }
      })
    };

    public func getAll() : [Asset] =
      Trie.toArray<Nat, Asset, Asset>(byId, func (k, a) { a });

    public func getHistory(assetId : Nat) : [Principal] =
      switch (Trie.get(ownersHistory, nk(assetId), Nat.equal)) { case null [] ; case (?xs) xs };
  };
};
