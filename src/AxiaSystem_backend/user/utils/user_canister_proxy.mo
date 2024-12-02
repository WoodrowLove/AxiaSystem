import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";

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
  };
}