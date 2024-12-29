import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Debug "mo:base/Debug";
import EventManager "../../heartbeat/event_manager";
import EventTypes "../../heartbeat/event_types";

module {
    public type NFT = {
        id: Nat;
        creator: Principal;
        owner: Principal;
        metadata: Text; // JSON or URI for metadata
        createdAt: Int;
        updatedAt: Int;
        isActive: Bool;
    };

    public class NFTManager(eventManager: EventManager.EventManager) {
        private var nfts: Trie.Trie<Nat, NFT> = Trie.empty(); // Store NFTs by ID
        private var nextId: Nat = 1;

        // Helper function to emit events
        private func emitNFTEvent(eventType: EventTypes.EventType, nftId: Nat, details: Text) : async () {
            let event: EventTypes.Event = {
                id = nftId;
                eventType = eventType;
                payload = #WalletEventGeneric({
                    walletId = Nat.toText(nftId);
                    details = details;
                });
            };
            await eventManager.emit(event);
        };

        // Create a new NFT
        public func createNFT(creator: Principal, metadata: Text): async Result.Result<NFT, Text> {
            if (metadata.size() == 0) {
                return #err("Metadata must not be empty.");
            };

            let nftId = nextId;
            nextId += 1;

            let newNFT: NFT = {
                id = nftId;
                creator = creator;
                owner = creator;
                metadata = metadata;
                createdAt = Time.now();
                updatedAt = Time.now();
                isActive = true;
            };

            nfts := Trie.put(nfts, nftId, Nat.equal, newNFT).0;

            await emitNFTEvent(#TokenCreated, nftId, "NFT created by " # Principal.toText(creator));
            #ok(newNFT)
        };

        // Transfer NFT ownership
        public func transferNFT(nftId: Nat, newOwner: Principal): async Result.Result<NFT, Text> {
            switch (Trie.find(nfts, nftId, Nat.equal)) {
                case null { #err("NFT not found."); };
                case (?nft) {
                    if (!nft.isActive) {
                        return #err("NFT is not active.");
                    };
                    let updatedNFT = { nft with owner = newOwner; updatedAt = Time.now() };
                    nfts := Trie.put(nfts, nftId, Nat.equal, updatedNFT).0;

                    await emitNFTEvent(#TokenMetadataUpdated, nftId, "NFT transferred to " # Principal.toText(newOwner));
                    #ok(updatedNFT)
                };
            }
        };

        // Deactivate an NFT (e.g., remove from marketplace)
        public func deactivateNFT(nftId: Nat): async Result.Result<NFT, Text> {
            switch (Trie.find(nfts, nftId, Nat.equal)) {
                case null { #err("NFT not found."); };
                case (?nft) {
                    if (!nft.isActive) {
                        return #err("NFT is already inactive.");
                    };
                    let updatedNFT = { nft with isActive = false; updatedAt = Time.now() };
                    nfts := Trie.put(nfts, nftId, Nat.equal, updatedNFT).0;

                    await emitNFTEvent(#TokenDeactivated, nftId, "NFT deactivated.");
                    #ok(updatedNFT)
                };
            }
        };

        // Reactivate an NFT
        public func reactivateNFT(nftId: Nat): async Result.Result<NFT, Text> {
            switch (Trie.find(nfts, nftId, Nat.equal)) {
                case null { #err("NFT not found."); };
                case (?nft) {
                    if (nft.isActive) {
                        return #err("NFT is already active.");
                    };
                    let updatedNFT = { nft with isActive = true; updatedAt = Time.now() };
                    nfts := Trie.put(nfts, nftId, Nat.equal, updatedNFT).0;

                    await emitNFTEvent(#TokenReactivated, nftId, "NFT reactivated.");
                    #ok(updatedNFT)
                };
            }
        };

        // Get an NFT by ID
        public func getNFT(nftId: Nat): async Result.Result<NFT, Text> {
            switch (Trie.find(nfts, nftId, Nat.equal)) {
                case null { #err("NFT not found."); };
                case (?nft) { #ok(nft); };
            }
        };

        // Get all NFTs for a specific owner
        public func getNFTsByOwner(owner: Principal): async [NFT] {
            Array.filter<NFT>(
                Trie.toArray(nfts).map<NFT>((kv) => kv.1),
                func(nft: NFT): Bool { nft.owner == owner }
            )
        };

        // Get all NFTs
        public func getAllNFTs(): async [NFT] {
            Trie.toArray(nfts).map<NFT>((kv) => kv.1)
        };
    };
};