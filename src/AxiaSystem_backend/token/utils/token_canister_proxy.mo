import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Error "mo:base/Error";

module {
    public type Token = {
        id: Nat;
        name: Text;
        symbol: Text;
        totalSupply: Nat;
        decimals: Nat;
        owner: Principal;
        isActive: Bool;
    };

    public type TokenCanisterInterface = actor {
        getAllTokens: () -> async [Token];
        getToken: (Nat) -> async ?Token;
        updateToken: (Token) -> async Result.Result<(), Text>;
        mintTokens: (Principal, Nat) -> async Result.Result<(), Text>;
        attachTokensToUser: (Nat, Principal, Nat) -> async Result.Result<(), Text>;
    };

    // Proxy class for inter-canister calls
    public class TokenCanisterProxy(canisterId: Principal) {
        private let tokenCanisterProxy: TokenCanisterInterface = actor(Principal.toText(canisterId));

        // Get all tokens
        public func getAllTokens(): async [Token] {
            await tokenCanisterProxy.getAllTokens()
        };

        // Get a specific token by ID
        public func getToken(tokenId: Nat): async ?Token {
            await tokenCanisterProxy.getToken(tokenId)
        };

        // Update a token's metadata
        public func updateToken(updatedToken: Token): async Result.Result<(), Text> {
            try {
                await tokenCanisterProxy.updateToken(updatedToken)
            } catch (error) {
                #err("Failed to update token: " # Error.message(error))
            }
        };

        // Mint new tokens
        public func mintTokens(userId: Principal, amount: Nat): async Result.Result<(), Text> {
            try {
                await tokenCanisterProxy.mintTokens(userId, amount)
            } catch (error) {
                #err("Failed to mint tokens: " # Error.message(error))
            }
        };

        // Attach tokens to a user
        public func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat): async Result.Result<(), Text> {
            try {
                await tokenCanisterProxy.attachTokensToUser(tokenId, userId, amount)
            } catch (error) {
                #err("Failed to attach tokens: " # Error.message(error))
            }
        };
    };
};
