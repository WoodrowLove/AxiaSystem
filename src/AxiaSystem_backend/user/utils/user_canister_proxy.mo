import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
import Debug "mo:base/Debug";

module {
    public type User = {
        id: Principal;
        username: Text;
        email: Text;
        createdAt: Int;
        updatedAt: Int;
        isActive: Bool;
    };

    // Define the interface for the user canister
    public type UserCanisterInterface = actor {
        getUserById: (Principal) -> async Result.Result<User, Text>;
        createUser: (Text, Text, Text) -> async Result.Result<User, Text>;
        updateUser: (Principal, ?Text, ?Text, ?Text) -> async Result.Result<User, Text>;
        registerDevice: shared (Principal, Principal) -> async Result.Result<(), Text>;
        validateLogin: shared (?Principal, ?Text, ?Text) -> async Result.Result<User, Text>;
        attachTokensToUser: (Principal, Nat, Nat) -> async Result.Result<(), Text>;
    };

    // Factory function for creating a user canister proxy
    public func createUserCanisterProxy(userCanisterId: Principal): UserCanisterInterface {
        actor(Principal.toText(userCanisterId)) : UserCanisterInterface
    };

    public class UserCanisterProxy(userCanisterId: Principal) {
        private let userCanister: UserCanisterInterface = createUserCanisterProxy(userCanisterId);

        public func getUserById(userId: Principal): async Result.Result<User, Text> {
            try {
                await userCanister.getUserById(userId)
            } catch (e) {
                #err("Failed to fetch user: " # Error.message(e))
            }
        };

        public func createUser(username: Text, email: Text, password: Text): async Result.Result<User, Text> {
            try {
                await userCanister.createUser(username, email, password)
            } catch (e) {
                #err("Failed to create user: " # Error.message(e))
            }
        };

        public func updateUser(
            userId: Principal,
            newUsername: ?Text,
            newEmail: ?Text,
            newPassword: ?Text
        ): async Result.Result<User, Text> {
            try {
                await userCanister.updateUser(userId, newUsername, newEmail, newPassword)
            } catch (e) {
                #err("Failed to update user: " # Error.message(e))
            }
        };

        public func registerDevice(userId: Principal, newDeviceKey: Principal): async Result.Result<(), Text> {
            try {
                await userCanister.registerDevice(userId, newDeviceKey);
            } catch (e) {
                #err("Failed to register device: " # Error.message(e));
            }
        };

        public func validateLogin(principal: ?Principal, email: ?Text, password: ?Text): async Result.Result<User, Text> {
            try {
                await userCanister.validateLogin(principal, email, password);
            } catch (e) {
                #err("Failed to validate login: " # Error.message(e));
            }
        };

        // ✅ Updated attachTokensToUser function
        public func attachTokensToUser(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
            Debug.print("🔄 [user_proxy.mo] Forwarding attachTokensToUser request to main.mo");

            try {
                let result = await userCanister.attachTokensToUser(userId, tokenId, amount);

                switch result {
                    case (#ok(())) {
                        Debug.print("✅ [user_proxy.mo] Tokens successfully attached for user: " # Principal.toText(userId));
                        return #ok(());
                    };
                    case (#err(e)) {
                        Debug.print("❌ [user_proxy.mo] Error attaching tokens: " # e);
                        return #err(e);
                    };
                };
            } catch (e) {
                let errorMsg = "Failed to attach tokens: " # Error.message(e);
                Debug.print("❌ [user_proxy.mo] " # errorMsg);
                return #err(errorMsg);
            }
        };
    };
};