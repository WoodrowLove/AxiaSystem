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

    private let tokenCanister : TokenCanisterInterface = actor("be2us-64aaa-aaaaa-qaabq-cai");


    public func getAllTokens(): async [Token] {
        await tokenCanister.getAllTokens()
    };

    public func getToken(tokenId: Nat): async ?Token {
        await tokenCanister.getToken(tokenId)
    };

    public func updateToken(updatedToken: Token): async Result.Result<(), Text> {
        try {
            await tokenCanister.updateToken(updatedToken)
        } catch (error) {
            #err("Failed to update token: " # Error.message(error))
        }
    };

    public func mintTokens(userId: Principal, amount: Nat): async Result.Result<(), Text> {
        try {
            await tokenCanister.mintTokens(userId, amount)
        } catch (error) {
            #err("Failed to mint tokens: " # Error.message(error))
        }
    };

    public func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat): async Result.Result<(), Text> {
        try {
            await tokenCanister.attachTokensToUser(tokenId, userId, amount)
        } catch (error) {
            #err("Failed to attach tokens: " # Error.message(error))
        }
    };
}
