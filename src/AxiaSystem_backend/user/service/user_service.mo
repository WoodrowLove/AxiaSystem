import UserModule "../../user/modules/user_module";
import EventManager "../../heartbeat/event_manager";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import _Nat "mo:base/Nat";
import _Array "mo:base/Array";
import Bool "mo:base/Bool";


module {
    public class UserService(userModule: UserModule.UserManager, eventManager: EventManager.EventManager) {

        // Function to create a user and emit an event
        public func createUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
            // Step 1: Create the user in the module
            let userResult = await userModule.createUser(username, email, password);

            // Step 2: Handle user creation result
            switch userResult {
                case (#ok(user)) {
                    // Emit a UserCreated event
                    let emitResult = await eventManager.emit({
                        id = Nat64.fromIntWrap(Time.now());
                        eventType = #UserCreated;
                        payload = #UserCreated({
                            UserId = Principal.toText(user.id);
                            username = user.username;
                            email = user.email;
                        });
                    });

                    // Check for event emission success/failure
                    switch emitResult {
                        case () {
                            Debug.print("User created and event emitted successfully.");
                            return #ok(user);
                        };
                    };
                };
                case (#err(errMsg)) {
                    Debug.print("User creation failed: " # errMsg);
                    return #err(errMsg);
                };
            };
        };

         // Function to retrieve a user by ID
        public func getUserById(userId: Principal): async Result.Result<UserModule.User, Text> {
            Debug.print("UserService: Handling getUserById request for: " # Principal.toText(userId));

            let userResult = await userModule.getUserById(userId);

            // Return the result as is
            switch userResult {
                case (#ok(user)) {
                    Debug.print("UserService: Found user: " # user.username);
                    return #ok(user);
                };
                case (#err(err)) {
                    Debug.print("UserService: Failed to find user: " # err);
                    return #err(err);
                };
            };
        };

        // Function to update a user and emit an event
public func updateUser(userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text): async Result.Result<UserModule.User, Text> {
    Debug.print("UserService: Handling updateUser request for ID: " # Principal.toText(userId));

    // Step 1: Update the user in the module
    let updateResult = await userModule.updateUser(userId, newUsername, newEmail, newPassword);

    // Step 2: Handle the update result
    switch updateResult {
        case (#ok(updatedUser)) {
            Debug.print("UserService: User updated successfully. Emitting event.");

            // Emit a UserUpdated event
let emitResult = await eventManager.emit({
    id = Nat64.fromIntWrap(Time.now());
    eventType = #UserUpdated;
    payload = #UserUpdated({
        UserId = Principal.toText(updatedUser.id);
        username = switch (newUsername) { case (null) { ?("Unchanged") }; case (?val) { ?val }; };
        email = switch (newEmail) { case (null) { ?("Unchanged") }; case (?val) { ?val }; };
    });
});

            // Check for event emission success/failure
            switch emitResult {
                case () {
                    Debug.print("UserService: User updated and event emitted successfully.");
                    return #ok(updatedUser);
                };
            };
        };
        case (#err(errMsg)) {
            Debug.print("UserService: User update failed: " # errMsg);
            return #err(errMsg);
        };
    };
};

// Function to deactivate a user and emit an event
public func deactivateUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("UserService: Handling deactivateUser request for ID: " # Principal.toText(userId));

    // Step 1: Deactivate the user in the module
    let deactivateResult = await userModule.deactivateUser(userId);

    // Step 2: Handle the deactivation result
    switch deactivateResult {
        case (#ok(())) {
            Debug.print("UserService: User deactivated successfully. Emitting event.");

            // Emit a UserDeactivated event
            let emitResult = await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #UserDeactivated;
                payload = #UserDeactivated({
                    UserId = Principal.toText(userId);
                });
            });

            // Check for event emission success/failure
            switch emitResult {
                case () {
                    Debug.print("UserService: User deactivated and event emitted successfully.");
                    return #ok(());
                };
            };
        };
        case (#err(errMsg)) {
            Debug.print("UserService: User deactivation failed: " # errMsg);
            return #err(errMsg);
        };
    };
};

// Function to reactivate a user and emit an event
public func reactivateUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("UserService: Handling reactivateUser request for ID: " # Principal.toText(userId));

    // Step 1: Reactivate the user in the module
    let reactivateResult = await userModule.reactivateUser(userId);

    // Step 2: Handle the reactivation result
    switch reactivateResult {
        case (#ok(())) {
            Debug.print("UserService: User reactivated successfully. Emitting event.");

            // Emit a UserReactivated event
            let emitResult = await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #UserReactivated;
                payload = #UserReactivated({
                    UserId = Principal.toText(userId);
                });
            });

            // Check for event emission success/failure
            switch emitResult {
                case () {
                    Debug.print("UserService: User reactivated and event emitted successfully.");
                    return #ok(());
                };
            };
        };
        case (#err(errMsg)) {
            Debug.print("UserService: User reactivation failed: " # errMsg);
            return #err(errMsg);
        };
    };
};

// Function to delete a user and emit an event
public func deleteUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("UserService: Handling deleteUser request for ID: " # Principal.toText(userId));

    // Step 1: Delete the user in the module
    let deleteResult = await userModule.deleteUser(userId);

    // Step 2: Handle the deletion result
    switch deleteResult {
        case (#ok(())) {
            Debug.print("UserService: User deleted successfully. Emitting event.");

            // Emit a UserDeleted event
            let emitResult = await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #UserDeleted;
                payload = #UserDeleted({
                    UserId = Principal.toText(userId);
                });
            });

            // Check for event emission success/failure
            switch emitResult {
                case () {
                    Debug.print("UserService: User deleted and UserDeleted event emitted successfully.");
                    return #ok(());
                };
            };
        };
        case (#err(errMsg)) {
            Debug.print("UserService: User deletion failed: " # errMsg);
            return #err(errMsg);
        };
    };
};


// Function to list all users
public func listAllUsers(includeInactive: Bool): async Result.Result<[UserModule.User], Text> {
    Debug.print("UserService: Handling listAllUsers request. Include inactive: " # Bool.toText(includeInactive));

    // Delegate to the user module
    let listResult = await userModule.listAllUsers(includeInactive);

    // Return the result
    return listResult;
};

// Function to reset a user's password and emit an event
public func resetPassword(userId: Principal, newPassword: Text): async Result.Result<UserModule.User, Text> {
    Debug.print("UserService: Handling resetPassword request for ID: " # Principal.toText(userId));

    // Step 1: Reset the user's password in the module
    let resetResult = await userModule.resetPassword(userId, newPassword);

    // Step 2: Handle the reset result
    switch resetResult {
        case (#ok(updatedUser)) {
            Debug.print("UserService: Password reset successfully. Emitting event.");

            // Emit a PasswordReset event
            let emitResult = await eventManager.emit({
                id = Nat64.fromIntWrap(Time.now());
                eventType = #PasswordReset;
                payload = #PasswordReset({
                    UserId = Principal.toText(userId);
                });
            });

            // Check for event emission success/failure
            switch emitResult {
                case () {
                    Debug.print("UserService: Password reset and PasswordReset event emitted successfully.");
                    return #ok(updatedUser);
                };
            };
        };
        case (#err(errMsg)) {
            Debug.print("UserService: Password reset failed: " # errMsg);
            return #err(errMsg);
        };
    };
};

public func registerDevice(userId: Principal, newDeviceKey: Principal): async Result.Result<(), Text> {
    await userModule.registerDevice(userId, newDeviceKey);
};

public func validateLogin(principal: ?Principal, email: ?Text, password: ?Text): async Result.Result<UserModule.User, Text> {
    await userModule.validateLogin(principal, email, password);
};

public func attachTokenToUser(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
    return await userManager.attachTokenToUser(userId, tokenId, amount);
};

    };
};
