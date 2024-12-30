import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {

type AssetId = Nat;

    public type Asset = {
        id: Nat;
        nftId: Nat;               // Linked NFT ID
        owner: Principal;         // Current owner
        previousOwners: [Principal]; // Historical owners
        metadata: Text;           // Asset-specific metadata (e.g., description, category)
        registeredAt: Int;        // Timestamp of asset registration
        updatedAt: Int;           // Last update timestamp
        isActive: Bool;           // Asset activity status
    };

    public class AssetRegistryManager(eventManager: EventManager.EventManager) {
        private var assets: Trie.Trie<Nat, Asset> = Trie.empty(); // Asset registry keyed by asset ID
        private var nextId: Nat = 1; // Auto-incrementing asset ID

        // Custom hash function for Nat
func natHash(n: Nat) : Hash.Hash {
    let hashValue = Nat32.fromNat(n);
    // Combine upper and lower 16 bits
    hashValue ^ (hashValue >> 16)
};

        // Emit events for asset-related actions
private func emitAssetEvent(eventType: EventTypes.EventType, assetId: Nat64, details: Text): async () {
    let event: EventTypes.Event = {
        id = assetId;
        eventType = eventType;
        payload = #WalletEventGeneric({
            walletId = Nat64.toText(assetId);
            details = details;
        });
    };
    await eventManager.emit(event);
};

        // Register a new asset
        public func registerAssetInRegistry(owner: Principal, nftId: Nat, metadata: Text): async Result.Result<Asset, Text> {
    if (metadata.size() == 0) {
        return #err("Metadata cannot be empty.");
    };

    let assetId = nextId;
    nextId += 1;

    let newAsset: Asset = {
        id = assetId;
        nftId = nftId;
        owner = owner;
        previousOwners = [];
        metadata = metadata;
        registeredAt = Time.now();
        updatedAt = Time.now();
        isActive = true;
    };

   let assetKey : Trie.Key<Nat> = { key = assetId; hash = natHash(assetId) };
assets := Trie.put(assets, assetKey, Nat.equal, newAsset).0;

    let assetIdNat64 = Nat64.fromNat(assetId);
    await emitAssetEvent(#TokenCreated, assetIdNat64, "Asset registered by " # Principal.toText(owner));

    #ok(newAsset)
};

        // Transfer ownership of an asset
        public func transferAssetInRegistry(assetId: Nat, newOwner: Principal): async Result.Result<Asset, Text> {
    let assetKey : Trie.Key<Nat> = { key = assetId; hash = natHash(assetId) };
    switch (Trie.find(assets, assetKey, Nat.equal)) {
        case null { #err("Asset not found.") };
        case (?asset) {
            if (not asset.isActive) {
                return #err("Asset is inactive.");
            };

            let updatedAsset = {
                asset with
                owner = newOwner;
                previousOwners = Array.append(asset.previousOwners, [asset.owner]);
                updatedAt = Time.now();
            };

            assets := Trie.put(assets, assetKey, Nat.equal, updatedAsset).0;

            let assetIdNat64 = Nat64.fromNat(assetId);
            await emitAssetEvent(#TokenMetadataUpdated, assetIdNat64, "Asset ownership transferred to " # Principal.toText(newOwner));
            #ok(updatedAsset)
        };
    }
};

       public func deactivateAssetInRegistry(assetId: Nat): async Result.Result<Asset, Text> {
    let assetKey : Trie.Key<Nat> = { key = assetId; hash = natHash(assetId) };
    switch (Trie.find(assets, assetKey, Nat.equal)) {
        case null { #err("Asset not found.") };
        case (?asset) {
            if (not asset.isActive) {
                return #err("Asset is already inactive.");
            };

            let updatedAsset = { asset with isActive = false; updatedAt = Time.now() };
            assets := Trie.put(assets, assetKey, Nat.equal, updatedAsset).0;

            let assetIdNat64 = Nat64.fromNat(assetId);
            await emitAssetEvent(#TokenDeactivated, assetIdNat64, "Asset deactivated.");
            #ok(updatedAsset)
        };
    }
};

        public func reactivateAssetInRegistry(assetId: Nat): async Result.Result<Asset, Text> {
    let assetKey : Trie.Key<Nat> = { key = assetId; hash = natHash(assetId) };
    switch (Trie.find(assets, assetKey, Nat.equal)) {
        case null { #err("Asset not found.") };
        case (?asset) {
            if (asset.isActive) {
                return #err("Asset is already active.");
            };

            let updatedAsset = { asset with isActive = true; updatedAt = Time.now() };
            assets := Trie.put(assets, assetKey, Nat.equal, updatedAsset).0;

            let assetIdNat64 = Nat64.fromNat(assetId);
            await emitAssetEvent(#TokenReactivated, assetIdNat64, "Asset reactivated.");
            #ok(updatedAsset)
        };
    }
};

        public func getAssetInRegistry(assetId: Nat): async Result.Result<Asset, Text> {
    let assetKey : Trie.Key<Nat> = { key = assetId; hash = natHash(assetId) };
    switch (Trie.find(assets, assetKey, Nat.equal)) {
        case null { #err("Asset not found.") };
        case (?asset) { #ok(asset) };
    }
};

        // Retrieve all assets owned by a specific user
public func getAssetsByOwnerInRegistry(owner: Principal) : async [Asset] {
    Trie.toArray<AssetId, Asset, Asset>(assets, func (k: AssetId, v: Asset) : Asset { v })
    |> Array.filter<Asset>(_, func(asset: Asset) : Bool { asset.owner == owner })
};

// Retrieve all assets linked to a specific NFT
public func getAssetsByNFTInRegistry(nftId: Nat) : async [Asset] {
    Trie.toArray<AssetId, Asset, Asset>(assets, func (k: AssetId, v: Asset) : Asset { v })
    |> Array.filter<Asset>(_, func(asset: Asset) : Bool { asset.nftId == nftId })
};

// Retrieve all assets
public func getAllAssetsInRegistry() : async [Asset] {
    Trie.toArray<AssetId, Asset, Asset>(assets, func (k: AssetId, v: Asset) : Asset { v })
};

// Retrieve the ownership history of an asset
public func getAssetOwnershipHistoryInRegistry(assetId: Nat): async Result.Result<[Principal], Text> {
    let assetKey : Trie.Key<Nat> = { key = assetId; hash = natHash(assetId) };
    switch (Trie.find(assets, assetKey, Nat.equal)) {
        case null { #err("Asset not found.") };
        case (?asset) {
            #ok(asset.previousOwners);
        };
    }
};

    };
};