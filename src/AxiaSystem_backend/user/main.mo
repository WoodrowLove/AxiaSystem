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

actor UserCanister {
    // Initialize the event manager
    private let eventManager = EventManager.EventManager();

    // Initialize the user manager with the event manager
    private let userManager = UserModule.UserManager(eventManager);

    private let userService = UserService.UserService(userManager, eventManager);
    

    // Public API: Create a new user
    public shared func createUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
        await userManager.createUser(username, email, password);
    };

    // Public API: Get user by ID
    public shared func getUserById(userId: Principal): async ?UserModule.User {
        Debug.print("Main: Handling getUserById request for ID: " # Principal.toText(userId));

        // Fetch the user from the manager
        let userResult = await userManager.getUserById(userId);

        // Convert the result to optional type
        switch userResult {
            case (#ok(user)) {
                Debug.print("Main: Found user ID: " # Principal.toText(user.id));
                return ?user;
            };
            case (#err(err)) {
                Debug.print("Main: User not found. Error: " # err);
                return null;
            };
        };
    };


    // Public API: Update a user
public shared func updateUser(userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text): async Result.Result<UserModule.User, Text> {
    Debug.print("Main: Handling updateUser request for ID: " # Principal.toText(userId));

    // Delegate to the user manager
    let updateResult = await userManager.updateUser(userId, newUsername, newEmail, newPassword);

    // Log and return the result
    switch updateResult {
        case (#ok(updatedUser)) {
            Debug.print("Main: User updated successfully for ID: " # Principal.toText(updatedUser.id));
            return #ok(updatedUser);
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to update user: " # errMsg);
            return #err(errMsg);
        };
    };
};


    // Heartbeat function to process queued events
    system func heartbeat() : async () {
      await eventManager.processQueuedEventsSync();
    };
    
    // Public API: Deactivate a user
public shared func deactivateUser(userId: Principal): async Result.Result<(), Text> {
    Debug.print("Main: Handling deactivateUser request for ID: " # Principal.toText(userId));

    // Delegate to the user manager
    let deactivateResult = await userManager.deactivateUser(userId);

    // Log and return the result
    switch deactivateResult {
        case (#ok(())) {
            Debug.print("Main: User deactivated successfully for ID: " # Principal.toText(userId));
            return #ok(());
        };
        case (#err(errMsg)) {
            Debug.print("Main: Failed to deactivate user: " # errMsg);
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

};