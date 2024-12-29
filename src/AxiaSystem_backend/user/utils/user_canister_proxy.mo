import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import SharedTypes "../../shared_types";
import _TokenState "../../token/state/token_state";

module {
  public type User = {
    id: Principal;
    username: Text;
    email: Text;
    createdAt: Int;
    updatedAt: Int;
    isActive: Bool;
    isVerified: Bool;
  };

  // Define the interface for the user canister
public type UserCanisterInterface = actor {
    getUserById: (userId: Principal) -> async Result.Result<User, Text>;
    createUser: (username: Text, email: Text, passwordHash: Text) -> async Result.Result<User, Text>;
    attachWalletToUser: (userId: Principal, walletId: Nat) -> async Result.Result<(), Text>;
    detachWalletFromUser: (userId: Principal) -> async Result.Result<(), Text>;
    deactivateUser: (userId: Principal) -> async Result.Result<(), Text>;
    listAllUsers: () -> async Result.Result<[User], Text>;
    attachTokensToUser: (tokenId: Nat, userId: Principal, amount: Nat, tokenCanisterPrincipal: Principal) -> async Result.Result<(), Text>;
    updateUser: (userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text) -> async Result.Result<User, Text>;
    resetPassword: (userId: Principal, newPassword: Text) -> async Result.Result<User, Text>;
    validateSession: (token: Text) -> async Result.Result<SharedTypes.Session, Text>;
    getSession: (sessionToken: Text) -> async Result.Result<SharedTypes.Session, Text>;
    deleteUser: (userId: Principal) -> async Result.Result<(), Text>;
};

  public func createUserCanisterProxy(userCanisterId: Principal) : UserCanisterInterface {
    actor(Principal.toText(userCanisterId)) : UserCanisterInterface
  };

  public class UserCanisterProxyManager(userCanisterId: Principal) {
    private let userCanister : UserCanisterInterface = createUserCanisterProxy(userCanisterId);

    public func getUserById(userId: Principal): async Result.Result<User, Text> {
      try {
        await userCanister.getUserById(userId)
      } catch (e) {
        #err("Failed to fetch user: " # Error.message(e))
      }
    };

    public func createUser(username: Text, email: Text, passwordHash: Text): async Result.Result<User, Text> {
      try {
        await userCanister.createUser(username, email, passwordHash)
      } catch (e) {
        #err("Failed to create user: " # Error.message(e))
      }
    };

    public func attachWalletToUser(userId: Principal, walletId: Nat): async Result.Result<(), Text> {
      try {
        await userCanister.attachWalletToUser(userId, walletId)
      } catch (e) {
        #err("Failed to attach wallet: " # Error.message(e))
      }
    };

    public func deactivateUser(userId: Principal): async Result.Result<(), Text> {
      try {
        await userCanister.deactivateUser(userId)
      } catch (e) {
        #err("Failed to deactivate user: " # Error.message(e))
      }
    };

    public func listAllUsers(): async Result.Result<[User], Text> {
      try {
        await userCanister.listAllUsers()
      } catch (e) {
        #err("Failed to list users: " # Error.message(e))
      }
    };

    public func detachWalletFromUser(userId: Principal): async Result.Result<(), Text> {
      try {
        await userCanister.detachWalletFromUser(userId)
      } catch (e) {
        #err("Failed to detach wallet from user: " # Error.message(e))
      }
    };

    // Update user details
public func updateUser(userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text): async Result.Result<User, Text> {
    try {
        await userCanister.updateUser(userId, newUsername, newEmail, newPassword)
    } catch (e) {
        #err("Failed to update user: " # Error.message(e))
    }
};

// Reset user password
public func resetPassword(userId: Principal, newPassword: Text): async Result.Result<User, Text> {
    try {
        await userCanister.resetPassword(userId, newPassword)
    } catch (e) {
        #err("Failed to reset password: " # Error.message(e))
    }
};

// Validate session token
public func validateSession(sessionToken: Text): async Result.Result<(), Text> {
    try {
        let result = await userCanister.validateSession(sessionToken);
        switch (result) {
            case (#ok(_)) {
                #ok(())
            };
            case (#err(e)) {
                #err(e)
            };
        }
    } catch (e) {
        #err("Failed to validate session: " # Error.message(e))
    }
};

// Attach tokens to a user
public func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat, tokenCanisterPrincipal: Principal): async Result.Result<(), Text> {
    try {
        await userCanister.attachTokensToUser(tokenId, userId, amount, tokenCanisterPrincipal)
    } catch (e) {
        #err("Failed to attach tokens to user: " # Error.message(e))
    }
};

// Retrieve session by token
public func getSession(sessionToken: Text): async Result.Result<SharedTypes.Session, Text> {
    try {
        await userCanister.getSession(sessionToken)
    } catch (e) {
        #err("Failed to retrieve session: " # Error.message(e))
    }
};

// Delete user
public func deleteUser(userId: Principal): async Result.Result<(), Text> {
    try {
        await userCanister.deleteUser(userId)
    } catch (e) {
        #err("Failed to delete user: " # Error.message(e))
    }
};

// List all active users
public func listActiveUsers(): async Result.Result<[User], Text> {
    try {
        await userCanister.listAllUsers() // Filter logic can be applied at the caller level
    } catch (e) {
        #err("Failed to list active users: " # Error.message(e))
    }
};
  };
}