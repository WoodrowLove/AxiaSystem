import TokenModule "./modules/token_module";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import EventManager "../heartbeat/event_manager";
import UserCanisterProxy "../user/utils/user_canister_proxy";

// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";
import Time "mo:base/Time";
import Debug "mo:base/Debug";

persistent actor TokenActor {

    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        let _insight : Insight.SystemInsight = {
            source = "token";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 TOKEN INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };

     private transient let eventManager = EventManager.EventManager();  // Ensure this matches expected type
    private transient let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("xobql-2x777-77774-qaaja-cai"));
    private transient let tokenManager = TokenModule.TokenManager(eventManager, userProxy); // Pass both

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
    public shared func mintTokens(
        tokenId: Nat,
        amount: Nat,
        caller: Principal
    ): async Result.Result<(), Text> {
        await tokenManager.mintTokens(tokenId, amount, ?caller);
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


    // Mint tokens to a specific user
    public shared func mintToUser(tokenId: Nat, userId: Principal, amount: Nat): async Result.Result<(), Text> {
        await emitInsight("info", "Minting " # Nat.toText(amount) # " tokens of ID " # Nat.toText(tokenId) # " to user " # Principal.toText(userId));
        
        let result = await tokenManager.mintToUser(tokenId, userId, amount);
        
        switch (result) {
            case (#ok(())) {
                await emitInsight("info", "Successfully minted tokens to user");
            };
            case (#err(error)) {
                await emitInsight("error", "Token minting failed: " # error);
            };
        };
        
        result
    };

    // Get balance of a specific user for a specific token  
    public func getBalanceOf(tokenId: Nat, userId: Principal): async Result.Result<Nat, Text> {
        tokenManager.getBalanceOf(tokenId, userId)
    };

    // Get all token balances for a specific user
    public func getBalancesForUser(userId: Principal): async [(Nat, Nat)] {
        tokenManager.getBalancesForUser(userId)
    };

    // Attach tokens to user (balance-only, no supply change)
    public shared func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat): async Result.Result<(), Text> {
        await emitInsight("info", "Attaching " # Nat.toText(amount) # " tokens of ID " # Nat.toText(tokenId) # " to user " # Principal.toText(userId));
        
        let result = await tokenManager.attachTokensToUser(tokenId, userId, amount);
        
        switch (result) {
            case (#ok(())) {
                await emitInsight("info", "Successfully attached tokens to user");
            };
            case (#err(error)) {
                await emitInsight("error", "Token attachment failed: " # error);
            };
        };
        
        result
    };}