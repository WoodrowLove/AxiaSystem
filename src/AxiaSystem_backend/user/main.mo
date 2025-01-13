import UserModule "../user/modules/user_module";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";

actor UserCanister {
    // Initialize the event manager
    private let eventManager = EventManager.EventManager();

    // Initialize the user manager with the event manager
    private let userManager = UserModule.UserManager(eventManager);

    // Public API: Create a new user
    public shared func createUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
        await userManager.createUser(username, email, password);
    };

    // Public API: Get user by ID
    public shared func getUserById(userId: Principal): async ?UserModule.User {
      await userManager.getUserById(userId);
    };

    // Heartbeat function to process queued events
    system func heartbeat() : async () {
      await eventManager.processQueuedEventsSync();
    };
};