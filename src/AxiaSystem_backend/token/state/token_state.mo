import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Trie "mo:base/Trie";
import Result "mo:base/Result";
import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import _Array "mo:base/Array";
import LoggingUtils "..../../../../utils/logging_utils";

module {
  public type Token = {
    id: Nat;
    name: Text;
    symbol: Text;
    totalSupply: Nat;
    decimals: Nat;
    owner: Principal;
    isActive: Bool;
    balances: Trie.Trie<Principal, Nat>;
  };

  public type LogEntry = {
  timestamp: Nat;
  event: Text;
  details: ?Text;
};

  public class TokenState() {
    private var tokens: Trie.Trie<Nat, Token> = Trie.empty();
    private var nextTokenId: Nat = 1;
    private let logStore = LoggingUtils.init();
    private var _eventLog: [Text] = [];

    // Get the next available token ID
    public func getNextTokenId(): Nat {
      let tokenId = nextTokenId;
      nextTokenId += 1;
      tokenId
    };

    // Add a new token to the state
    public func addToken(newToken: Token): Result.Result<(), Text> {
      if (Trie.get(tokens, key(newToken.id), Nat.equal) != null) {
        #err("Token already exists")
      } else {
        tokens := Trie.put(tokens, key(newToken.id), Nat.equal, newToken).0;
        #ok(())
      }
    };

    // Retrieve a token by its ID
    public func getToken(tokenId: Nat): ?Token {
      Trie.get(tokens, key(tokenId), Nat.equal)
    };

    // Update an existing token's details
    public func updateToken(updatedToken: Token): Result.Result<(), Text> {
      if (Trie.get(tokens, key(updatedToken.id), Nat.equal) == null) {
        #err("Token not found")
      } else {
        tokens := Trie.put(tokens, key(updatedToken.id), Nat.equal, updatedToken).0;
        #ok(())
      }
    };

// Retrieve all tokens in the system
public func getAllTokens(): [Token] {
  Iter.toArray(Iter.map(Trie.iter(tokens), func ((_: Nat, v: Token)): Token = v))
};
    
    // Remove a token
    public func removeToken(tokenId: Nat): Result.Result<(), Text> {
      if (Trie.get(tokens, key(tokenId), Nat.equal) == null) {
        #err("Token not found")
      } else {
        tokens := Trie.remove(tokens, key(tokenId), Nat.equal).0;
        #ok(())
      }
    };

    // Helper function for creating Trie keys
    private func key(x: Nat): Trie.Key<Nat> = { 
      key = x; 
      hash = customHash(x)
    };

    // Custom hash function for Nat
    private func customHash(n: Nat): Hash.Hash {
      var hash: Nat32 = 5381;
      var i = 0;
      var remaining = n;
      while (i < 8) {
        hash := ((hash << 5) +% hash) +% Nat32.fromNat(remaining % 256);
        remaining /= 256;
        i += 1;
      };
      hash
    };

// Structure to store locked tokens
public type LockedToken = {
    tokenId: Nat;
    amount: Nat;
    lockedBy: Principal;
};

// Stable storage for locked tokens
private var lockedTokens: Trie.Trie<Nat, LockedToken> = Trie.empty();

// Lock tokens for bridging
public func lockTokens(
    tokenId: Nat,
    amount: Nat,
    lockedBy: Principal
): Result.Result<(), Text> {
    let tokenOpt = getToken(tokenId);
    switch (tokenOpt) {
        case null {
            return #err("Token not found: ID " # Nat.toText(tokenId));
        };
        case (?token) {
            if (token.totalSupply < amount) {
                return #err("Insufficient token supply to lock.");
            };

            let lockedToken = {
                tokenId = tokenId;
                amount = amount;
                lockedBy = lockedBy;
            };

            // Update locked tokens
            lockedTokens := Trie.put(lockedTokens, key(tokenId), Nat.equal, lockedToken).0;

            // Update token supply
            let updatedToken = { token with totalSupply = let newSupply = Nat.sub(token.totalSupply, amount); };
            tokens := Trie.put(tokens, key(tokenId), Nat.equal, updatedToken).0;

            LoggingUtils.logInfo(
                logStore,
                "TokenState",
                "Locked " # Nat.toText(amount) # " tokens for bridging: Token ID " # Nat.toText(tokenId),
                ?lockedBy
            );

            return #ok(());
        };
    };
};

// Retrieve locked tokens for a token ID
public func getLockedTokens(tokenId: Nat): ?LockedToken {
    Trie.get(lockedTokens, key(tokenId), Nat.equal)
};

// Release locked tokens (e.g., after XRPL minting is confirmed)
public func releaseLockedTokens(tokenId: Nat): Result.Result<(), Text> {
    let lockedTokenOpt = Trie.get(lockedTokens, key(tokenId), Nat.equal);
    switch (lockedTokenOpt) {
        case null {
            return #err("No locked tokens found for Token ID: " # Nat.toText(tokenId));
        };
        case (?lockedToken) {
            let tokenOpt = getToken(tokenId);
            switch (tokenOpt) {
                case null {
                    return #err("Token not found: ID " # Nat.toText(tokenId));
                };
                case (?token) {
                    // Update token supply
                    let updatedToken = { token with totalSupply = token.totalSupply + lockedToken.amount };
                    tokens := Trie.put(tokens, key(tokenId), Nat.equal, updatedToken).0;

                    // Remove locked token entry
                    lockedTokens := Trie.remove(lockedTokens, key(tokenId), Nat.equal).0;

                    LoggingUtils.logInfo(
                        logStore,
                        "TokenState",
                        "Released " # Nat.toText(lockedToken.amount) # " locked tokens for Token ID " # Nat.toText(tokenId),
                        null
                    );

                    return #ok(());
                };
            };
        };
    };
};

// Log token lock events
public func logTokenLockEvent(tokenId: Nat, amount: Nat, lockedBy: Principal): () {
    let event = "Locked " # Nat.toText(amount) # " tokens for bridging (Token ID: " # Nat.toText(tokenId) # ")";
    let loggingContext = LoggingUtils.init();
    LoggingUtils.logInfo(loggingContext, "TokenState", event, ?lockedBy);
};

/* XRPL Metadata Structure
public type XRPLMetadata = {
    xrplTokenAddress: Text; // XRPL token address
    isBridged: Bool;        // Indicates whether the token is bridged to XRPL
};

// Storage for XRPL metadata
private var xrplMetadata: Trie.Trie<Nat, XRPLMetadata> = Trie.empty();

// Associate XRPL data with a token
public func associateXRPLMetadata(tokenId: Nat, metadata: XRPLMetadata): Result.Result<(), Text> {
    // Ensure the token exists
    let tokenOpt = Trie.get(tokens, key(tokenId), Nat.equal);
    switch (tokenOpt) {
        case null {
            #err("Token not found");
        };
        case (?_) {
            xrplMetadata := Trie.put(xrplMetadata, key(tokenId), Nat.equal, metadata).0;
            #ok(());
        };
    };
};

// Retrieve XRPL metadata for a token
public func getXRPLMetadata(tokenId: Nat): ?XRPLMetadata {
    Trie.get(xrplMetadata, key(tokenId), Nat.equal)
};*/

 public func updateTokenMetadata(
    tokenId: Nat,
    newName: Text,
    newSymbol: Text,
    caller: Principal
): async Result.Result<Token, Text> {
    let tokenOpt = getToken(tokenId);
    switch (tokenOpt) {
        case null {
            return #err("Token not found: ID " # Nat.toText(tokenId));
        };
        case (?token) {
            if (token.owner != caller) {
                return #err("Unauthorized: Only the token owner can update metadata.");
            };

            let updatedToken = {
                id = token.id;
                name = newName;
                symbol = newSymbol;
                totalSupply = token.totalSupply;
                decimals = token.decimals;
                owner = token.owner;
                isActive = token.isActive;
                balances = token.balances;
            };

            let updateResult = updateToken(updatedToken);
            switch (updateResult) {
                case (#ok(_)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenState",
                        "Token metadata updated: ID " # Nat.toText(tokenId),
                        null
                    );
                    return #ok(updatedToken);
                };
                case (#err(e)) {
                    return #err("Failed to update token metadata: " # e);
                };
            };
        };
    };
};

         public func deactivateToken(tokenId: Nat): Result.Result<(), Text> {
    let tokenOpt = getToken(tokenId);
    switch (tokenOpt) {
        case null {
            return #err("Token not found: ID " # Nat.toText(tokenId));
        };
        case (?token) {
            let updatedToken = { token with isActive = false };
            switch (updateToken(updatedToken)) {
                case (#ok(_)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenState",
                        "Token deactivated: ID " # Nat.toText(tokenId),
                        null
                    );
                    return #ok(());
                };
                case (#err(e)) {
                    return #err("Failed to deactivate token: " # e);
                };
            };
        };
    };
};

        public func reactivateToken(tokenId: Nat): Result.Result<(), Text> {
    let tokenOpt = getToken(tokenId);
    switch (tokenOpt) {
        case null {
            return #err("Token not found: ID " # Nat.toText(tokenId));
        };
        case (?token) {
            let updatedToken = { token with isActive = true };
            switch (updateToken(updatedToken)) {
                case (#ok(_)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenState",
                        "Token reactivated: ID " # Nat.toText(tokenId),
                        null
                    );
                    return #ok(());
                };
                case (#err(e)) {
                    return #err("Failed to reactivate token: " # e);
                };
            };
        };
    };
};

         public func listAllLockedTokens(): [LockedToken] {
            Iter.toArray(Iter.map(Trie.iter(lockedTokens), func((_: Nat, lockedToken: LockedToken)): LockedToken = lockedToken))
        };

// Increase the total supply for a token
public func mintTokens(tokenId: Nat, amount: Nat): Result.Result<(), Text> {
    switch (getToken(tokenId)) {
        case null {
            #err("Token not found");
        };
        case (?token) {
            let updatedToken = { token with totalSupply = token.totalSupply + amount };
            updateToken(updatedToken);
        };
    }
};

// Mint tokens to a specific user (atomic supply increment + balance update)
public func mintToUser(tokenId: Nat, userId: Principal, amount: Nat): Result.Result<(), Text> {
    switch (getToken(tokenId)) {
        case null {
            LoggingUtils.logError(logStore, "TokenState", "Token not found: ID " # Nat.toText(tokenId), null);
            #err("Token not found: ID " # Nat.toText(tokenId));
        };
        case (?token) {
            // Get current balance of the user
            let currentBalance = Trie.get(token.balances, { key = userId; hash = Principal.hash(userId) }, Principal.equal);
            let newBalance = switch (currentBalance) {
                case null amount;
                case (?balance) balance + amount;
            };

            // Update token balances for the user
            let updatedBalances = Trie.put(
                token.balances,
                { key = userId; hash = Principal.hash(userId) },
                Principal.equal,
                newBalance
            ).0;

            // Atomically update both totalSupply and user balance
            let updatedToken = { 
                token with 
                balances = updatedBalances;
                totalSupply = token.totalSupply + amount;
            };
            
            switch (updateToken(updatedToken)) {
                case (#ok(())) {
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenState",
                        "Minted " # Nat.toText(amount) # " tokens to user " # Principal.toText(userId) # " for token ID " # Nat.toText(tokenId),
                        null
                    );
                    #ok(());
                };
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "TokenState", "Failed to mint tokens to user: " # e, null);
                    #err("Failed to mint tokens to user: " # e);
                };
            };
        };
    };
};

// Decrease the total supply for a token
public func burnToken(tokenId: Nat, amount: Nat): Result.Result<(), Text> {
    switch (getToken(tokenId)) {
        case null {
            #err("Token not found");
        };
        case (?token) {
            if (amount > token.totalSupply) {
                return #err("Insufficient token supply");
            };
            let updatedToken = { token with totalSupply = let newSupply = Nat.sub(token.totalSupply, amount); };
            updateToken(updatedToken);
        };
    }
};

public func attachTokensToUser(
  tokenId: Nat,
  userId: Principal,
  amount: Nat
): Result.Result<(), Text> {
  switch (getToken(tokenId)) {
    case null {
      LoggingUtils.logError(logStore, "TokenState", "Token not found: ID " # Nat.toText(tokenId), null);
      #err("Token not found: ID " # Nat.toText(tokenId));
    };
    case (?token) {
      // Get current balance of the user
      let currentBalance = Trie.get(token.balances, { key = userId; hash = Principal.hash(userId) }, Principal.equal);
      let newBalance = switch (currentBalance) {
        case null amount;
        case (?balance) balance + amount;
      };

      // Update token balances for the user
      let updatedBalances = Trie.put(
        token.balances,
        { key = userId; hash = Principal.hash(userId) },
        Principal.equal,
        newBalance
      ).0;

      // Update the token state - FIXED: Only update balances, NOT totalSupply
      let updatedToken = { 
        token with 
        balances = updatedBalances;
      };
      
      switch (updateToken(updatedToken)) {
        case (#ok(())) {
          LoggingUtils.logInfo(
            logStore,
            "TokenState",
            "Attached " # Nat.toText(amount) # " tokens to user " # Principal.toText(userId) # " for token ID " # Nat.toText(tokenId),
            null
          );
          #ok(());
        };
        case (#err(e)) {
          LoggingUtils.logError(logStore, "TokenState", "Failed to update token state: " # e, null);
          #err("Failed to update token state: " # e);
        };
      };
    };
  };
};

// Get balance of a specific user for a specific token
public func getBalanceOf(tokenId: Nat, userId: Principal): Result.Result<Nat, Text> {
    switch (getToken(tokenId)) {
        case null {
            #err("Token not found: ID " # Nat.toText(tokenId));
        };
        case (?token) {
            let balance = Trie.get(token.balances, { key = userId; hash = Principal.hash(userId) }, Principal.equal);
            switch (balance) {
                case null #ok(0);
                case (?bal) #ok(bal);
            };
        };
    };
};

// Get all token balances for a specific user
public func getBalancesForUser(userId: Principal): [(Nat, Nat)] {
    let allTokens = getAllTokens();
    let userBalances = _Array.mapFilter<Token, (Nat, Nat)>(allTokens, func(token: Token): ?(Nat, Nat) {
        let balance = Trie.get(token.balances, { key = userId; hash = Principal.hash(userId) }, Principal.equal);
        switch (balance) {
            case null null; // User has no balance for this token
            case (?bal) {
                if (bal > 0) {
                    ?(token.id, bal)
                } else {
                    null
                }
            };
        };
    });
    userBalances
};

  };
  
}



/* Enhancements
	1.	Batch Operations:
	•	Add support for bulk operations, such as minting tokens to multiple users or burning tokens from multiple accounts, to improve efficiency in high-volume scenarios.
	2.	Metrics and Analytics:
	•	Introduce methods to calculate system-wide metrics, such as:
	•	Total tokens minted, burned, or locked.
	•	Active/inactive token counts.
	3.	Concurrency and Parallelism:
	•	Consider implementing asynchronous updates for operations like locking/unlocking tokens or updating balances to optimize performance.
	4.	Dynamic Configuration:
	•	Extract constants like nextTokenId or authorized Principals into a centralized configuration module for easier management and updates.
	5.	User Balance Queries:
	•	Add methods to retrieve user-specific balance summaries across all tokens or for specific token filters.
	6.	Role-Based Access Control (RBAC):
	•	Enhance the ownership checks by introducing roles (e.g., administrators, token creators) to delegate specific permissions. */