import TokenModule "../modules/token_module";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import ValidationUtils "../../utils/validation_utils";
import TokenEvents "../utils/token_events";

module {
    public class TokenService(tokenManager: TokenModule.TokenManagerInterface) {
        private let tokenEvents = TokenEvents.TokenEvents();

        // Create a Token
        public func createToken(name: Text, symbol: Text, totalSupply: Nat, decimals: Nat, owner: Principal): async Result.Result<TokenModule.Token, Text> {
            if (not ValidationUtils.isValidTokenName(name)) {
                return #err("Invalid token name: Must be non-empty.");
            };
            if (not ValidationUtils.isValidTokenSymbol(symbol)) {
                return #err("Invalid token symbol: Must be 1-5 characters.");
            };
            if (not ValidationUtils.isValidTotalSupply(totalSupply)) {
                return #err("Total supply must be greater than 0.");
            };
            if (not ValidationUtils.isValidDecimals(decimals)) {
                return #err("Invalid decimals: Must be between 0 and 18.");
            };

            let result = await tokenManager.createToken(name, symbol, totalSupply, decimals, owner);

            switch (result) {
                case (#ok(token)) {
                    ignore tokenEvents.addEvent(
                        token.id,
                        #Creation,
                        "Token created: " # name # " (" # symbol # ")",
                        ?owner
                    );
                };
                case (#err(_)) {};
            };

            result
        };

        // Retrieve a Token
        public func getToken(tokenId: Nat): Result.Result<TokenModule.Token, Text> {
            tokenManager.logInfo("TokenService", "Retrieving token ID: " # Nat.toText(tokenId), null);
            tokenManager.getToken(tokenId)
        };

        // Update Token Metadata
        public func updateTokenMetadata(tokenId: Nat, newName: Text, newSymbol: Text, caller: Principal): async Result.Result<TokenModule.Token, Text> {
            if (not ValidationUtils.isValidTokenName(newName)) {
                return #err("Invalid token name: Must be non-empty.");
            };
            if (not ValidationUtils.isValidTokenSymbol(newSymbol)) {
                return #err("Invalid token symbol: Must be 1-5 characters.");
            };

            let result = await tokenManager.updateTokenMetadata(tokenId, newName, newSymbol, caller);

            switch (result) {
                case (#ok(updatedToken)) {
                    ignore tokenEvents.addEvent(
                        tokenId,
                        #MetadataUpdate,
                        "Metadata updated: Name = " # newName # ", Symbol = " # newSymbol,
                        ?caller
                    );
                    tokenManager.logInfo("TokenService", "Metadata updated for Token ID: " # Nat.toText(tokenId), ?caller);
                    #ok(updatedToken)
                };
                case (#err(e)) {
                    tokenManager.logError("TokenService", "Failed to update metadata: " # e, ?caller);
                    #err(e)
                };
            }
        };

        // Deactivate a Token
        public func deactivateToken(tokenId: Nat, caller: Principal): async Result.Result<TokenModule.Token, Text> {
            tokenManager.logInfo("TokenService", "Deactivating token ID: " # Nat.toText(tokenId), ?caller);
            await tokenManager.deactivateToken(tokenId, caller)
        };

        // Get Event Log
        public func getEventLog(): [Text] {
            tokenManager.logInfo("TokenService", "Retrieving event log", null);
            tokenManager.getEventLog()
        };

        // Retrieve All Tokens
        public func getAllTokens(): [TokenModule.Token] {
            tokenManager.logInfo("TokenService", "Retrieving all tokens", null);
            tokenManager.getAllTokens()
        };

        // Lock Tokens
        public func lockTokens(tokenId: Nat, amount: Nat, lockedBy: Principal): async Result.Result<(), Text> {
            let result = await tokenManager.lockTokens(tokenId, amount, lockedBy);

            switch (result) {
                case (#ok(_)) {
                    ignore tokenEvents.addEvent(
                        tokenId,
                        #Locking,
                        "Locked " # Nat.toText(amount) # " tokens.",
                        ?lockedBy
                    );
                    tokenManager.logInfo("TokenService", "Tokens locked successfully for Token ID: " # Nat.toText(tokenId), ?lockedBy);
                    #ok(())
                };
                case (#err(e)) {
                    tokenManager.logError("TokenService", "Failed to lock tokens: " # e, ?lockedBy);
                    #err(e)
                };
            }
        };

        // Release Locked Tokens
        public func releaseLockedTokens(tokenId: Nat): async Result.Result<(), Text> {
            let result = await tokenManager.releaseLockedTokens(tokenId);

            switch (result) {
                case (#ok(_)) {
                    ignore tokenEvents.addEvent(
                        tokenId,
                        #Unlocking,
                        "Unlocked tokens for Token ID: " # Nat.toText(tokenId),
                        null
                    );
                    tokenManager.logInfo("TokenService", "Tokens unlocked for Token ID: " # Nat.toText(tokenId), null);
                    #ok(())
                };
                case (#err(e)) {
                    tokenManager.logError("TokenService", "Failed to unlock tokens: " # e, null);
                    #err(e)
                };
            }
        };

        // Mint Tokens
        public func mintTokens(tokenId: Nat, amount: Nat, caller: Principal): async Result.Result<(), Text> {
            let result = await tokenManager.mintToken(tokenId, amount, ?caller);

            switch (result) {
                case (#ok(_)) {
                    ignore tokenEvents.addEvent(
                        tokenId,
                        #Minting,
                        "Minted " # Nat.toText(amount) # " tokens.",
                        ?caller
                    );
                    tokenManager.logInfo("TokenService", "Minted " # Nat.toText(amount) # " tokens for Token ID: " # Nat.toText(tokenId), ?caller);
                    #ok(())
                };
                case (#err(e)) {
                    tokenManager.logError("TokenService", "Minting failed: " # e, ?caller);
                    #err(e)
                };
            }
        };

        // Burn Tokens
        public func burnTokens(tokenId: Nat, amount: Nat, caller: Principal): async Result.Result<(), Text> {
            let result = tokenManager.burnToken(tokenId, amount);

            switch (result) {
                case (#ok(_)) {
                    ignore tokenEvents.addEvent(
                        tokenId,
                        #Burning,
                        "Burned " # Nat.toText(amount) # " tokens.",
                        ?caller
                    );
                    tokenManager.logInfo("TokenService", "Burned " # Nat.toText(amount) # " tokens for Token ID: " # Nat.toText(tokenId), ?caller);
                    #ok(())
                };
                case (#err(e)) {
                    tokenManager.logError("TokenService", "Burning failed: " # e, ?caller);
                    #err(e)
                };
            }
        };

        // Attach Tokens to User
        public func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat): async Result.Result<(), Text> {
            tokenManager.logInfo(
                "TokenService",
                "Attaching " # Nat.toText(amount) # " tokens to user " # Principal.toText(userId) # " for token ID: " # Nat.toText(tokenId),
                null
            );
            await tokenManager.attachTokensToUser(tokenId, userId, amount)
        };
    };
};



/* Enhancements
	1.	Batch Operations:
	•	Add support for bulk operations (e.g., minting or attaching tokens to multiple users) for better performance in high-transaction scenarios.
	2.	Role-Based Access Control (RBAC):
	•	Introduce a mechanism to enforce access control for sensitive actions like minting, burning, or deactivating tokens.
	3.	Advanced Querying:
	•	Provide APIs to query tokens or users with filters (e.g., active/inactive tokens, balance thresholds).
	4.	Enhanced Error Context:
	•	Include contextual details in error messages (e.g., operation type, input parameters) for better debugging.
	5.	Asynchronous Event Handling:
	•	Optimize event logging and management by making it asynchronous, reducing the blocking time for high-latency operations.
	6.	Token Lifecycle Events:
	•	Consider adding lifecycle-specific events, such as #Activated or #Destroyed, to track token states more effectively.
	7.	Rate Limiting:
	•	Prevent abuse by introducing rate limits for operations like minting or burning. */