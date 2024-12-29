import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Nat "mo:base/Nat";

module {
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

    // Define the interface for the wallet canister
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
        getWalletBalance : (Principal) -> async Result.Result<Nat, Text>;
    };

    public class WalletCanisterProxy(walletCanisterId: Principal) {
        private let walletCanister: WalletCanisterInterface = actor(Principal.toText(walletCanisterId));

        // Create a wallet for a user
        public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<Wallet, Text> {
            try {
                let result = await walletCanister.createWallet(userId, initialBalance);
                // Handle event emission or logging if needed
                result
            } catch (e) {
                #err("Failed to create wallet: " # Error.message(e))
            }
        };

        // Retrieve a wallet by the owner's Principal
        public func getWalletByOwner(ownerId: Principal): async Result.Result<Wallet, Text> {
            try {
                await walletCanister.getWalletByOwner(ownerId)
            } catch (e) {
                #err("Failed to fetch wallet: " # Error.message(e))
            }
        };

        // Update the wallet balance
        public func updateBalance(ownerId: Principal, amount: Int): async Result.Result<Nat, Text> {
            try {
                let result = await walletCanister.updateBalance(ownerId, amount);
                // Handle event emission or logging if needed
                result
            } catch (e) {
                #err("Failed to update balance: " # Error.message(e))
            }
        };

        // Get transaction history for a wallet
        public func getTransactionHistory(ownerId: Principal): async Result.Result<[Transaction], Text> {
            try {
                await walletCanister.getTransactionHistory(ownerId)
            } catch (e) {
                #err("Failed to fetch transaction history: " # Error.message(e))
            }
        };

        // Delete a wallet
        public func deleteWallet(ownerId: Principal): async Result.Result<(), Text> {
            try {
                let result = await walletCanister.deleteWallet(ownerId);
                // Handle event emission or logging if needed
                result
            } catch (e) {
                #err("Failed to delete wallet: " # Error.message(e))
            }
        };

        public func creditWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
            try {
                let result = await walletCanister.creditWallet(userId, amount, tokenId);
                // Handle event emission or logging if needed
                result
            } catch (e) {
                #err("Failed to credit wallet: " # Error.message(e))
            }
        };

        public func debitWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
            try {
                let result = await walletCanister.debitWallet(userId, amount, tokenId);
                // Handle event emission or logging if needed
                result
            } catch (e) {
                #err("Failed to debit wallet: " # Error.message(e))
            }
        };

        // Get balance for a specific user and token
        public func getBalance(userId: Principal, tokenId: Nat): async Result.Result<Nat, Text> {
            try {
                await walletCanister.getBalance(userId, tokenId)
            } catch (e) {
                #err("Failed to get balance: " # Error.message(e))
            }
        };

        // Add balance for a specific user and token
        public func addBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Nat, Text> {
            try {
                let result = await walletCanister.addBalance(userId, tokenId, amount);
                // Handle event emission or logging if needed
                result
            } catch (e) {
                #err("Failed to add balance: " # Error.message(e))
            }
        };

        // Deduct balance for a specific user and token
        public func deductBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<Nat, Text> {
            try {
                let result = await walletCanister.deductBalance(userId, tokenId, amount);
                // Handle event emission or logging if needed
                result
            } catch (e) {
                #err("Failed to deduct balance: " # Error.message(e))
            }
        };

        // Get wallet balance
public func getWalletBalance(userId: Principal): async Result.Result<Nat, Text> {
    try {
        await walletCanister.getWalletBalance(userId)
    } catch (e) {
        #err("Failed to get wallet balance: " # Error.message(e))
    }
};
    }
}
