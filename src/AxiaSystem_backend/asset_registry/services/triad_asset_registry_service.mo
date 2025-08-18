import AssetRegistryModule "../modules/asset_registry_module";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";

module {
  public type LinkProof = { signature : Blob; challenge : Blob; device : ?Blob };

  public type TriadEvent = {
    topic : Text;
    identityId : Principal;
    userId : ?Principal;
    walletId : ?Principal;
    ref : ?Text;
    data : Blob;
    ts : Nat64;
  };

  // External canister interfaces (to be connected)
  public type IdentityService = actor {
    verify: (Principal, LinkProof) -> async Bool;
  };

  public type UserService = actor {
    getUserById: (Principal) -> async Result.Result<{ identityId: Principal }, Text>;
  };

  public type WalletService = actor {
    getWallet: (Principal) -> async Result.Result<{ ownerIdentity: Principal }, Text>;
  };

  public type EventHub = actor {
    emit: (TriadEvent) -> async ();
  };

  public class TriadAssetRegistryService(
    assetManager: AssetRegistryModule.AssetRegistryManager,
    identityCanister: ?IdentityService,
    userCanister: ?UserService,
    walletCanister: ?WalletService,
    eventHub: ?EventHub
  ) {

    func verify(identity : Principal, proof : LinkProof) : async Bool {
      switch (identityCanister) {
        case null true; // Development mode: always pass
        case (?ic) await ic.verify(identity, proof);
      }
    };

    func ensureUser(identity : Principal, uid : Principal) : async Result.Result<(), Text> {
      switch (userCanister) {
        case null #ok(()); // Development mode: skip validation
        case (?uc) {
          switch (await uc.getUserById(uid)) {
            case (#err _e) #err("user not found");
            case (#ok u) { 
              if (u.identityId != identity) #err("user/identity mismatch") else #ok(()) 
            };
          }
        };
      }
    };

    func ensureWallet(identity : Principal, wid : Principal) : async Result.Result<(), Text> {
      switch (walletCanister) {
        case null #ok(()); // Development mode: skip validation
        case (?wc) {
          switch (await wc.getWallet(wid)) {
            case (#err _e) #err("wallet not found");
            case (#ok w) { 
              if (w.ownerIdentity != identity) #err("wallet/identity mismatch") else #ok(()) 
            };
          }
        };
      }
    };

    func emit(topic : Text, identityId : Principal, userId : ?Principal, walletId : ?Principal, ref : ?Text) : async () {
      switch (eventHub) {
        case null (); // Development mode: skip events
        case (?eh) {
          ignore eh.emit({
            topic; identityId; userId; walletId; ref;
            data = Blob.fromArray([]); ts = Nat64.fromIntWrap(Time.now())
          });
        };
      }
    };

    // ---- Triad endpoints

    public func registerAssetTriad(
      identityId : Principal,
      nftId      : Nat,
      metadata   : Text,
      proof      : LinkProof,
      userId     : ?Principal,
      walletId   : ?Principal
    ) : async Result.Result<AssetRegistryModule.Asset, Text> {
      let verified = await verify(identityId, proof);
      if (not verified) return #err("unauthorized");
      
      switch (userId) { 
        case (?u) { 
          switch (await ensureUser(identityId, u)) { 
            case (#err e) return #err(e); 
            case (#ok ()) () 
          } 
        }; 
        case null () 
      };
      
      switch (walletId) { 
        case (?w) { 
          switch (await ensureWallet(identityId, w)) { 
            case (#err e) return #err(e); 
            case (#ok ()) () 
          } 
        }; 
        case null () 
      };

      let a = assetManager.create(identityId, nftId, metadata, userId, walletId, true);
      await emit("registry.asset.registered", identityId, userId, walletId, ?("asset:" # Nat.toText(a.id)));
      #ok(a)
    };

    public func transferAssetTriad(
      identityId       : Principal,
      assetId          : Nat,
      newOwnerIdentity : Principal,
      proof            : LinkProof,
      userId           : ?Principal
    ) : async Result.Result<AssetRegistryModule.Asset, Text> {
      let verified = await verify(identityId, proof);
      if (not verified) return #err("unauthorized");
      
      switch (assetManager.get(assetId)) {
        case null #err("asset not found");
        case (?a) {
          if (not a.isActive) return #err("asset inactive");
          if (a.ownerIdentity != identityId) return #err("not asset owner");
          
          switch (assetManager.transfer(assetId, newOwnerIdentity)) {
            case null #err("transfer failed");
            case (?updated) {
              await emit("registry.asset.transferred", identityId, userId, updated.walletId, ?("asset:" # Nat.toText(assetId)));
              #ok(updated)
            }
          }
        }
      }
    };

    public func deactivateAssetTriad(identityId : Principal, assetId : Nat, proof : LinkProof) : async Result.Result<AssetRegistryModule.Asset, Text> {
      let verified = await verify(identityId, proof);
      if (not verified) return #err("unauthorized");
      
      switch (assetManager.get(assetId)) {
        case null #err("asset not found");
        case (?a) {
          if (a.ownerIdentity != identityId) return #err("not asset owner");
          
          switch (assetManager.setActive(assetId, false)) {
            case null #err("deactivate failed");
            case (?updated) { 
              await emit("registry.asset.deactivated", identityId, a.userId, a.walletId, ?("asset:" # Nat.toText(assetId))); 
              #ok(updated) 
            }
          }
        }
      }
    };

    public func reactivateAssetTriad(identityId : Principal, assetId : Nat, proof : LinkProof) : async Result.Result<AssetRegistryModule.Asset, Text> {
      let verified = await verify(identityId, proof);
      if (not verified) return #err("unauthorized");
      
      switch (assetManager.get(assetId)) {
        case null #err("asset not found");
        case (?a) {
          if (a.ownerIdentity != identityId) return #err("not asset owner");
          
          switch (assetManager.setActive(assetId, true)) {
            case null #err("reactivate failed");
            case (?updated) { 
              await emit("registry.asset.reactivated", identityId, a.userId, a.walletId, ?("asset:" # Nat.toText(assetId))); 
              #ok(updated) 
            }
          }
        }
      }
    };

    // ---- Query methods (for consistency)
    public func getAsset(assetId : Nat) : ?AssetRegistryModule.Asset = assetManager.get(assetId);
    public func getAssetsByOwner(ownerIdentity : Principal) : [AssetRegistryModule.Asset] = assetManager.getByOwner(ownerIdentity);
    public func getAssetsByNFT(nftId : Nat) : [AssetRegistryModule.Asset] = assetManager.getByNFT(nftId);
    public func getAllAssets() : [AssetRegistryModule.Asset] = assetManager.getAll();
    public func getAssetHistory(assetId : Nat) : [Principal] = assetManager.getHistory(assetId);
  };
};
