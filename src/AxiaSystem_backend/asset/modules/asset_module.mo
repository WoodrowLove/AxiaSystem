import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Trie "mo:base/Trie";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    // Enhanced Asset type with Triad integration
    public type Asset = {
        id: Nat;                        // Unique asset identifier
        ownerIdentity: Principal;       // 🔐 Canonical owner (Identity layer - Triad)
        userId: ?Principal;             // 👤 Optional User layer context (UX/profile link)
        walletId: ?Principal;           // 💰 Optional Wallet layer context (value link)
        metadata: Text;                 // Asset metadata (e.g., description, category)
        registeredAt: Int;              // Timestamp of asset registration (nanoseconds)
        updatedAt: Int;                 // Last update timestamp (nanoseconds)
        isActive: Bool;                 // Asset activity status
        triadVerified: Bool;            // 🛡️ Triad compliance verification flag
    };

    // Custom type for AssetId
    public type AssetId = Nat;

    public class AssetManager(eventManager: EventManager.EventManager) {
        // Enhanced storage with performance optimizations (not stable in class)
        private var nextAssetId: Nat = 1;
        private var assets: Trie.Trie<Nat, Asset> = Trie.empty();
        // 🚀 Performance index: ownerIdentity -> [assetId] for O(assets_owned) queries
        private var byOwner: Trie.Trie<Principal, [Nat]> = Trie.empty();

        // Helper functions for Trie operations
        private func getNatKey(k: Nat): Trie.Key<Nat> = { key = k; hash = Nat32.fromNat(k % (2**32)) };
        private func getPrinKey(p: Principal): Trie.Key<Principal> = { key = p; hash = Principal.hash(p) };

        // Helper function for current timestamp
        private func now(): Int = Time.now();

        // Owner index management for fast lookups
        private func putOwnerIndex(owner: Principal, assetId: Nat) {
            let k = getPrinKey(owner);
            let cur = switch (Trie.get(byOwner, k, Principal.equal)) { 
                case null []; 
                case (?xs) xs 
            };
            byOwner := Trie.put(byOwner, k, Principal.equal, Array.append<Nat>(cur, [assetId])).0;
        };

        private func moveOwnerIndex(oldOwner: Principal, newOwner: Principal, assetId: Nat) {
            // Remove from old owner index
            let ok = getPrinKey(oldOwner);
            let old = switch (Trie.get(byOwner, ok, Principal.equal)) { 
                case null []; 
                case (?xs) xs 
            };
            let old2 = Array.filter<Nat>(old, func (x) { x != assetId });
            byOwner := Trie.put(byOwner, ok, Principal.equal, old2).0;
            // Add to new owner index
            putOwnerIndex(newOwner, assetId);
        };

        // Emit events for asset-related actions
        private func emitAssetEvent(eventType: EventTypes.EventType, payload: EventTypes.EventPayload): async () {
            let event: EventTypes.Event = {
                id = Nat64.fromNat(Int.abs(Time.now()));
                eventType = eventType;
                payload = payload;
            };
            await eventManager.emit(event);
        };

        // 🔥 Core Triad-native asset creation
        public func createAsset(
            ownerIdentity: Principal,
            metadata: Text,
            userId: ?Principal,
            walletId: ?Principal,
            triadVerified: Bool
        ): async Result.Result<Asset, Text> {
            if (Text.size(metadata) == 0) {
                return #err("Metadata cannot be empty.");
            };

            let id = nextAssetId;
            nextAssetId += 1;
            let t = now();
            
            let newAsset: Asset = {
                id = id;
                ownerIdentity = ownerIdentity;
                userId = userId;
                walletId = walletId;
                metadata = metadata;
                registeredAt = t;
                updatedAt = t;
                isActive = true;
                triadVerified = triadVerified;
            };

            assets := Trie.put(assets, getNatKey(id), Nat.equal, newAsset).0;
            putOwnerIndex(ownerIdentity, id);

            await emitAssetEvent(#AssetRegistered, #AssetRegistered {
                assetId = newAsset.id;
                owner = ownerIdentity;
                metadata = metadata;
                registeredAt = t;
            });

            #ok(newAsset)
        };

        // 🔄 Enhanced ownership transfer with Triad support
        public func setOwner(assetId: AssetId, newOwnerIdentity: Principal): async Result.Result<Asset, Text> {
            switch (Trie.get(assets, getNatKey(assetId), Nat.equal)) {
                case null { #err("Asset not found.") };
                case (?asset) {
                    if (not asset.isActive) {
                        return #err("Asset is inactive.");
                    };

                    let updatedAsset = {
                        asset with
                        ownerIdentity = newOwnerIdentity;
                        updatedAt = now();
                    };

                    assets := Trie.put(assets, getNatKey(assetId), Nat.equal, updatedAsset).0;
                    moveOwnerIndex(asset.ownerIdentity, newOwnerIdentity, assetId);

                    await emitAssetEvent(#AssetTransferred, #AssetTransferred {
                        assetId = assetId;
                        previousOwner = asset.ownerIdentity;
                        newOwner = newOwnerIdentity;
                        transferTime = now();
                    });

                    #ok(updatedAsset)
                };
            };
        };

        // 🔴 Asset deactivation with Triad support
        public func setActive(assetId: AssetId, active: Bool): async Result.Result<Asset, Text> {
            switch (Trie.get(assets, getNatKey(assetId), Nat.equal)) {
                case null { #err("Asset not found.") };
                case (?asset) {
                    if (asset.isActive == active) {
                        return #err(if (active) "Asset is already active." else "Asset is already inactive.");
                    };

                    let updatedAsset = { 
                        asset with 
                        isActive = active; 
                        updatedAt = now() 
                    };

                    assets := Trie.put(assets, getNatKey(assetId), Nat.equal, updatedAsset).0;

                    let eventType = if (active) #AssetReactivated else #AssetDeactivated;
                    let eventPayload = if (active) {
                        #AssetReactivated {
                            assetId = assetId;
                            owner = asset.ownerIdentity;
                            reactivatedAt = now();
                        }
                    } else {
                        #AssetDeactivated {
                            assetId = assetId;
                            owner = asset.ownerIdentity;
                            deactivatedAt = now();
                        }
                    };

                    await emitAssetEvent(eventType, eventPayload);
                    #ok(updatedAsset)
                };
            };
        };

        // 🔍 Query operations with Triad-optimized performance
        
        // Get single asset by ID
        public func get(assetId: AssetId): ?Asset {
            Trie.get(assets, getNatKey(assetId), Nat.equal)
        };

        // Get all assets
        public func getAll(): [Asset] {
            let assetArray = Trie.toArray<Nat, Asset, (Nat, Asset)>(assets, func(k, v) { (k, v) });
            Array.map<(Nat, Asset), Asset>(assetArray, func ((_, a)) { a })
        };

        // 🚀 Fast owner lookup using index (O(assets_owned) vs O(all_assets))
        public func getByOwner(ownerIdentity: Principal): [Asset] {
            let ids = switch (Trie.get(byOwner, getPrinKey(ownerIdentity), Principal.equal)) {
                case null []; 
                case (?xs) xs
            };
            Array.mapFilter<Nat, Asset>(ids, func (id) { get(id) })
        };

        // Get only active assets
        public func getActiveAssets(): [Asset] {
            Array.filter<Asset>(getAll(), func(asset: Asset): Bool {
                asset.isActive
            })
        };

        // Search assets by metadata keyword (case-insensitive)
        public func searchByMetadata(keyword: Text): [Asset] {
            if (Text.size(keyword) == 0) return [];
            let kw = Text.toLowercase(keyword);
            Array.filter<Asset>(getAll(), func(a) {
                Text.contains(Text.toLowercase(a.metadata), #text kw)
            })
        };

        // 🔄 Legacy compatibility wrappers
        
        // Legacy: Register asset without Triad verification
        public func registerAsset(owner: Principal, metadata: Text): async Result.Result<Asset, Text> {
            await createAsset(owner, metadata, null, null, false)
        };

        // Legacy: Transfer asset (maps to setOwner)
        public func transferAsset(assetId: AssetId, newOwner: Principal): async Result.Result<Asset, Text> {
            await setOwner(assetId, newOwner)
        };

        // Legacy: Deactivate asset
        public func deactivateAsset(assetId: AssetId): async Result.Result<Asset, Text> {
            await setActive(assetId, false)
        };

        // Legacy: Reactivate asset
        public func reactivateAsset(assetId: AssetId): async Result.Result<Asset, Text> {
            await setActive(assetId, true)
        };

        // Legacy: Get asset (wrapper)
        public func getAsset(assetId: AssetId): async Result.Result<Asset, Text> {
            switch (get(assetId)) {
                case null { #err("Asset not found.") };
                case (?asset) { #ok(asset) };
            };
        };

        // Legacy: Get all assets (wrapper)
        public func getAllAssets(): async [Asset] {
            getAll()
        };

        // Legacy: Get assets by owner (wrapper)
        public func getAssetsByOwner(owner: Principal): async [Asset] {
            getByOwner(owner)
        };

        // Legacy: Search by metadata (wrapper) 
        public func searchAssetsByMetadata(keyword: Text): async [Asset] {
            searchByMetadata(keyword)
        };

        // 📦 Batch operations
        public func batchTransferAssets(assetIds: [AssetId], newOwner: Principal): async Result.Result<[Asset], Text> {
            var updatedAssets: [Asset] = [];
            for (assetId in assetIds.vals()) {
                let transferResult = await setOwner(assetId, newOwner);
                switch (transferResult) {
                    case (#ok(asset)) updatedAssets := Array.append(updatedAssets, [asset]);
                    case (#err(e)) return #err("Failed to transfer asset with ID: " # Nat.toText(assetId) # ", Error: " # e);
                }
            };
            #ok(updatedAssets)
        };
    };
};