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
        
        let result = await userManager.createUser(username, email, password);
        
        switch (result) {
            case (#ok(user)) {
                await emitInsight("info", "User successfully created with ID: " # Principal.toText(user.id) # ", username: " # username);
            };
            case (#err(error)) {
                await emitInsight("error", "User creation failed for username: " # username # " - " # error);
            };
        };
        
        result
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

};