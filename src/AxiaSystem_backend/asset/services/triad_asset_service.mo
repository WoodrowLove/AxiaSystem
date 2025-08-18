import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Blob "mo:base/Blob";
import AssetModule "../modules/asset_module";

module {
    // 🔗 Triad Integration Types
    public type LinkProof = { 
        signature: Blob; 
        challenge: Blob; 
        device: ?Blob 
    };

    public type TriadEvent = {
        topic: Text;
        identityId: Principal;
        userId: ?Principal;
        walletId: ?Principal;
        ref: ?Text;
        data: Blob;
        ts: Nat64;
    };

    // 🛡️ External Canister Interfaces (to be connected)
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

    // 🎯 Triad Asset Service Class
    public class TriadAssetService(
        assetManager: AssetModule.AssetManager,
        identityCanister: ?IdentityService,
        userCanister: ?UserService,
        walletCanister: ?WalletService,
        eventHub: ?EventHub
    ) {

        // 🔐 Helper: Verify Identity + Device Authentication
        private func verifyIdentity(identityId: Principal, proof: LinkProof): async Bool {
            switch (identityCanister) {
                case null { 
                    // Fallback: basic principal validation for development
                    Principal.isAnonymous(identityId) == false
                };
                case (?identity) {
                    try {
                        await identity.verify(identityId, proof)
                    } catch (_) {
                        false
                    }
                };
            }
        };

        // 👤 Helper: Ensure User-Identity Link Consistency  
        private func ensureUserLink(userId: Principal, identityId: Principal): async Result.Result<(), Text> {
            switch (userCanister) {
                case null { #ok(()) }; // Skip validation if no user canister
                case (?user) {
                    switch (await user.getUserById(userId)) {
                        case (#err(e)) { #err("User not found: " # e) };
                        case (#ok(userRecord)) {
                            if (userRecord.identityId != identityId) {
                                #err("User-Identity mismatch")
                            } else {
                                #ok(())
                            }
                        };
                    }
                };
            }
        };

        // 💰 Helper: Ensure Wallet-Identity Ownership
        private func ensureWalletOwner(walletId: Principal, identityId: Principal): async Result.Result<(), Text> {
            switch (walletCanister) {
                case null { #ok(()) }; // Skip validation if no wallet canister
                case (?wallet) {
                    switch (await wallet.getWallet(walletId)) {
                        case (#err(e)) { #err("Wallet not found: " # e) };
                        case (#ok(walletRecord)) {
                            if (walletRecord.ownerIdentity != identityId) {
                                #err("Wallet ownership mismatch")
                            } else {
                                #ok(())
                            }
                        };
                    }
                };
            }
        };

        // 📡 Helper: Emit Triad Event
        private func emitTriadEvent(
            topic: Text,
            identityId: Principal,
            userId: ?Principal,
            walletId: ?Principal,
            ref: ?Text
        ): async () {
            switch (eventHub) {
                case null { /* No event emission in development */ };
                case (?hub) {
                    try {
                        await hub.emit({
                            topic = topic;
                            identityId = identityId;
                            userId = userId;
                            walletId = walletId;
                            ref = ref;
                            data = Blob.fromArray([]);
                            ts = Nat64.fromIntWrap(Time.now());
                        });
                    } catch (_) {
                        // Log error but don't fail the operation
                    }
                };
            }
        };

        // 🔥 TRIAD-COMPLIANT ASSET OPERATIONS

        // Register Asset with Full Triad Validation
        public func registerAssetTriad(
            identityId: Principal,
            metadata: Text,
            proof: LinkProof,
            userId: ?Principal,
            walletId: ?Principal
        ): async Result.Result<Nat, Text> {
            // 1. Verify Identity + Device Authentication
            if (not (await verifyIdentity(identityId, proof))) {
                return #err("Unauthorized: Identity verification failed");
            };

            // 2. Validate User-Identity Link (if provided)
            switch (userId) {
                case null { /* No user context to validate */ };
                case (?uid) {
                    switch (await ensureUserLink(uid, identityId)) {
                        case (#err(e)) { return #err(e) };
                        case (#ok(())) { /* Validation passed */ };
                    }
                };
            };

            // 3. Validate Wallet-Identity Ownership (if provided)
            switch (walletId) {
                case null { /* No wallet context to validate */ };
                case (?wid) {
                    switch (await ensureWalletOwner(wid, identityId)) {
                        case (#err(e)) { return #err(e) };
                        case (#ok(())) { /* Validation passed */ };
                    }
                };
            };

            // 4. Create Asset with Triad Verification
            switch (await assetManager.createAsset(identityId, metadata, userId, walletId, true)) {
                case (#err(e)) { #err(e) };
                case (#ok(asset)) {
                    // 5. Emit Triad Event
                    await emitTriadEvent(
                        "asset.registered",
                        identityId,
                        userId,
                        walletId,
                        ?("asset:" # Nat.toText(asset.id))
                    );

                    #ok(asset.id)
                };
            };
        };

        // Transfer Asset with Triad Validation
        public func transferAssetTriad(
            identityId: Principal,
            assetId: Nat,
            newOwnerIdentity: Principal,
            proof: LinkProof,
            userId: ?Principal
        ): async Result.Result<(), Text> {
            // 1. Verify Identity + Device Authentication
            if (not (await verifyIdentity(identityId, proof))) {
                return #err("Unauthorized: Identity verification failed");
            };

            // 2. Get and validate asset ownership
            switch (assetManager.get(assetId)) {
                case null { return #err("Asset not found") };
                case (?asset) {
                    if (not asset.isActive) {
                        return #err("Asset is inactive");
                    };
                    if (asset.ownerIdentity != identityId) {
                        return #err("Not asset owner");
                    };

                    // 3. Perform transfer
                    switch (await assetManager.setOwner(assetId, newOwnerIdentity)) {
                        case (#err(e)) { #err(e) };
                        case (#ok(updatedAsset)) {
                            // 4. Emit Triad Event
                            await emitTriadEvent(
                                "asset.transferred",
                                identityId,
                                userId,
                                updatedAsset.walletId,
                                ?("asset:" # Nat.toText(assetId))
                            );

                            #ok(())
                        };
                    };
                };
            };
        };

        // Deactivate Asset with Triad Validation
        public func deactivateAssetTriad(
            identityId: Principal, 
            assetId: Nat, 
            proof: LinkProof
        ): async Result.Result<(), Text> {
            // 1. Verify Identity + Device Authentication
            if (not (await verifyIdentity(identityId, proof))) {
                return #err("Unauthorized: Identity verification failed");
            };

            // 2. Validate ownership and perform deactivation
            switch (assetManager.get(assetId)) {
                case null { #err("Asset not found") };
                case (?asset) {
                    if (asset.ownerIdentity != identityId) {
                        return #err("Not asset owner");
                    };

                    switch (await assetManager.setActive(assetId, false)) {
                        case (#err(e)) { #err(e) };
                        case (#ok(_)) {
                            // 3. Emit Triad Event
                            await emitTriadEvent(
                                "asset.deactivated",
                                identityId,
                                asset.userId,
                                asset.walletId,
                                ?("asset:" # Nat.toText(assetId))
                            );

                            #ok(())
                        };
                    };
                };
            };
        };

        // Reactivate Asset with Triad Validation
        public func reactivateAssetTriad(
            identityId: Principal, 
            assetId: Nat, 
            proof: LinkProof
        ): async Result.Result<(), Text> {
            // 1. Verify Identity + Device Authentication
            if (not (await verifyIdentity(identityId, proof))) {
                return #err("Unauthorized: Identity verification failed");
            };

            // 2. Validate ownership and perform reactivation
            switch (assetManager.get(assetId)) {
                case null { #err("Asset not found") };
                case (?asset) {
                    if (asset.ownerIdentity != identityId) {
                        return #err("Not asset owner");
                    };

                    switch (await assetManager.setActive(assetId, true)) {
                        case (#err(e)) { #err(e) };
                        case (#ok(_)) {
                            // 3. Emit Triad Event
                            await emitTriadEvent(
                                "asset.reactivated",
                                identityId,
                                asset.userId,
                                asset.walletId,
                                ?("asset:" # Nat.toText(assetId))
                            );

                            #ok(())
                        };
                    };
                };
            };
        };

        // 🔍 QUERY OPERATIONS (No authentication required)

        public func getAsset(assetId: Nat): ?AssetModule.Asset {
            assetManager.get(assetId)
        };

        public func getAllAssets(): [AssetModule.Asset] {
            assetManager.getAll()
        };

        public func getAssetsByOwner(ownerIdentity: Principal): [AssetModule.Asset] {
            assetManager.getByOwner(ownerIdentity)
        };

        public func getActiveAssets(): [AssetModule.Asset] {
            assetManager.getActiveAssets()
        };

        public func searchAssetsByMetadata(keyword: Text): [AssetModule.Asset] {
            assetManager.searchByMetadata(keyword)
        };

        // 📦 BATCH OPERATIONS (Triad-compliant)

        public func batchTransferAssetsTriad(
            identityId: Principal,
            assetIds: [Nat],
            newOwnerIdentity: Principal,
            proof: LinkProof,
            userId: ?Principal
        ): async Result.Result<(), Text> {
            // Verify identity once for the batch
            if (not (await verifyIdentity(identityId, proof))) {
                return #err("Unauthorized: Identity verification failed");
            };

            // Process each asset transfer
            for (assetId in assetIds.vals()) {
                switch (await transferAssetTriad(identityId, assetId, newOwnerIdentity, proof, userId)) {
                    case (#err(e)) {
                        return #err("Batch transfer failed at asset " # Nat.toText(assetId) # ": " # e);
                    };
                    case (#ok(())) { /* Continue */ };
                }
            };

            #ok(())
        };
    };
}
