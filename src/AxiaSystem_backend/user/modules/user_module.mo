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

module {
    public type User = {
        id: Principal;
        username: Text;
        email: Text;
        hashedPassword: Text;
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
};

    public class UserManager(eventManager: EventManager.EventManager) : UserManagerInterface {
        private var users: [User] = [];
        private let logStore = LoggingUtils.init();

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
                createdAt = Time.now();
                updatedAt = Time.now();
                icpWallet = null; // Will be populated when the wallet is created
                tokens = Trie.empty();
                isActive = true;
            };

            // Add the new user to the state
            users := Array.append(users, [newUser]);

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
            Array.find<User>(users, func(user: User): Bool { user.email == email });
        };

        /// Utility to hash passwords (simplified)
        private func hashPassword(password: Text): Text {
            return "hashed_" # password;
        };

        /// Function to get a user by ID
public func getUserById(userId: Principal): async Result.Result<User, Text> {
    // Attempt to find the user by ID
    let userOpt = Array.find<User>(users, func(user: User): Bool { user.id == userId });

    // Return the result as a `Result` type
    switch userOpt {
        case (null) {
            return #err("User not found.");
        };
        case (?user) {
            return #ok(user);
        };
    };
};

/// Function to update an existing user's details
public func updateUser(userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text): async Result.Result<User, Text> {
    let userOpt = Array.find<User>(users, func(user: User): Bool { user.id == userId });

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
                createdAt = user.createdAt;
                updatedAt = Time.now();
                icpWallet = user.icpWallet;
                tokens = user.tokens;
                isActive = user.isActive;
            };

            users := Array.map<User, User>(users, func(existingUser: User): User {
                if (existingUser.id == userId) {
                    updatedUser
                } else {
                    existingUser
                }
            });

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

/// Function to deactivate a user
public func deactivateUser(userId: Principal): async Result.Result<(), Text> {
    // Attempt to find the user by ID
    let userOpt = Array.find<User>(users, func(user: User): Bool { user.id == userId });

    switch userOpt {
        case (null) {
            // If the user is not found, return an error
            return #err("User not found.");
        };
        case (?user) {
            // If the user is found, update their isActive field to false
            let updatedUser = { user with isActive = false; updatedAt = Time.now() };
            // Replace the user in the users array
            users := Array.map<User, User>(users, func(existingUser: User): User {
                if (existingUser.id == userId) {
                    updatedUser;
                } else {
                    existingUser;
                }
            });

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
    // Attempt to find the user by ID
    let userOpt = Array.find<User>(users, func(user: User): Bool { user.id == userId });

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

            // Replace the user in the users array
            users := Array.map<User, User>(users, func(existingUser: User): User {
                if (existingUser.id == userId) {
                    updatedUser;
                } else {
                    existingUser;
                }
            });

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
    // Attempt to find the user by ID
    let userOpt = Array.find<User>(users, func(user: User): Bool { user.id == userId });

    switch userOpt {
        case null {
            // If the user is not found, return an error
            return #err("User not found.");
        };
        case (?user) {
            // Remove the user from the array
            users := Array.filter<User>(users, func(existingUser: User): Bool {
                existingUser.id != userId
            });

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
    if (includeInactive) {
        return #ok(users);
    } else {
        let activeUsers = Array.filter<User>(users, func(user: User): Bool {
            user.isActive
        });
        return #ok(activeUsers);
    };
};

/// Function to reset a user's password
public func resetPassword(userId: Principal, newPassword: Text): async Result.Result<User, Text> {
    // Attempt to find the user by ID
    let userOpt = Array.find<User>(users, func(user: User): Bool { user.id == userId });

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

            // Replace the user in the users array
            users := Array.map<User, User>(users, func(existingUser: User): User {
                if (existingUser.id == userId) {
                    updatedUser;
                } else {
                    existingUser;
                }
            });

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
};
};