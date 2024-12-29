import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Time "mo:base/Time";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
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

        // Emit events for asset-related actions
        private func emitAssetEvent(eventType: EventTypes.EventType, assetId: Nat, details: Text): async () {
            let event: EventTypes.Event = {
                id = assetId;
                eventType = eventType;
                payload = #WalletEventGeneric({
                    walletId = Nat.toText(assetId);
                    details = details;
                });
            };
            await eventManager.emit(event);
        };

        // Register a new asset
        public func registerAsset(owner: Principal, nftId: Nat, metadata: Text): async Result.Result<Asset, Text> {
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

            assets := Trie.put(assets, assetId, Nat.equal, newAsset).0;

            await emitAssetEvent(#TokenCreated, assetId, "Asset registered by " # Principal.toText(owner));
            #ok(newAsset)
        };

        // Transfer ownership of an asset
        public func transferAsset(assetId: Nat, newOwner: Principal): async Result.Result<Asset, Text> {
            switch (Trie.find(assets, assetId, Nat.equal)) {
                case null { #err("Asset not found."); };
                case (?asset) {
                    if (!asset.isActive) {
                        return #err("Asset is inactive.");
                    };

                    let updatedAsset = {
                        asset with
                        owner = newOwner;
                        previousOwners = Array.append(asset.previousOwners, [asset.owner]);
                        updatedAt = Time.now();
                    };

                    assets := Trie.put(assets, assetId, Nat.equal, updatedAsset).0;

                    await emitAssetEvent(#TokenMetadataUpdated, assetId, "Asset ownership transferred to " # Principal.toText(newOwner));
                    #ok(updatedAsset)
                };
            }
        };

        // Deactivate an asset
        public func deactivateAsset(assetId: Nat): async Result.Result<Asset, Text> {
            switch (Trie.find(assets, assetId, Nat.equal)) {
                case null { #err("Asset not found."); };
                case (?asset) {
                    if (!asset.isActive) {
                        return #err("Asset is already inactive.");
                    };

                    let updatedAsset = { asset with isActive = false; updatedAt = Time.now() };
                    assets := Trie.put(assets, assetId, Nat.equal, updatedAsset).0;

                    await emitAssetEvent(#TokenDeactivated, assetId, "Asset deactivated.");
                    #ok(updatedAsset)
                };
            }
        };

        // Reactivate an asset
        public func reactivateAsset(assetId: Nat): async Result.Result<Asset, Text> {
            switch (Trie.find(assets, assetId, Nat.equal)) {
                case null { #err("Asset not found."); };
                case (?asset) {
                    if (asset.isActive) {
                        return #err("Asset is already active.");
                    };

                    let updatedAsset = { asset with isActive = true; updatedAt = Time.now() };
                    assets := Trie.put(assets, assetId, Nat.equal, updatedAsset).0;

                    await emitAssetEvent(#TokenReactivated, assetId, "Asset reactivated.");
                    #ok(updatedAsset)
                };
            }
        };

        // Retrieve an asset by ID
        public func getAsset(assetId: Nat): async Result.Result<Asset, Text> {
            switch (Trie.find(assets, assetId, Nat.equal)) {
                case null { #err("Asset not found."); };
                case (?asset) { #ok(asset); };
            }
        };

        // Retrieve all assets owned by a specific user
        public func getAssetsByOwner(owner: Principal): async [Asset] {
            Array.filter<Asset>(
                Trie.toArray(assets).map<Asset>((kv) => kv.1),
                func(asset: Asset): Bool { asset.owner == owner }
            )
        };

        // Retrieve all assets linked to a specific NFT
        public func getAssetsByNFT(nftId: Nat): async [Asset] {
            Array.filter<Asset>(
                Trie.toArray(assets).map<Asset>((kv) => kv.1),
                func(asset: Asset): Bool { asset.nftId == nftId }
            )
        };

        // Retrieve all assets
        public func getAllAssets(): async [Asset] {
            Trie.toArray(assets).map<Asset>((kv) => kv.1)
        };
    };
};