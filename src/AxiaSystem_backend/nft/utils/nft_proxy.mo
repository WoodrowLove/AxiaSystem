import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";

module {
    public type NFTCanisterInterface = actor {
        createNFT: (Principal, Text) -> async Result.Result<Nat, Text>;
        transferNFT: (Nat, Principal) -> async Result.Result<(), Text>;
        deactivateNFT: (Nat) -> async Result.Result<(), Text>;
        reactivateNFT: (Nat) -> async Result.Result<(), Text>;
        getNFT: (Nat) -> async Result.Result<{ id: Nat; creator: Principal; owner: Principal; metadata: Text; isActive: Bool; createdAt: Int; updatedAt: Int }, Text>;
        getNFTsByOwner: (Principal) -> async [Nat];
        getAllNFTs: () -> async [Nat];
    };

    public class NFTProxy(canisterId: Principal) {
        private let nftCanister: NFTCanisterInterface = actor(Principal.toText(canisterId));

        // Create a new NFT
        public func createNFT(
            creator: Principal,
            metadata: Text
        ): async Result.Result<Nat, Text> {
            await nftCanister.createNFT(creator, metadata);
        };

        // Transfer ownership of an NFT
        public func transferNFT(
            nftId: Nat,
            newOwner: Principal
        ): async Result.Result<(), Text> {
            await nftCanister.transferNFT(nftId, newOwner);
        };

        // Deactivate an NFT
        public func deactivateNFT(
            nftId: Nat
        ): async Result.Result<(), Text> {
            await nftCanister.deactivateNFT(nftId);
        };

        // Reactivate an NFT
        public func reactivateNFT(
            nftId: Nat
        ): async Result.Result<(), Text> {
            await nftCanister.reactivateNFT(nftId);
        };

        // Retrieve an NFT by ID
        public func getNFT(
            nftId: Nat
        ): async Result.Result<{ id: Nat; creator: Principal; owner: Principal; metadata: Text; isActive: Bool; createdAt: Int; updatedAt: Int }, Text> {
            await nftCanister.getNFT(nftId);
        };

        // Retrieve all NFTs for a specific owner
        public func getNFTsByOwner(
            owner: Principal
        ): async [Nat] {
            await nftCanister.getNFTsByOwner(owner);
        };

        // Retrieve all NFTs
        public func getAllNFTs(): async [Nat] {
            await nftCanister.getAllNFTs();
        };
    };
};