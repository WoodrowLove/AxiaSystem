import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat "mo:base/Nat";
// import Debug "mo:base/Debug";
import SharedTypes "../../shared_types";  // ✅ Import Shared Types

module {
    // ✅ Use shared User type
    public type User = SharedTypes.User;

    // ✅ Import User and Wallet Canister Interfaces
    public type UserCanisterInterface = SharedTypes.UserCanisterInterface;
    public type WalletCanisterInterface = actor {
        createWallet: (userId: Principal, initialBalance: Nat) -> async Result.Result<Wallet, Text>;
        getWalletByOwner: (ownerId: Principal) -> async Result.Result<Wallet, Text>;
        updateBalance: (ownerId: Principal, amount: Int) -> async Result.Result<Nat, Text>;
        getTransactionHistory: (ownerId: Principal) -> async Result.Result<[Transaction], Text>;
        deleteWallet: (ownerId: Principal) -> async Result.Result<(), Text>;
        creditWallet: (userId: Principal, amount: Nat, tokenId: Nat) -> async Result.Result<Nat, Text>;
        debitWallet: (userId: Principal, amount: Nat, tokenId: Nat) -> async Result.Result<Nat, Text>;
        getBalance: (userId: Principal, tokenId: Nat) -> async Result.Result<Nat, Text>;
        addBalance: (userId: Principal, tokenId: Nat, amount: Nat) -> async Result.Result<Nat, Text>;
        deductBalance: (userId: Principal, tokenId: Nat, amount: Nat) -> async Result.Result<Nat, Text>;
        getWalletBalance: (Principal) -> async Result.Result<Nat, Text>;
    };

    // ✅ Wallet and Transaction Types
    public type Wallet = {
        id: Int;
        owner: Principal;
        balance: Nat;
        transactions: [Transaction];
    };

    public type Transaction = {
        id: Nat;
        amount: Int;
        timestamp: Nat;
        description: Text;
    };

    // ✅ Factory Function for User Canister Proxy
    public func createUserCanisterProxy(userCanisterId: Principal): UserCanisterInterface {
        actor (Principal.toText(userCanisterId)) : UserCanisterInterface
    };

    // ✅ Wallet Canister Proxy
    public class WalletCanisterProxy(walletCanisterId: Principal, userCanisterId: Principal) {
        private let walletCanister: WalletCanisterInterface = actor (Principal.toText(walletCanisterId));
        private let userCanister: UserCanisterInterface = createUserCanisterProxy(userCanisterId);

        // ✅ Get Slim User by ID (to prevent IDL errors)
       public func getUserById(userId: Principal): async Result.Result<User, Text> {
  try {
    let userResult = await userCanister.getUserById(userId); // ✅ Use `getUserById`
    
    switch userResult {
      case (#ok(user)) return #ok(user);  // ✅ Works with full user data
      case (#err(errorMessage)) return #err("User lookup failed: " # errorMessage);
    };
  } catch (e) {
    return #err("Failed to fetch user: " # Error.message(e));
  }
};

        // ✅ Create a wallet for a user
        public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<Wallet, Text> {
            let userCheck = await getUserById(userId);
            switch userCheck {
                case (#err(error)) return #err("Failed to validate user: " # error);
                case (#ok(_)) {
                    try {
                        let result = await walletCanister.createWallet(userId, initialBalance);
                        return result;
                    } catch (e) {
                        return #err("Failed to create wallet: " # Error.message(e));
                    }
                };
            };
        };

        // ✅ Retrieve a wallet by owner
        public func getWalletByOwner(ownerId: Principal): async Result.Result<Wallet, Text> {
            try {
                await walletCanister.getWalletByOwner(ownerId);
            } catch (e) {
                return #err("Failed to fetch wallet: " # Error.message(e));
            }
        };

        // ✅ Update wallet balance
        public func updateBalance(ownerId: Principal, amount: Int): async Result.Result<Nat, Text> {
            try {
                await walletCanister.updateBalance(ownerId, amount);
            } catch (e) {
                return #err("Failed to update balance: " # Error.message(e));
            }
        };

        // ✅ Get transaction history
        public func getTransactionHistory(ownerId: Principal): async Result.Result<[Transaction], Text> {
            try {
                await walletCanister.getTransactionHistory(ownerId);
            } catch (e) {
                return #err("Failed to fetch transaction history: " # Error.message(e));
            }
        };

        // ✅ Delete a wallet
        public func deleteWallet(ownerId: Principal): async Result.Result<(), Text> {
            try {
                await walletCanister.deleteWallet(ownerId);
            } catch (e) {
                return #err("Failed to delete wallet: " # Error.message(e));
            }
        };

        // ✅ Credit a wallet (add funds)
        public func creditWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
            try {
                await walletCanister.creditWallet(userId, amount, tokenId);
            } catch (e) {
                return #err("Failed to credit wallet: " # Error.message(e));
            }
        };

        // ✅ Debit a wallet (withdraw funds)
        public func debitWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
            try {
                await walletCanister.debitWallet(userId, amount, tokenId);
            } catch (e) {
                return #err("Failed to debit wallet: " # Error.message(e));
            }
        };

        // ✅ Get balance for a user and token
        public func getBalance(userId: Principal, tokenId: Nat): async Result.Result<Nat, Text> {
            try {
                await walletCanister.getBalance(userId, tokenId);
            } catch (e) {
                return #err("Failed to get balance: " # Error.message(e));
            }
        };

        // ✅ Add balance for a user and token
        public func addBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Nat, Text> {
            try {
                await walletCanister.addBalance(userId, tokenId, amount);
            } catch (e) {
                return #err("Failed to add balance: " # Error.message(e));
            }
        };

        // ✅ Deduct balance for a user and token
        public func deductBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Nat, Text> {
            try {
                await walletCanister.deductBalance(userId, tokenId, amount);
            } catch (e) {
                return #err("Failed to deduct balance: " # Error.message(e));
            }
        };

        // ✅ Get wallet balance
        public func getWalletBalance(userId: Principal): async Result.Result<Nat, Text> {
            try {
                await walletCanister.getWalletBalance(userId);
            } catch (e) {
                return #err("Failed to get wallet balance: " # Error.message(e));
            }
        };
    };
};