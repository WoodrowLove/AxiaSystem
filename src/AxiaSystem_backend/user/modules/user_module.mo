import ValidationUtils "../../utils/validation_utils";
import LoggingUtils "../../utils/logging_utils";
import Sha256 "mo:sha256/SHA256";
import Blob "mo:base/Blob";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Nat8 "mo:base/Nat8";
import EventTypes "../../heartbeat/event_types";
import EventManager "../../heartbeat/event_manager";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Trie "mo:base/Trie";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";

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
        getUserById: (Principal) -> async ?User;
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
        public func getUserById(userId: Principal): async ?User {
            Array.find<User>(users, func(user: User): Bool { user.id == userId });
        };
    };
};