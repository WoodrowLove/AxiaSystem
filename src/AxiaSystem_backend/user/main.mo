import UserModule "../user/modules/user_module";
import UserService "../user/service/user_service";
import EventManager "../heartbeat/event_manager";
import _EventTypes "../heartbeat/event_types";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Bool "mo:base/Bool";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import UserCanisterProxy "utils/user_canister_proxy";
import Int "mo:base/Int";
import IdentityModule "../identity/modules/identity_module";

// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";

persistent actor UserCanister {

    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        // TODO: Replace with actual NamoraAI canister call when deployed
        let _insight : Insight.SystemInsight = {
            source = "user";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 USER INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };

    private var users : Trie.Trie<Principal, UserModule.User> = Trie.empty();
    // Initialize the event manager
    private transient let eventManager = EventManager.EventManager();
    transient let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("xad5d-bh777-77774-qaaia-cai"));

    // Initialize the user manager with the event manager
    private transient let userManager = UserModule.UserManager(eventManager);

    private transient let userService = UserService.UserService(userManager, eventManager, userProxy);


    /// Attach tokens to a user and persist the update in the Trie
private func _attachTokensToUser(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
    await emitInsight("info", "Token attachment initiated for user: " # Principal.toText(userId) # ", tokenId: " # Nat.toText(tokenId) # ", amount: " # Nat.toText(amount));
    
    // Define Trie keys for Principal and Nat
    func keyPrincipal(p: Principal): Trie.Key<Principal> = { key = p; hash = Principal.hash(p) };
    func keyNat(n: Nat): Trie.Key<Nat> = { key = n; hash = customNatHash(n) };

    // Retrieve user from Trie
    let userOpt = Trie.get(users, keyPrincipal(userId), Principal.equal);
    switch userOpt {
        case null { 
            await emitInsight("error", "Token attachment failed: User not found for ID: " # Principal.toText(userId));
            return #err("User not found."); 
        };
        case (?user) {
            // Retrieve current balance
            let currentBalanceOpt = Trie.get(user.tokens, keyNat(tokenId), Nat.equal);
            let newBalance = switch currentBalanceOpt {
                case null amount;
                case (?balance) balance + amount;
            };

            // Update the token balance for the user
            let updatedTokens = Trie.put(user.tokens, keyNat(tokenId), Nat.equal, newBalance).0;

            // Create the updated user record
            let updatedUser = {
                user with
                tokens = updatedTokens;
                updatedAt = Time.now();
            };

            // Persist the update in the stable Trie
            users := Trie.replace(users, keyPrincipal(userId), Principal.equal, ?updatedUser).0;

            // Emit an event after updating the balance
            await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #TokenAttachedToUser;
                payload = #TokenAttachedToUser({
                    userId = Principal.toText(userId);
                    tokenId = tokenId;
                    amount = amount;
                });
            });

            await emitInsight("info", "Tokens successfully attached to user: " # Principal.toText(userId) # ", tokenId: " # Nat.toText(tokenId) # ", newBalance: " # Nat.toText(newBalance));
            return #ok(());
        };
    };
};

func customNatHash(n : Nat) : Hash.Hash {
    let hashValue = Nat32.fromNat(n);
    hashValue ^ (hashValue >> 16)
};
    

    // Public API: Create a new user
    public shared func createUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
        await emitInsight("info", "User creation attempt initiated for username: " # username);
        
        // Step 1: Create the user record
        let result = await userManager.createUser(username, email, password);
        
        switch (result) {
            case (#ok(user)) {
                await emitInsight("info", "User successfully created with ID: " # Principal.toText(user.id) # ", username: " # username);
                
                // Step 2: Auto-create identity for complete setup
                let identityCanister = actor("uxrrr-q7777-77774-qaaaq-cai") : actor {
                    ensureIdentity: (Principal, ?Text, ?Text) -> async Result.Result<{}, Text>;
                };
                
                let identityResult = await identityCanister.ensureIdentity(user.id, ?username, ?email);
                switch (identityResult) {
                    case (#ok(_)) {
                        await emitInsight("info", "Identity auto-created for user: " # username);
                    };
                    case (#err(identityError)) {
                        await emitInsight("warning", "Identity auto-creation failed for user: " # username # " - " # identityError);
                    };
                };
                
                // Step 3: Auto-create wallet for complete setup
                let walletCanister = actor("umunu-kh777-77774-qaaca-cai") : actor {
                    ensureWallet: (Principal) -> async Result.Result<{}, Text>;
                };
                
                let walletResult = await walletCanister.ensureWallet(user.id);
                switch (walletResult) {
                    case (#ok(_)) {
                        await emitInsight("info", "Wallet auto-created for user: " # username);
                        // TODO: Add wallet linking functionality when UserManager supports it
                    };
                    case (#err(walletError)) {
                        await emitInsight("warning", "Wallet auto-creation failed for user: " # username # " - " # walletError);
                    };
                };
                
                await emitInsight("info", "Complete user setup finished for: " # username # " (User + Identity + Wallet)");
            };
            case (#err(error)) {
                await emitInsight("error", "User creation failed for username: " # username # " - " # error);
            };
        };
        
        result
    };

    // NEW: Complete user registration with identity and wallet creation
    public shared func registerUserComplete(username: Text, email: Text, password: Text): async Result.Result<{user: UserModule.User; hasIdentity: Bool; hasWallet: Bool}, Text> {
        await emitInsight("info", "Complete user registration initiated for username: " # username);
        
        // Step 1: Create the user
        let userResult = await userManager.createUser(username, email, password);
        
        switch (userResult) {
            case (#err(error)) {
                await emitInsight("error", "User creation failed during complete registration: " # error);
                return #err("Failed to create user: " # error);
            };
            case (#ok(user)) {
                await emitInsight("info", "User created, now provisioning identity and wallet for: " # Principal.toText(user.id));
                
                // Step 2: Create identity via direct canister call
                var hasIdentity = false;
                let identityCanister = actor("uxrrr-q7777-77774-qaaaq-cai") : actor {
                    ensureIdentity: (Principal, ?Text, ?Text) -> async Result.Result<{}, Text>;
                };
                
                let identityResult = await identityCanister.ensureIdentity(user.id, ?username, ?email);
                switch (identityResult) {
                    case (#ok(_)) {
                        hasIdentity := true;
                        await emitInsight("info", "Identity created for user: " # username);
                    };
                    case (#err(identityError)) {
                        await emitInsight("warning", "Identity creation failed for user: " # username # " - " # identityError);
                    };
                };
                
                // Step 3: Create wallet via direct canister call
                var hasWallet = false;
                let walletCanister = actor("umunu-kh777-77774-qaaca-cai") : actor {
                    ensureWallet: (Principal) -> async Result.Result<{}, Text>;
                };
                
                let walletResult = await walletCanister.ensureWallet(user.id);
                switch (walletResult) {
                    case (#ok(_)) {
                        hasWallet := true;
                        await emitInsight("info", "Wallet created for user: " # username);
                    };
                    case (#err(walletError)) {
                        await emitInsight("warning", "Wallet creation failed for user: " # username # " - " # walletError);
                    };
                };
                
                await emitInsight("info", "Complete registration finished for: " # username # " (Identity: " # (if hasIdentity "✓" else "✗") # ", Wallet: " # (if hasWallet "✓" else "✗") # ")");
                
                return #ok({
                    user = user;
                    hasIdentity = hasIdentity;
                    hasWallet = hasWallet;
                });
            };
        };
    };

    // Public API: Get user by ID
public shared func getUserById(userId: Principal): async Result.Result<UserModule.User, Text> {
    Debug.print("Main: Handling getUserById request for ID: " # Principal.toText(userId));

    let userResult = await userManager.getUserById(userId);

    switch userResult {
        case (#ok(user)) {
            Debug.print("Main: Found user ID: " # Principal.toText(user.id));
            await emitInsight("info", "User lookup successful for ID: " # Principal.toText(userId));
            return #ok(user);
        };
        case (#err(err)) {
            Debug.print("Main: User not found. Error: " # err);
            await emitInsight("warning", "User lookup failed for ID: " # Principal.toText(userId) # " - " # err);
            return #err(err);
        };
    };
};


    // Public API: Update a user
public shared func updateUser(userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text): async Result.Result<UserModule.User, Text> {
    Debug.print("Main: Handling updateUser request for ID: " # Principal.toText(userId));
    await emitInsight("info", "User update attempt for ID: " # Principal.toText(userId));

    // Delegate to the user manager
    let updateResult = await userManager.updateUser(userId, newUsername, newEmail, newPassword);

    // Log and return the result
    switch updateResult {
        case (#ok(updatedUser)) {
            Debug.print("Main: User updated successfully for ID: " # Principal.toText(updatedUser.id));
            await emitInsight("info", "User profile updated successfully for ID: " # Principal.toText(userId));
            return #ok(updatedUser);
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to update user: " # errMsg);
            await emitInsight("error", "User update failed for ID: " # Principal.toText(userId) # " - " # errMsg);
            return #err(errMsg);
        };
    };
};
    
    // Public API: Deactivate a user
public shared func deactivateUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("Main: Handling deactivateUser request for ID: " # Principal.toText(userId));
    await emitInsight("warning", "User deactivation requested for ID: " # Principal.toText(userId));

    // Delegate to the user manager
    let deactivateResult = await userManager.deactivateUser(userId);

    // Log and return the result
    switch deactivateResult {
        case (#ok(())) {
            Debug.print("Main: User deactivated successfully for ID: " # Principal.toText(userId));
            await emitInsight("warning", "User account deactivated for ID: " # Principal.toText(userId));
            return #ok(());
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to deactivate user: " # errMsg);
            await emitInsight("error", "User deactivation failed for ID: " # Principal.toText(userId) # " - " # errMsg);
            return #err(errMsg);
        };
    };
};

// Public API: Reactivate a user
public shared func reactivateUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("Main: Handling reactivateUser request for ID: " # Principal.toText(userId));

    // Delegate to the user manager
    let reactivateResult = await userManager.reactivateUser(userId);

    // Log and return the result
    switch reactivateResult {
        case (#ok(())) {
            Debug.print("Main: User reactivated successfully for ID: " # Principal.toText(userId));
            return #ok(());
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to reactivate user: " # errMsg);
            return #err(errMsg);
        };
    };
};

// Public API: List all users
public shared func listAllUsers(includeInactive: Bool): async Result.Result<[UserModule.User], Text> {
    Debug.print("Main: Handling listAllUsers request. Include inactive: " # Bool.toText(includeInactive));

    // Delegate to the user service
    let listResult = await userService.listAllUsers(includeInactive);

    // Log and return the result
    switch listResult {
        case (#ok(users)) {
            Debug.print("Main: Retrieved all users. Total: " # Nat.toText(Array.size(users)));
            return #ok(users);
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to retrieve all users: " # errMsg);
            return #err(errMsg);
        };
    };
};

// Public API: Reset user password
public shared func resetPassword(userId: Principal, newPassword: Text): async Result.Result<(), Text> {
    Debug.print("Main: Handling resetPassword request for ID: " # Principal.toText(userId));

    // Delegate to the user service
    let resetResult = await userService.resetPassword(userId, newPassword);

    switch (resetResult) {
        case (#ok(_)) {
            Debug.print("Main: Password reset successfully for ID: " # Principal.toText(userId));
            #ok(())
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to reset password: " # errMsg);
            #err(errMsg)
        };
    }
};

// Public API: Delete a user
public shared func deleteUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("Main: Handling deleteUser request for ID: " # Principal.toText(userId));

    // Delegate to the user manager
    let deleteResult = await userManager.deleteUser(userId);

    // Log and return the result
    switch deleteResult {
        case (#ok(())) {
            Debug.print("Main: User deleted successfully for ID: " # Principal.toText(userId));
            return #ok(());
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to delete user: " # errMsg);
            return #err(errMsg);
        };
    };
};

// Public API: Register a device for a user
public shared func registerDevice(userId: Principal, newDeviceKey: Principal): async Result.Result<(), Text> {
    Debug.print("Main: Handling registerDevice request for User ID: " # Principal.toText(userId));

    // Delegate the logic to the user manager
    let registerResult = await userManager.registerDevice(userId, newDeviceKey);

    // Log and return the result
    switch registerResult {
        case (#ok(())) {
            Debug.print("Main: Device registered successfully for User ID: " # Principal.toText(userId));
            return #ok(());
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to register device for User ID: " # errMsg);
            return #err(errMsg);
        };
    };
};

// Public API: Validate login for a user
public shared func validateLogin(principal: ?Principal, email: ?Text, password: ?Text): async Result.Result<UserModule.User, Text> {
    Debug.print("Main: Handling validateLogin request.");

    // Delegate the validation logic to the user manager
    let validationResult = await userManager.validateLogin(principal, email, password);

    // Log and return the result
    switch validationResult {
        case (#ok(user)) {
            Debug.print("Main: Login validated successfully for User ID: " # Principal.toText(user.id));
            return #ok(user);
        };
        case (#err(errMsg)) {
            Debug.print("Main: Login validation failed: " # errMsg);
            return #err(errMsg);
        };
    };
    
};
public shared func attachTokensToUser(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
    Debug.print("🔄 [main.mo] Forwarding attachTokensToUser request to UserManager.");
    let result = await userManager.attachTokensToUser(userId, tokenId, amount);

    switch result {
        case (#ok(())) {
            Debug.print("✅ [main.mo] Tokens attached successfully.");
            return #ok(());
        };
        case (#err(e)) {
            Debug.print("❌ [main.mo] Failed to attach tokens: " # e);
            return #err("Failed to attach tokens: " # e);
        };
    };
};

 public shared func isUserRegistered(userId: Principal): async Bool {
        Debug.print("🔍 [Main] Checking if user is registered: " # Principal.toText(userId));
        return await userService.isUserRegistered(userId);
    };

    // NEW: Auto-provision identity and wallet
    public shared func ensureIdentityAndWallet(
        userId: Principal, 
        defaultUsername: ?Text, 
        defaultEmail: ?Text
    ): async Result.Result<(UserModule.User, Text), Text> {
        await emitInsight("info", "Auto-provisioning identity and wallet for user: " # Principal.toText(userId));
        
        let result = await userManager.ensureIdentityAndWallet(userId, defaultUsername, defaultEmail);
        
        switch (result) {
            case (#ok((_user, message))) {
                await emitInsight("info", "Auto-provisioning completed: " # message);
            };
            case (#err(error)) {
                await emitInsight("error", "Auto-provisioning failed: " # error);
            };
        };
        
        result
    };

    // NEW: Get user with complete profile including wallet info
    public shared func getUserProfile(userId: Principal): async Result.Result<{user: UserModule.User; walletId: ?Text; hasWallet: Bool}, Text> {
        await emitInsight("info", "Getting complete user profile for: " # Principal.toText(userId));
        
        // Get user record
        let userResult = await userManager.getUserById(userId);
        
        switch (userResult) {
            case (#err(error)) {
                return #err("User not found: " # error);
            };
            case (#ok(user)) {
                // Check if user has a wallet
                let walletCanister = actor("umunu-kh777-77774-qaaca-cai") : actor {
                    getWalletByOwner: (Principal) -> async Result.Result<{id: Int; owner: Principal; balance: Nat}, Text>;
                };
                
                let walletResult = await walletCanister.getWalletByOwner(userId);
                switch (walletResult) {
                    case (#ok(wallet)) {
                        let walletIdText = Int.toText(wallet.id);
                        await emitInsight("info", "Complete profile retrieved for user: " # user.username # " with wallet: " # walletIdText);
                        return #ok({
                            user = user;
                            walletId = ?walletIdText;
                            hasWallet = true;
                        });
                    };
                    case (#err(_)) {
                        await emitInsight("info", "User profile retrieved (no wallet): " # user.username);
                        return #ok({
                            user = user;
                            walletId = null;
                            hasWallet = false;
                        });
                    };
                };
            };
        };
    };

    // NEW: Complete identity verification and lookup system
    public shared func getCompleteUserInfo(userId: Principal): async Result.Result<{
        user: UserModule.User; 
        identity: ?{id: Principal; createdAt: Int; updatedAt: Int; deviceKeys: [Principal]}; 
        wallet: ?{id: Int; balance: Nat}; 
        connections: {identityLinked: Bool; walletLinked: Bool; allLinked: Bool}
    }, Text> {
        await emitInsight("info", "Getting complete system info for user: " # Principal.toText(userId));
        
        // Get user record
        let userResult = await userManager.getUserById(userId);
        
        switch (userResult) {
            case (#err(error)) {
                return #err("User not found: " # error);
            };
            case (#ok(user)) {
                
                // Check identity
                var identityInfo: ?{id: Principal; createdAt: Int; updatedAt: Int; deviceKeys: [Principal]} = null;
                var identityLinked = false;
                
                let identityCanister = actor("uxrrr-q7777-77774-qaaaq-cai") : actor {
                    getIdentity: (Principal) -> async ?IdentityModule.Identity;
                };
                
                let identityResult = await identityCanister.getIdentity(userId);
                switch (identityResult) {
                    case (?identity) {
                        identityLinked := true;
                        identityInfo := ?{
                            id = identity.id;
                            createdAt = identity.createdAt;
                            updatedAt = identity.updatedAt;
                            deviceKeys = identity.deviceKeys;
                        };
                    };
                    case null {
                        identityLinked := false;
                    };
                };
                
                // Check wallet
                var walletInfo: ?{id: Int; balance: Nat} = null;
                var walletLinked = false;
                
                let walletCanister = actor("umunu-kh777-77774-qaaca-cai") : actor {
                    getWalletByOwner: (Principal) -> async Result.Result<{id: Int; owner: Principal; balance: Nat}, Text>;
                };
                
                let walletResult = await walletCanister.getWalletByOwner(userId);
                switch (walletResult) {
                    case (#ok(wallet)) {
                        walletLinked := true;
                        walletInfo := ?{
                            id = wallet.id;
                            balance = wallet.balance;
                        };
                    };
                    case (#err(_)) {
                        walletLinked := false;
                    };
                };
                
                let allLinked = identityLinked and walletLinked;
                
                await emitInsight("info", "Complete system info retrieved for: " # user.username # " (Identity: " # (if identityLinked "✓" else "✗") # ", Wallet: " # (if walletLinked "✓" else "✗") # ")");
                
                return #ok({
                    user = user;
                    identity = identityInfo;
                    wallet = walletInfo;
                    connections = {
                        identityLinked = identityLinked;
                        walletLinked = walletLinked;
                        allLinked = allLinked;
                    };
                });
            };
        };
    };

    // NEW: Find user by username
    public shared func getUserByUsername(username: Text): async Result.Result<UserModule.User, Text> {
        await emitInsight("info", "Looking up user by username: " # username);
        
        // Get all users and find by username
        let usersResult = await userService.listAllUsers(true);
        switch (usersResult) {
            case (#err(error)) {
                return #err("Failed to search users: " # error);
            };
            case (#ok(users)) {
                for (user in users.vals()) {
                    if (user.username == username) {
                        await emitInsight("info", "User found by username: " # username);
                        return #ok(user);
                    };
                };
                return #err("User not found with username: " # username);
            };
        };
    };

};