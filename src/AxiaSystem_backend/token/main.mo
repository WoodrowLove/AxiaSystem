import TokenModule "./modules/token_module";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import EventManager "../heartbeat/event_manager";
import UserModule "../user/modules/user_module";

actor TokenActor {
     private let eventManager = EventManager.EventManager();  // Ensure this matches expected type
    private let userManager = UserModule.UserManager(eventManager); // Pass eventManager
    private let tokenManager = TokenModule.TokenManager(eventManager, userManager); // Pass both

    // Core Token Operations
    public func createToken(
        name: Text,
        symbol: Text,
        totalSupply: Nat,
        decimals: Nat,
        owner: Principal
    ): async Result.Result<TokenModule.Token, Text> {
        await tokenManager.createToken(name, symbol, totalSupply, decimals, owner);
    };

    public query func getToken(tokenId: Nat): async Result.Result<TokenModule.Token, Text> {
        tokenManager.getToken(tokenId);
    };

    public func updateTokenMetadata(
        tokenId: Nat,
        newName: Text,
        newSymbol: Text,
        caller: Principal
    ): async Result.Result<TokenModule.Token, Text> {
        await tokenManager.updateTokenMetadata(tokenId, newName, newSymbol, caller);
    };

    public func deactivateToken(tokenId: Nat, caller: Principal): async Result.Result<TokenModule.Token, Text> {
        await tokenManager.deactivateToken(tokenId, caller);
    };

    public func reactivateToken(tokenId: Nat, caller: Principal): async Result.Result<TokenModule.Token, Text> {
        await tokenManager.reactivateToken(tokenId, caller);
    };

    public query func getAllTokens(): async [TokenModule.Token] {
        tokenManager.getAllTokens();
    };

    // Minting and Burning
    public func mintTokens(
        tokenId: Nat,
        amount: Nat,
        caller: Principal
    ): async Result.Result<(), Text> {
        await tokenManager.mintToken(tokenId, amount, ?caller);
    };

    public func burnTokens(tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
        tokenManager.burnToken(tokenId, amount);
    };

    // Event and Logging
    public query func getEventLog(): async [Text] {
        tokenManager.getEventLog();
    };

    // Bridging (Optional)
    public func lockTokens(
        tokenId: Nat,
        amount: Nat,
        owner: Principal
    ): async Result.Result<Nat, Text> {
        await tokenManager.lockTokens(tokenId, amount, owner);
    };

    public func releaseLockedTokens(tokenId: Nat): async Result.Result<(), Text> {
        await tokenManager.releaseLockedTokens(tokenId);
    };


    public func attachTokensToUser(
    tokenId: Nat,
    userId: Principal,
    amount: Nat
): async Result.Result<(), Text> {
    await tokenManager.attachTokensToUser(tokenId, userId, amount);
};

}