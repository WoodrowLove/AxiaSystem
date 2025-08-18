import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import AssetService "./services/asset_service";
import TriadAssetService "./services/triad_asset_service";
import EventManager "../heartbeat/event_manager";
import AssetModule "./modules/asset_module";

persistent actor AssetCanister {
    // Initialize the event manager
    private transient let eventManager = EventManager.EventManager();

    // Initialize the Asset Manager
    private transient let assetManager = AssetService.createAssetService(eventManager);

    // Initialize the Triad Asset Service (with placeholder canister references)
    private transient let triadAssetService = TriadAssetService.TriadAssetService(
        assetManager,
        null, // identityCanister: ?IdentityService - to be connected
        null, // userCanister: ?UserService - to be connected  
        null, // walletCanister: ?WalletService - to be connected
        null  // eventHub: ?EventHub - to be connected
    );

    // 🔥 TRIAD-COMPLIANT ENDPOINTS (New, Recommended)

    // Register Asset with Full Triad Validation
    public shared ({ caller = _ }) func registerAssetTriad(
        identityId: Principal,
        metadata: Text,
        proof: TriadAssetService.LinkProof,
        userId: ?Principal,
        walletId: ?Principal
    ): async Result.Result<Nat, Text> {
        await triadAssetService.registerAssetTriad(identityId, metadata, proof, userId, walletId)
    };

    // Transfer Asset Ownership with Triad Validation
    public shared ({ caller = _ }) func transferAssetTriad(
        identityId: Principal,
        assetId: Nat,
        newOwnerIdentity: Principal,
        proof: TriadAssetService.LinkProof,
        userId: ?Principal
    ): async Result.Result<(), Text> {
        await triadAssetService.transferAssetTriad(identityId, assetId, newOwnerIdentity, proof, userId)
    };

    // Deactivate Asset with Triad Validation
    public shared ({ caller = _ }) func deactivateAssetTriad(
        identityId: Principal, 
        assetId: Nat, 
        proof: TriadAssetService.LinkProof
    ): async Result.Result<(), Text> {
        await triadAssetService.deactivateAssetTriad(identityId, assetId, proof)
    };

    // Reactivate Asset with Triad Validation
    public shared ({ caller = _ }) func reactivateAssetTriad(
        identityId: Principal, 
        assetId: Nat, 
        proof: TriadAssetService.LinkProof
    ): async Result.Result<(), Text> {
        await triadAssetService.reactivateAssetTriad(identityId, assetId, proof)
    };

    // Batch Transfer Assets with Triad Validation
    public shared ({ caller = _ }) func batchTransferAssetsTriad(
        identityId: Principal,
        assetIds: [Nat],
        newOwnerIdentity: Principal,
        proof: TriadAssetService.LinkProof,
        userId: ?Principal
    ): async Result.Result<(), Text> {
        await triadAssetService.batchTransferAssetsTriad(identityId, assetIds, newOwnerIdentity, proof, userId)
    };
    // 🔄 LEGACY ENDPOINTS (Backward Compatibility - Deprecated)
    // Note: These maintain backward compatibility but mark triadVerified=false
    // New integrations should use the *Triad endpoints above

    // Register a new asset (Legacy)
    public shared ({ caller = _ }) func registerAsset(
        owner: Principal,
        metadata: Text
    ): async Result.Result<Nat, Text> {
        let result = await AssetService.registerAsset(assetManager, owner, metadata);
        switch (result) {
            case (#ok(asset)) #ok(asset.id);
            case (#err(error)) #err(error);
        }
    };

    // Transfer ownership of an asset (Legacy)
    public shared ({ caller = _ }) func transferAsset(
        assetId: Nat,
        newOwner: Principal
    ): async Result.Result<(), Text> {
        let result = await AssetService.transferAsset(assetManager, assetId, newOwner);
        switch (result) {
            case (#ok(_)) { #ok(()) };
            case (#err(e)) { #err(e) };
        }
    };

    // Deactivate an asset (Legacy)
    public shared ({ caller = _ }) func deactivateAsset(assetId: Nat): async Result.Result<(), Text> {
        let result = await AssetService.deactivateAsset(assetManager, assetId);
        switch (result) {
            case (#ok(_)) { #ok(()) };
            case (#err(e)) { #err(e) };
        }
    };

    // Reactivate an asset (Legacy)
    public shared ({ caller = _ }) func reactivateAsset(assetId: Nat): async Result.Result<(), Text> {
        let result = await AssetService.reactivateAsset(assetManager, assetId);
        switch (result) {
            case (#ok(_)) { #ok(()) };
            case (#err(e)) { #err(e) };
        }
    };

    // Batch transfer ownership of assets (Legacy)
    public shared ({ caller = _ }) func batchTransferAssets(
        assetIds: [Nat],
        newOwner: Principal
    ): async Result.Result<[AssetModule.Asset], Text> {
        await AssetService.batchTransferAssets(assetManager, assetIds, newOwner);
    };

    // 🔍 QUERY ENDPOINTS (Backward Compatible)
    // These work for both Triad and Legacy assets

    // Retrieve asset details by ID
    public query func getAsset(
        assetId: Nat
    ): async Result.Result<AssetModule.Asset, Text> {
        switch (triadAssetService.getAsset(assetId)) {
            case null { #err("Asset not found") };
            case (?asset) { #ok(asset) };
        };
    };

    // Retrieve all assets
    public query func getAllAssets(): async [AssetModule.Asset] {
        triadAssetService.getAllAssets()
    };

    // Retrieve assets owned by a specific user (supports both legacy owner and Identity)
    public query func getAssetsByOwner(owner: Principal): async [AssetModule.Asset] {
        triadAssetService.getAssetsByOwner(owner)
    };

    // Retrieve all active assets
    public query func getActiveAssets(): async [AssetModule.Asset] {
        triadAssetService.getActiveAssets()
    };

    // Search assets by metadata keyword
    public query func searchAssetsByMetadata(keyword: Text): async [AssetModule.Asset] {
        triadAssetService.searchAssetsByMetadata(keyword)
    };

    // 📊 SYSTEM INFORMATION

    // Get system statistics
    public query func getSystemStats(): async {
        totalAssets: Nat;
        activeAssets: Nat;
        triadVerifiedAssets: Nat;
    } {
        let allAssets = triadAssetService.getAllAssets();
        let activeAssets = triadAssetService.getActiveAssets();
        let triadVerified = Array.filter(allAssets, func(a: AssetModule.Asset): Bool { a.triadVerified });
        
        {
            totalAssets = allAssets.size();
            activeAssets = activeAssets.size();
            triadVerifiedAssets = triadVerified.size();
        }
    };
};