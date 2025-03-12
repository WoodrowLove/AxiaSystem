import ValidationUtils "../../utils/validation_utils";
import LoggingUtils "../../utils/logging_utils";
import Sha256 "mo:sha256/SHA256";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Nat8 "mo:base/Nat8";
import _EventTypes "../../heartbeat/event_types";
import EventManager "../../heartbeat/event_manager";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
//import Nat32 "mo:base/Nat32";
//import Hash "mo:base/Hash";


module {
    public type User = {
        id: Principal;
        username: Text;
        email: Text;
        hashedPassword: Text;
        deviceKeys: [Principal];
        createdAt: Int;
        updatedAt: Int;
        icpWallet: ?Text; // Wallet address will be set after wallet creation
        tokens: Trie.Trie<Nat, Nat>;
        isActive: Bool;
    };

    public type UserManagerInterface = {
    createUser: (Text, Text, Text) -> async Result.Result<User, Text>;
    getUserById: (Principal) -> async Result.Result<User, Text>;
    updateUser: (Principal, ?Text, ?Text, ?Text) -> async Result.Result<User, Text>;
    deactivateUser: (Principal) -> async Result.Result<(), Text>;
    reactivateUser: (Principal) -> async Result.Result<(), Text>;
    deleteUser: (Principal) -> async Result.Result<(), Text>;
    listAllUsers: Bool -> async Result.Result<[User], Text>;
    resetPassword: (Principal, Text) -> async Result.Result<User, Text>;
    attachTokensToUser: (Principal, Nat, Nat) -> async Result.Result<(), Text>;
    isUserRegistered: (Principal) -> async Bool; 
    
};

    public class UserManager(eventManager: EventManager.EventManager) : UserManagerInterface {
        private let logStore = LoggingUtils.init();
        private var users : Trie.Trie<Principal, User> = Trie.empty();

        
        func customNatHash(n : Nat) : Hash.Hash {
    let hashValue = Nat32.fromNat(n);
    hashValue ^ (hashValue >> 16)
};


private func keyPrincipal(p: Principal): Trie.Key<Principal> = {
    key = p;
    hash = Principal.hash(p);
};

// func key(n: Nat) : Trie.Key<Nat> = { key = n; hash = customNatHash(n) };


        public func registerDevice(userId: Principal, newDeviceKey: Principal): async Result.Result<(), Text> {
    var updatedUser: ?User = null;

    users := Trie.mapFilter(users, func(k: Principal, v: User) : ?User {
        if (k == userId) {
            // Check if the device key already exists
            let keyExists = Array.find(v.deviceKeys, func(key: Principal) : Bool {
                key == newDeviceKey
            });
            
            switch (keyExists) {
                case (null) {
                    // Key doesn't exist, so update the user
                    let updated = {
                        v with
                        deviceKeys = Array.append(v.deviceKeys, [newDeviceKey]);
                        updatedAt = Time.now();
                    };
                    updatedUser := ?updated;
                    ?updated
                };
                case (_) {
                    // Key already exists; no changes needed
                    ?v
                };
            };
        } else {
            ?v
        }
    });

    switch updatedUser {
        case null {
            // If the user is not found or the key already exists, return an error
            #err("User not found or device key already exists.")
        };
        case (?_) {
            // Emit the event after successfully registering the device
            await eventManager.emitDeviceRegistered(userId, newDeviceKey);

            // Return success
            #ok(())
        };
    }
};

        /// Function to create a new user
        public func createUser(username: Text, email: Text, password: Text): async Result.Result<User, Text> {
            // Validate email
            if (not ValidationUtils.isValidEmail(email)) {
                return #err("Invalid email format");
            };

            // Check if the user already exists
            switch (findUserByEmail(email)) {
                case (?_) { return #err("User with this email already exists."); };
                case null {};
            };

            // Hash the password
            let hashedPassword = hashPassword(password);

            // Generate a unique identifier using SHA256 and truncate to 27 bytes
            let uniqueInput = username # email # Int.toText(Time.now());
            let inputBlob = Text.encodeUtf8(uniqueInput);
            let hashedArray = Sha256.sha256(Blob.toArray(inputBlob));
            let truncatedHash = Array.subArray<Nat8>(hashedArray, 0, 27);
            let uniqueId = Principal.fromBlob(Blob.fromArray(truncatedHash));

            // Create the user object
            let newUser: User = {
                id = uniqueId;
                username = username;
                email = email;
                hashedPassword = hashedPassword;
                deviceKeys = [];
                createdAt = Time.now();
                updatedAt = Time.now();
                icpWallet = null; // Will be populated when the wallet is created
                tokens = Trie.empty();
                isActive = true;
            };

            // Add the new user to the state
            users := Trie.put(users, keyPrincipal(newUser.id), Principal.equal, newUser).0;

            // Log success
            LoggingUtils.logInfo(logStore, "UserModule", "User created successfully: " # username, null);

            // Emit a "UserCreated" event for the wallet canister
            await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #UserCreated;
                payload = #UserCreated({
                    UserId = Principal.toText(uniqueId);
                    username = username;
                    email = email;
                });
            });

            return #ok(newUser);
        };

      /// Utility to find a user by email
private func findUserByEmail(email: Text): ?User {
    let userIter = Trie.iter(users);
    let found = Array.find<(Principal, User)>(Iter.toArray(userIter), func((_, user): (Principal, User)): Bool {
        user.email == email
    });
    switch found {
        case (?(_, user)) { ?user };
        case null { null };
    }
};
        /// Utility to hash passwords (simplified)
        private func hashPassword(password: Text): Text {
            return "hashed_" # password;
        };

        public func validateLogin(principal: ?Principal, email: ?Text, password: ?Text): async Result.Result<User, Text> {
    // Check if logging in via Principal (Internet Identity)
    switch principal {
        case (?p) {
            let userOpt = Trie.find(users, keyPrincipal(p), Principal.equal);
            switch userOpt {
                case null {
                    // Emit login failure before returning
                    await eventManager.emitLoginFailure(?p, null, "Principal not recognized.");
                    #err("Login failed: Principal not recognized.");
                };
                case (?user) {
                    if (Array.find(user.deviceKeys, func(key: Principal) : Bool { key == p }) != null) {
                        // Emit login success before returning
                        await eventManager.emitLoginSuccess(user.id, ?p, null);
                        #ok(user);
                    } else {
                        await eventManager.emitLoginFailure(?p, null, "Principal not associated with user.");
                        #err("Login failed: Principal not associated with user.");
                    };
                };
            };
        };
        case null {
           // Fallback: Validate login via email and password
switch (email, password) {
    case (?e, ?p) {
        let userIter = Trie.iter(users);
        let userArray = Iter.toArray(userIter);
        let userOpt = Array.find(userArray, func((_, user): (Principal, User)) : Bool {
            user.email == e and user.hashedPassword == hashPassword(p)
        });
                    switch userOpt {
                        case null {
                            // Emit login failure before returning
                            await eventManager.emitLoginFailure(null, ?e, "Invalid email or password.");
                            #err("Login failed: Invalid email or password.");
                        };
                        case (?(_, user)) {
                            // Emit login success before returning
                            await eventManager.emitLoginSuccess(user.id, null, ?e);
                            #ok(user);
                        };
                    };
                };
                case _ {
                    // Emit login failure before returning
                    await eventManager.emitLoginFailure(null, null, "Missing credentials.");
                    #err("Login failed: Missing credentials.");
                };
            };
        };
    }
};

    public func getUserById(userId: Principal): async Result.Result<User, Text> {
    let userKey = { hash = Principal.hash(userId); key = userId };
    let userOpt = Trie.get(users, userKey, Principal.equal);

    switch userOpt {
        case (?user) { #ok(user) };
        case null { #err("User not found.") };
    };
};

public func getSlimUserById(userId: Principal) : async Result.Result<{ 
  id: Principal;
  username: Text;
  email: Text;
  createdAt: Int;
  updatedAt: Int;
  isActive: Bool;
}, Text> {
  let userResult = await getUserById(userId);
  
  switch userResult {
    case (#ok(user)) {
      #ok({
        id = user.id;
        username = user.username;
        email = user.email;
        createdAt = user.createdAt;
        updatedAt = user.updatedAt;
        isActive = user.isActive;
      })
    };
    case (#err(e)) #err(e);
  }
};

/// Function to update an existing user's details
public func updateUser(userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text): async Result.Result<User, Text> {
    let userKey = { hash = Principal.hash(userId); key = userId };
    let userOpt = Trie.find(users, userKey, Principal.equal);

    switch userOpt {
    case null {
        return #err("User not found.");
    };
    case (?user) {
        if (newEmail != null and not ValidationUtils.isValidEmail(switch newEmail { 
            case (null) { "" }; 
            case (?email) { email }; 
        })) {
            return #err("Invalid email format.");
        };

        let updatedUser: User = {
            id = user.id;
            username = switch newUsername { case null { user.username }; case (?u) { u }; };
            email = switch newEmail { case null { user.email }; case (?e) { e }; };
            hashedPassword = switch newPassword { case null { user.hashedPassword }; case (?p) { hashPassword(p) }; };
            deviceKeys = user.deviceKeys;
            createdAt = user.createdAt;
            updatedAt = Time.now();
            icpWallet = user.icpWallet;
            tokens = user.tokens;
            isActive = user.isActive;
        };

        users := Trie.replace(
            users,
            userKey,
            Principal.equal,
            ?updatedUser
        ).0;

        LoggingUtils.logInfo(logStore, "UserModule", "User updated successfully: " # Principal.toText(userId), null);

        let emitResult = await eventManager.emitUserUpdated(userId, newUsername, newEmail);
        switch emitResult {
            case (#ok(())) {
                Debug.print("User updated and UserUpdated event emitted successfully.");
            };
            case (#err(e)) {
                Debug.print("User updated, but failed to emit UserUpdated event: " # e);
            };
        };

        return #ok(updatedUser);
    };
};
};

/// Function to attach tokens to a user
public func attachTokensToUser(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
    Debug.print("🔍 Received attachTokensToUser request.");
    Debug.print("🔍 Looking for user: " # Principal.toText(userId));
    Debug.print("🔍 Current users Trie: " # debug_show(users));

    let userOpt = Trie.get(users, { key = userId; hash = Principal.hash(userId) }, Principal.equal);
    
    switch (userOpt) {
        case (null) {
            Debug.print("❌ User not found in Trie.");
            return #err("User not found.");
        };
        case (?user) {
            Debug.print("✅ Found user: " # user.username);
            Debug.print("🔍 Existing token balances: " # debug_show(user.tokens));

            let currentBalanceOpt = Trie.get(user.tokens, { key = tokenId; hash = customNatHash(tokenId) }, Nat.equal);
            let newBalance = switch currentBalanceOpt {
                case null amount;
                case (?balance) balance + amount;
            };

            let (updatedTokens, _) = Trie.put(
                user.tokens,
                { key = tokenId; hash = customNatHash(tokenId) },
                Nat.equal,
                newBalance
            );

            let updatedUser = { user with tokens = updatedTokens; updatedAt = Time.now() };

            users := Trie.replace(
                users,
                { key = userId; hash = Principal.hash(userId) },
                Principal.equal,
                ?updatedUser
            ).0;

            Debug.print("✅ Updated user token balances: " # debug_show(updatedUser.tokens));

            return #ok(());
        };
    };
};

/// Function to deactivate a user
public func deactivateUser(userId: Principal): async Result.Result<(), Text> {
    let userKey = { hash = Principal.hash(userId); key = userId };
    let userOpt = Trie.find(users, userKey, Principal.equal);

    switch userOpt {
        case (null) {
            // If the user is not found, return an error
            return #err("User not found.");
        };
        case (?user) {
            // If the user is found, update their isActive field to false
            let updatedUser = { user with isActive = false; updatedAt = Time.now() };
            // Replace the user in the Trie
            users := Trie.replace(
                users,
                userKey,
                Principal.equal,
                ?updatedUser
            ).0;

            // Emit a "UserDeactivated" event
            await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #UserDeactivated;
                payload = #UserDeactivated({
                    UserId = Principal.toText(userId);
                });
            });

            // Return success
            return #ok(());
        };
    };
};

 /// Function to reactivate a user
public func reactivateUser(userId: Principal): async Result.Result<(), Text> {
    let userKey = { hash = Principal.hash(userId); key = userId };
    let userOpt = Trie.find(users, userKey, Principal.equal);

    switch userOpt {
        case (null) {
            // If the user is not found, return an error
            return #err("User not found.");
        };
        case (?user) {
            if (user.isActive) {
                // If the user is already active, return an error
                return #err("User is already active.");
            };

            // If the user is found, update their isActive field to true
            let updatedUser = { user with isActive = true; updatedAt = Time.now() };

            // Replace the user in the Trie
            users := Trie.replace(
                users,
                userKey,
                Principal.equal,
                ?updatedUser
            ).0;

            // Emit a "UserReactivated" event
            await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #UserReactivated;
                payload = #UserReactivated({
                    UserId = Principal.toText(userId);
                });
            });

            // Return success
            return #ok(());
        };
    };
};

    /// Function to delete a user
public func deleteUser(userId: Principal): async Result.Result<(), Text> {
    let userKey = { hash = Principal.hash(userId); key = userId };
    let (newUsers, removedUser) = Trie.remove(users, userKey, Principal.equal);

    switch (removedUser) {
        case null {
            // If the user is not found, return an error
            return #err("User not found.");
        };
        case (?user) {
            // Update the users Trie
            users := newUsers;

            // Emit a "UserDeleted" event
            await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #UserDeleted;
                payload = #UserDeleted({
                    UserId = Principal.toText(userId);
                });
            });

            // Log success
            LoggingUtils.logInfo(logStore, "UserModule", "User deleted successfully: " # Principal.toText(userId), null);

            // Return success
            return #ok(());
        };
    };
};


/// Function to list all users
public func listAllUsers(includeInactive: Bool): async Result.Result<[User], Text> {
    let userIter = Trie.iter(users);
    let userArray = Iter.toArray(userIter);
    
    if (includeInactive) {
        return #ok(Array.map(userArray, func((_, user): (Principal, User)): User { user }));
    } else {
        let activeUsers = Array.filter(userArray, func((_, user): (Principal, User)): Bool {
            user.isActive
        });
        return #ok(Array.map(activeUsers, func((_, user): (Principal, User)): User { user }));
    };
};

/// Function to reset a user's password
public func resetPassword(userId: Principal, newPassword: Text): async Result.Result<User, Text> {
    let userKey = { hash = Principal.hash(userId); key = userId };
    let userOpt = Trie.find(users, userKey, Principal.equal);

    switch userOpt {
        case null {
            // If the user is not found, return an error
            return #err("User not found.");
        };
        case (?user) {
            // Hash the new password
            let hashedPassword = hashPassword(newPassword);

            // Update the user's password and `updatedAt` timestamp
            let updatedUser = { user with hashedPassword = hashedPassword; updatedAt = Time.now() };

            // Replace the user in the Trie
            users := Trie.replace(
                users,
                userKey,
                Principal.equal,
                ?updatedUser
            ).0;

            // Emit a "PasswordReset" event
            await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #PasswordReset;
                payload = #PasswordReset({
                    UserId = Principal.toText(userId);
                });
            });

            // Log success
            LoggingUtils.logInfo(logStore, "UserModule", "Password reset successfully for user: " # Principal.toText(userId), null);

            // Return the updated user
            return #ok(updatedUser);
        };
    };
};

 public func isUserRegistered(userId: Principal): async Bool {
            Debug.print("🔍 Checking if user is registered: " # Principal.toText(userId));

            let userOpt = Trie.get(users, { key = userId; hash = Principal.hash(userId) }, Principal.equal);

            switch userOpt {
                case (null) {
                    Debug.print("❌ User not found: " # Principal.toText(userId));
                    return false;
                };
                case (?_) {
                    Debug.print("✅ User is registered: " # Principal.toText(userId));
                    return true;
                };
            };
        };

};
};