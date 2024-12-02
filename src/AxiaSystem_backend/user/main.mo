import UserModule "./modules/user_module";
import Result "mo:base/Result";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import TokenCanisterProxy "../token/utils/token_canister_proxy";

actor {
  private let userManager = UserModule.UserManager();
  private let tokenCanisterProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai"));

  public func createUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
    await userManager.createUser(username, email, password);
  };

  public func getUserById(id: Principal): async ?UserModule.User {
    await userManager.getUserById(id);
  };

public shared(_msg) func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat): async Result.Result<(), Text> {
    try {
        // Call the token canister to attach tokens
        let result = await tokenCanisterProxy.attachTokensToUser(tokenId, userId, amount);
        
        // Log the operation
        switch (result) {
            case (#ok(_)) {
                // Log success
                // You might want to use your logging utility here
                #ok(())
            };
            case (#err(e)) {
                // Log error
                // You might want to use your logging utility here
                #err("Failed to attach tokens: " # e)
            };
        }
    } catch (error) {
        // Handle any unexpected errors during the inter-canister call
        #err("Unexpected error while attaching tokens: " # Error.message(error))
    };
};
};