import TokenState "../state/token_state";
import ValidationUtils "..../../../../utils/validation_utils";
import ErrorHandling "..../../../../utils/error_handling";
import LoggingUtils "..../../../../utils/logging_utils";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import TokenEvents "../utils/token_events";
import UserModule "../../user/modules/user_module";

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

 public type TokenManagerInterface = {
  createToken : (Text, Text, Nat, Nat, Principal) -> async Result.Result<Token, Text>;
  getToken : (Nat) -> Result.Result<Token, Text>;
  updateTokenMetadata : (Nat, Text, Text, Principal) -> async Result.Result<Token, Text>;
  reactivateToken : (Nat, Principal) -> async Result.Result<Token, Text>; // Updated
  deactivateToken : (Nat, Principal) -> async Result.Result<Token, Text>;
  getEventLog : () -> [Text];
  logInfo : (Text, Text, ?Principal) -> ();
  logError : (Text, Text, ?Principal) -> ();
  getAllTokens : () -> [Token];
  releaseLockedTokens : (Nat) -> async Result.Result<(), Text>;
  attachTokensToUser : (Nat, Principal, Nat) -> async Result.Result<(), Text>;
  burnToken : (Nat, Nat) -> Result.Result<(), Text>;
  isTokenOwner : (Nat, Principal) -> Bool;
  lockTokens : (Nat, Nat, Principal) -> async Result.Result<Nat, Text>;
  logErrorText : (Text, Text, ?Text) -> ();
  logInfoText : (Text, Text, ?Text) -> ();
  mintToken : (Nat, Nat, ?Principal) -> async Result.Result<(), Text>;
  onError : Text -> async ();
  unlockTokens : (Nat, Nat, Principal) -> async Result.Result<Nat, Text>;
};
  public type LogEntry = {
    timestamp: Nat;
    event: Text;
    details: ?Text;
  };

  public class TokenManager() : TokenManagerInterface {
  private let tokenState = TokenState.TokenState();
  private var eventLog: [Text] = [];
  private let logStore = LoggingUtils.init();
  private let tokenEvents = TokenEvents.TokenEvents();
  

public func getToken(tokenId: Nat): Result.Result<Token, Text> {
  let tokenOpt = tokenState.getToken(tokenId);
  
  switch (tokenOpt) {
    case (?token) {
      logInfo("TokenModule", "Token retrieved successfully with ID: " # Nat.toText(tokenId), null);
      #ok(token)
    };
    case null {
      logError("TokenModule", "Token not found with ID: " # Nat.toText(tokenId), null);
      #err("Token not found")
    };
  }
};

public func logInfo(category: Text, message: Text, principal: ?Principal) {
    LoggingUtils.logInfo(logStore, category, message, principal);
  };

public func logError(category: Text, message: Text, principal: ?Principal) {
    LoggingUtils.logError(logStore, category, message, principal);
  };

public func logInfoText(category: Text, message: Text, details: ?Text) {
  LoggingUtils.logInfo(logStore, category, message, null);
  switch (details) {
    case (?d) { LoggingUtils.logInfo(logStore, category, "Details: " # d, null); };
    case null { };
  };
};

public func logErrorText(category: Text, message: Text, details: ?Text) {
  LoggingUtils.logError(logStore, category, message, null);
  switch (details) {
    case (?d) { LoggingUtils.logError(logStore, category, "Details: " # d, null); };
    case null { };
  };
};

 public func getAllTokens(): [Token] {
    tokenState.getAllTokens()
 };

    // Create a new token
    public func createToken(
    name: Text,
    symbol: Text,
    totalSupply: Nat,
    decimals: Nat,
    owner: Principal
): async Result.Result<Token, Text> {
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

    let tokenId = tokenState.getNextTokenId();
    let newToken: Token = {
        id = tokenId;
        name = name;
        symbol = symbol;
        totalSupply = totalSupply;
        decimals = decimals;
        owner = owner;
        isActive = true;
        balances = Trie.empty<Principal, Nat>();
    };

    switch (tokenState.addToken(newToken)) {
    case (#err(e)) { return #err(e); };
    case (#ok(_)) {
        let event = tokenEvents.addEvent(
            tokenId,
            #Creation,
            "Token created successfully: " # name,
            ?owner
        );
        LoggingUtils.logInfo(
            logStore,
            "TokenModule",
            "Token created successfully: ID " # Nat.toText(tokenId) # 
            ", Event ID: " # Nat.toText(event.id),
            ?owner
        );
        // You could do additional processing with the event here
        return #ok(newToken);
    };
};
};

    // Update token metadata (only owner)
    public func updateTokenMetadata(
    tokenId: Nat,
    newName: Text,
    newSymbol: Text,
    caller: Principal
): async Result.Result<Token, Text> {
    switch (tokenState.getToken(tokenId)) {
        case (?token) {
            if (token.owner != caller) {
                return #err("Unauthorized: Only the owner can update metadata.");
            };
            if (ValidationUtils.isValidTokenName(newName)) {
                return #err("Invalid token name.");
            };
            if (ValidationUtils.isValidTokenSymbol(newSymbol)) {
                return #err("Invalid token symbol.");
            };

            let updatedToken = { token with name = newName; symbol = newSymbol };
            switch (tokenState.updateToken(updatedToken)) {
                case (#err(e)) { return #err(e); };
                case (#ok(_)) {
                    let _event = tokenEvents.addEvent(
                        tokenId,
                        #MetadataUpdate,
                        "Metadata updated: Name = " # newName # ", Symbol = " # newSymbol,
                        ?caller
                    );
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenModule",
                        "Token metadata updated for ID: " # Nat.toText(tokenId),
                        ?caller
                    );
                    return #ok(updatedToken);
                };
            };
        };
        case null {
            return #err("Token not found: ID " # Nat.toText(tokenId));
        };
    };
};

    // Deactivate token (only owner)
    public func deactivateToken(
    tokenId: Nat,
    caller: Principal
): async Result.Result<Token, Text> {
    switch (tokenState.getToken(tokenId)) {
        case (?token) {
            if (token.owner != caller) {
                return #err("Unauthorized: Only the owner can deactivate the token.");
            };

            let updatedToken = { token with isActive = false };
            switch (tokenState.updateToken(updatedToken)) {
                case (#err(e)) { return #err(e); };
                case (#ok(_)) {
                    let _event = tokenEvents.addEvent(
                        tokenId,
                        #Deactivation,
                        "Token deactivated by " # Principal.toText(caller),
                        ?caller
                    );
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenModule",
                        "Token " # Nat.toText(tokenId) # " deactivated by " # Principal.toText(caller),
                        ?caller
                    );
                    return #ok(updatedToken);
                };
            };
        };
        case null {
            return #err("Token not found: ID " # Nat.toText(tokenId));
        };
    };
};

// Get event log
public func getEventLog(): [Text] {
  LoggingUtils.logInfo(logStore, "TokenModule", "Event log retrieved", null);
  eventLog
};

// Handle errors
public func onError(err: Text): async () {
  LoggingUtils.logInfo(logStore, "TokenModule", "Error occurred: " # err, null);
  let errorDetail = ErrorHandling.handleInternalError(err);
  ErrorHandling.logError(errorDetail);
};

// Check if a caller is authorized to create tokens
private func _isAuthorizedToCreate(caller: Principal): Bool {
    // Define authorized users (for now, assume only specific Principal is authorized)
    let authorizedUsers = [Principal.fromText("ctiya-peaaa-aaaaa-qaaja-cai")]; // Replace with actual authorized Principal IDs
    Array.find(authorizedUsers, func(user: Principal): Bool { user == caller }) != null
};

// Lock tokens on ICP for bridging
public func lockTokens(
    tokenId: Nat,
    amount: Nat,
    owner: Principal
): async Result.Result<Nat, Text> {
    switch (tokenState.getToken(tokenId)) {
        case (?token) {
            if (token.owner != owner) {
                return #err("Unauthorized: Only the owner can lock tokens.");
            };
            if (amount > token.totalSupply) {
                return #err("Insufficient token supply.");
            };

            
            let newSupply = Nat.sub(token.totalSupply, amount);
            let updatedToken = { token with totalSupply = newSupply };
            switch (tokenState.updateToken(updatedToken)) {
                case (#err(e)) { return #err(e); };
                case (#ok(_)) {
                    let _event = tokenEvents.addEvent(
                        tokenId,
                        #Locking,
                        "Locked " # Nat.toText(amount) # " tokens for bridging.",
                        ?owner
                    );
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenModule",
                        "Locked " # Nat.toText(amount) # " tokens for bridging.",
                        ?owner
                    );
                    return #ok(amount);
                };
            };
        };
        case null { return #err("Token not found: ID " # Nat.toText(tokenId)); };
    };
};

/* Generate instructions to mint XRPL tokens
public func mintOnXRPL(tokenId: Nat, amount: Nat, xrplAddress: Text): async Result.Result<(), Text> {
    let tokenOpt = tokenState.getToken(tokenId);

    switch (tokenOpt) {
        case (?token) {
           LoggingUtils.logInfo(
    logStore, 
    "TokenModule", 
    "Minting " # Nat.toText(amount) # " " # token.symbol # " tokens (ID: " # Nat.toText(tokenId) # ") to XRPL address: " # xrplAddress, 
    null
);
            // Call XRPL middleware here with appropriate parameters
            // Placeholder for XRPL middleware call
            return #ok(());
        };
        case null {
            return #err("Token not found.");
        };
    };
}; */

public func unlockTokens(tokenId: Nat, amount: Nat, owner: Principal): async Result.Result<Nat, Text> {
    let tokenOpt = tokenState.getToken(tokenId);

    switch (tokenOpt) {
        case (?token) {
            if (token.owner != owner) {
                return #err("Unauthorized: Only the owner can unlock tokens.");
            };

            if (token.isActive) {
                return #err("Cannot unlock tokens for inactive tokens.");
            };

            let updatedToken = {
                token with
                totalSupply = (token.totalSupply + amount : Nat)
            };

            let updateResult = tokenState.updateToken(updatedToken);
            if (updateResult == #err("Update failed")) {
                return #err("Failed to unlock tokens.");
            };

            LoggingUtils.logInfo(
                logStore, 
                "TokenModule", 
                "Token " # Nat.toText(tokenId) # " unlocked " # Nat.toText(amount) # " tokens by " # Principal.toText(owner), 
                null
            );

            eventLog := Array.append(eventLog, ["Token " # Nat.toText(tokenId) # " unlocked " # Nat.toText(amount) # " tokens."]);

            return #ok(amount);
        };
        case null {
            return #err("Token not found.");
        };
    };
};

public func isTokenOwner(tokenId: Nat, userId: Principal): Bool {
    switch (getToken(tokenId)) {
        case (#ok(token)) token.owner == userId;
        case (#err(_)) false;
    }
};

public func mintToken(
    tokenId: Nat,
    amount: Nat,
    userId: ?Principal
): async Result.Result<(), Text> {
    switch (getToken(tokenId)) {
        case (#err(e)) { return #err(e); };
        case (#ok(token)) {
            let updatedToken = {
    token with 
    totalSupply = token.totalSupply + amount
};
            switch (tokenState.updateToken(updatedToken)) {
                case (#err(e)) { return #err(e); };
                case (#ok(_)) {
                    switch (userId) {
                        case (null) { return #ok(()); };
                        case (?id) {
                            let userManager = UserModule.UserManager();
                            switch (await userManager.attachTokensToUser(tokenId, id, amount, tokenState)) {
                                case (#err(e)) { return #err(e); };
                                case (#ok(_)) { return #ok(()); };
                            };
                        };
                    };
                };
            };
        };
    };
};

public func burnToken(tokenId: Nat, amount: Nat): Result.Result<(), Text> {
    switch (getToken(tokenId)) {
        case (#err(e)) { return #err(e); };
        case (#ok(token)) {
            if (amount > token.totalSupply) {
                return #err("Insufficient token supply to burn.");
            };

            let updatedToken = { token with totalSupply = let newSupply = Nat.sub(token.totalSupply, amount); };
            switch (tokenState.updateToken(updatedToken)) {
                case (#ok(_)) {
                    let _event =tokenEvents.addEvent(
                        tokenId,
                        #Burning,
                        "Burned " # Nat.toText(amount) # " tokens.",
                        null
                    );
                    LoggingUtils.logInfo(
                        logStore,
                        "TokenModule",
                        "Burned " # Nat.toText(amount) # " tokens.",
                        null
                    );
                    return #ok(());
                };
                case (#err(e)) { return #err(e); };
            };
        };
    };
};


public func attachTokensToUser(
  tokenId: Nat,
  userId: Principal,
  amount: Nat
): async Result.Result<(), Text> {
  // Retrieve the token
  switch (tokenState.getToken(tokenId)) {
    case null {
      #err("Token not found: ID " # Nat.toText(tokenId))
    };
    case (?token) {
      if (token.isActive) {
        return #err("Token is not active and cannot be attached to users.");
      };

      // Perform state update
      let updateResult = tokenState.attachTokensToUser(tokenId, userId, amount);
      switch (updateResult) {
        case (#ok(())) {
          LoggingUtils.logInfo(
            logStore,
            "TokenModule",
            "Attached " # Nat.toText(amount) # " tokens to user " # Principal.toText(userId),
            null
          );
          #ok(())
        };
        case (#err(e)) #err("Failed to attach tokens: " # e);
      }
    };
  };
};

public func reactivateToken(tokenId: Nat, caller: Principal): async Result.Result<Token, Text> {
  // Retrieve the token from the state
  switch (tokenState.getToken(tokenId)) {
    case null {
      #err("Token not found: ID " # Nat.toText(tokenId));
    };
    case (?token) {
      // Ensure the caller is authorized to reactivate the token
      if (token.owner != caller) {
        return #err("Unauthorized: Only the token owner can reactivate the token.");
      };

      // Check if the token is already active
      if (token.isActive) {
        return #err("Token is already active.");
      };

      // Reactivate the token
      let updatedToken = { token with isActive = true };
      switch (tokenState.updateToken(updatedToken)) {
        case (#ok(())) {
          // Log the reactivation
          LoggingUtils.logInfo(
            logStore,
            "TokenModule",
            "Token " # Nat.toText(tokenId) # " reactivated by " # Principal.toText(caller),
            null
          );
          #ok(updatedToken)
        };
        case (#err(e)) {
          #err("Failed to reactivate token: " # e);
        };
      };
    };
  };
};

public func releaseLockedTokens(tokenId: Nat): async Result.Result<(), Text> {
    tokenState.releaseLockedTokens(tokenId)
};

  }
}