import TokenModule "../modules/token_module";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";


module {
    // Create Token
    public func createToken(
    tokenManager: TokenModule.TokenManager,
    name: Text,
    symbol: Text,
    totalSupply: Nat,
    decimals: Nat,
    owner: Principal
): async Result.Result<TokenModule.Token, Text> {
    if (ValidationUtils.isValidTokenName(name)) {
        return #err("Invalid token name: Must be non-empty.");
    };
    if (ValidationUtils.isValidTokenSymbol(symbol)) {
        return #err("Invalid token symbol: Must be 1-5 characters.");
    };
    if (ValidationUtils.isValidTotalSupply(totalSupply)) {
        return #err("Total supply must be greater than 0.");
    };
    if (ValidationUtils.isValidDecimals(decimals)) {
        return #err("Invalid decimals: Must be between 0 and 18.");
    };

    let result = await tokenManager.createToken(name, symbol, totalSupply, decimals, owner);

    switch (result) {
        case (#err(e)) {
            tokenManager.logError("TokenizationService", "Failed to create token: " # e, null);
            return #err(e);
        };
        case (#ok(token)) {
            TokenEvents.addEvent(
                token.id,
                #Creation,
                "Token created successfully: " # token.name,
                ?owner
            );
            tokenManager.logInfo("TokenizationService", "Token created successfully: ID " # Nat.toText(token.id), ?owner);
            return #ok(token);
        };
    };
};

    // Retrieve Token
    public func getToken(
        tokenManager: TokenModule.TokenManager,
        tokenId: Nat
    ): Result.Result<TokenModule.Token, Text> {
        tokenManager.logInfo("TokenizationService", "Retrieving token ID: " # Nat.toText(tokenId), null);
        tokenManager.getToken(tokenId)
    };

    // Update Token Metadata
    public func updateTokenMetadata(
    tokenManager: TokenModule.TokenManager,
    tokenId: Nat,
    newName: Text,
    newSymbol: Text,
    caller: Principal
): async Result.Result<TokenModule.Token, Text> {
    if (ValidationUtils.isValidTokenName(newName)) {
        return #err("Invalid token name: Must be non-empty.");
    };
    if (ValidationUtils.isValidTokenSymbol(newSymbol)) {
        return #err("Invalid token symbol: Must be 1-5 characters.");
    };

    let result = await tokenManager.updateTokenMetadata(tokenId, newName, newSymbol, caller);

    switch (result) {
        case (#err(e)) {
            tokenManager.logError("TokenizationService", "Failed to update metadata: " # e, ?caller);
            return #err(e);
        };
        case (#ok(updatedToken)) {
            TokenEvents.addEvent(
                tokenId,
                #MetadataUpdate,
                "Metadata updated: Name = " # newName # ", Symbol = " # newSymbol,
                ?caller
            );
            tokenManager.logInfo("TokenizationService", "Metadata updated successfully for Token ID: " # Nat.toText(tokenId), ?caller);
            return #ok(updatedToken);
        };
    };
};
    // Deactivate Token
    public func deactivateToken(
        tokenManager: TokenModule.TokenManager,
        tokenId: Nat,
        caller: Principal
    ): async Result.Result<TokenModule.Token, Text> {
        tokenManager.logInfo("TokenizationService", "Deactivating token ID: " # Nat.toText(tokenId), ?caller);
        await tokenManager.deactivateToken(tokenId, caller)
    };

    // Get Event Log
    public func getEventLog(
        tokenManager: TokenModule.TokenManager
    ): [Text] {
        tokenManager.logInfo("TokenizationService", "Retrieving event log", null);
        tokenManager.getEventLog()
    };

    // Retrieve All Tokens
    public func getAllTokens(
        tokenManager: TokenModule.TokenManager
    ): [TokenModule.Token] {
        tokenManager.logInfo("TokenizationService", "Retrieving all tokens", null);
        tokenManager.getAllTokens()
    };

    // **New Functions**

    // Lock Tokens for XRPL Bridging
    public func lockTokens(
    tokenManager: TokenModule.TokenManager,
    tokenId: Nat,
    amount: Nat,
    lockedBy: Principal
): async Result.Result<(), Text> {
    let result = await tokenManager.lockTokens(tokenId, amount, lockedBy);

    switch (result) {
        case (#err(e)) {
            tokenManager.logError("TokenizationService", "Failed to lock tokens: " # e, ?lockedBy);
            return #err(e);
        };
        case (#ok(_)) {
            TokenEvents.addEvent(
                tokenId,
                #Locking,
                "Locked " # Nat.toText(amount) # " tokens for bridging.",
                ?lockedBy
            );
            tokenManager.logInfo("TokenizationService", "Tokens locked successfully for Token ID: " # Nat.toText(tokenId), ?lockedBy);
            return #ok(());
        };
    };
};

    // Release Locked Tokens
    public func releaseLockedTokens(
    tokenManager: TokenModule.TokenManager,
    tokenId: Nat
): async Result.Result<(), Text> {
    let result = await tokenManager.releaseLockedTokens(tokenId);

    switch (result) {
        case (#err(e)) {
            tokenManager.logError("TokenizationService", "Failed to release locked tokens: " # e, null);
            return #err(e);
        };
        case (#ok(_)) {
            TokenEvents.addEvent(
                tokenId,
                #Unlocking,
                "Released locked tokens for bridging.",
                null
            );
            tokenManager.logInfo("TokenizationService", "Locked tokens released successfully for Token ID: " # Nat.toText(tokenId), null);
            return #ok(());
        };
    };
};

    /* Associate XRPL Metadata with a Token
    public func associateXRPLMetadata(
        tokenManager: TokenModule.TokenManager,
        tokenId: Nat,
        xrplTokenAddress: Text
    ): async Result.Result<(), Text> {
        tokenManager.logInfo("TokenizationService", "Associating XRPL metadata with Token ID: " # Nat.toText(tokenId), null);
        let metadata = {
            xrplTokenAddress = xrplTokenAddress;
            isBridged = true;
        };
        await tokenManager.associateXRPLMetadata(tokenId, metadata)
    };

    // Retrieve XRPL Metadata
    public func getXRPLMetadata(
        tokenManager: TokenModule.TokenManager,
        tokenId: Nat
    ): async Result.Result<TokenModule.XRPLMetadata, Text> {
        tokenManager.logInfo("TokenizationService", "Retrieving XRPL metadata for Token ID: " # Nat.toText(tokenId), null);
        tokenManager.getXRPLMetadata(tokenId)
    };*/

// Mint tokens
public func mintTokens(
    tokenManager: TokenModule.TokenManager,
    tokenId: Nat,
    amount: Nat,
    caller: Principal
): async Result.Result<(), Text> {
    let result = await tokenManager.mintToken(tokenId, amount, ?caller);

    switch (result) {
        case (#err(e)) {
            tokenManager.logError("TokenizationService", "Minting failed: " # e, ?caller);
            return #err(e);
        };
        case (#ok(_)) {
            TokenEvents.addEvent(
                tokenId,
                #Minting,
                "Minted " # Nat.toText(amount) # " tokens.",
                ?caller
            );
            tokenManager.logInfo("TokenizationService", "Minted " # Nat.toText(amount) # " tokens for Token ID: " # Nat.toText(tokenId), ?caller);
            return #ok(());
        };
    };
};

// Burn tokens
public func burnTokens(
    tokenManager: TokenModule.TokenManager,
    tokenId: Nat,
    amount: Nat,
    caller: Principal
): async Result.Result<(), Text> {
    let result = await tokenManager.burnToken(tokenId, amount);

    switch (result) {
        case (#err(e)) {
            tokenManager.logError("TokenizationService", "Burning failed: " # e, ?caller);
            return #err(e);
        };
        case (#ok(_)) {
            TokenEvents.addEvent(
                tokenId,
                #Burning,
                "Burned " # Nat.toText(amount) # " tokens.",
                ?caller
            );
            tokenManager.logInfo("TokenizationService", "Burned " # Nat.toText(amount) # " tokens for Token ID: " # Nat.toText(tokenId), ?caller);
            return #ok(());
        };
    };
};

    public func attachTokensToUser(
  tokenManager: TokenModule.TokenManager,
  tokenId: Nat,
  userId: Principal,
  amount: Nat
): async Result.Result<(), Text> {
  tokenManager.logInfo(
    "TokenService",
    "Attaching " # Nat.toText(amount) # " tokens to user " # Principal.toText(userId) # " for token ID: " # Nat.toText(tokenId),
    null
  );

  await tokenManager.attachTokensToUser(tokenId, userId, amount);
};

};


