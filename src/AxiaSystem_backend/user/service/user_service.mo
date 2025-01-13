import UserModule "../../user/modules/user_module";
import EventManager "../../heartbeat/event_manager";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Debug "mo:base/Debug";

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
    };
};