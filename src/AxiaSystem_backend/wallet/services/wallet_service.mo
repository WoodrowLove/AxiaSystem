import WalletModule "../modules/wallet_module";
import EventManager "../../heartbeat/event_manager";
import Result "mo:base/Result";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";


module {
  public class WalletService(walletManager: WalletModule.WalletManager, eventManager: EventManager.EventManager) {

    // Create a wallet for a user
    public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<WalletModule.Wallet, Text> {
      let result = await walletManager.createWallet(userId, initialBalance);
      switch result {
        case (#ok(wallet)) {
          // Emit wallet created event
          await eventManager.emitWalletCreated(
            wallet.owner,
            "Wallet created with initial balance: " # Nat.toText(wallet.balance)
          );
          #ok(wallet);
        };
        case (#err(error)) {
          #err("Failed to create wallet: " # error);
        };
      }
    };

    // Get a wallet by owner ID
    public func getWalletByOwner(ownerId: Principal): async Result.Result<WalletModule.Wallet, Text> {
      let balanceResult = await walletManager.getWalletBalance(ownerId);
      switch (balanceResult) {
        case (#ok(balance)) {
          let wallet: WalletModule.Wallet = {
            id = Time.now();
            owner = ownerId;
            balance = balance;
            transactions = List.nil<WalletModule.WalletTransaction>();
          };
          // Emit wallet fetched event (optional)
          await eventManager.emitWalletEvent(
            ownerId,
            #WalletEventGeneric,
            "Wallet fetched successfully.",
            balance
          );
          #ok(wallet);
        };
        case (#err(error)) {
          #err("Failed to retrieve wallet: " # error);
        };
      }
    };

    // Update the wallet balance
    public func updateBalance(ownerId: Principal, amount: Int): async Result.Result<Nat, Text> {
      let updateResult = await walletManager.updateBalance(ownerId, amount);
      switch updateResult {
        case (#ok(newBalance)) {
          // Emit wallet updated event
          await eventManager.emitWalletUpdated(
            ownerId,
            "Wallet balance updated to: " # Nat.toText(newBalance)
          );
          #ok(newBalance);
        };
        case (#err(error)) {
          #err("Failed to update wallet balance: " # error);
        };
      }
    };

    // Get transaction history
    public func getTransactionHistory(ownerId: Principal): async Result.Result<[WalletModule.WalletTransaction], Text> {
      let result = await walletManager.getTransactionHistory(ownerId);
      switch (result) {
        case (#ok(transactionList)) {
          #ok(List.toArray(transactionList));
        };
        case (#err(error)) {
          #err("Failed to fetch transaction history: " # error);
        };
      }
    };

    // Delete a wallet
    public func deleteWallet(ownerId: Principal): async Result.Result<(), Text> {
      let result = await walletManager.deleteWallet(ownerId);
      switch result {
        case (#ok(())) {
          // Emit wallet deleted event
          await eventManager.emitWalletDeleted(
            ownerId,
            "Wallet deleted successfully."
          );
          #ok(());
        };
        case (#err(error)) {
          #err("Failed to delete wallet: " # error);
        };
      }
    };

    // Credit a wallet (add funds)
    public func creditWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
      let creditResult = await walletManager.creditWallet(userId, amount);
      switch creditResult {
        case (#ok(newBalance)) {
          // Emit wallet credited event
          await eventManager.emitWalletUpdated(
            userId,
            "Wallet credited with: " # Nat.toText(amount)
          );
          #ok(newBalance);
        };
        case (#err(error)) {
          #err("Failed to credit wallet: " # error);
        };
      }
    };

    // Debit a wallet (withdraw funds)
    public func debitWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
      let debitResult = await walletManager.debitWallet(userId, amount);
      switch debitResult {
        case (#ok(newBalance)) {
          // Emit wallet debited event
          await eventManager.emitWalletUpdated(
            userId,
            "Wallet debited by: " # Nat.toText(amount)
          );
          #ok(newBalance);
        };
        case (#err(error)) {
          #err("Failed to debit wallet: " # error);
        };
      }
    };

    // Attach token balances to a wallet
    public func attachTokenBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
      let result = await walletManager.attachTokenBalance(userId, tokenId, amount);
      switch result {
        case (#ok(())) {
          // Emit wallet updated event
          await eventManager.emitWalletUpdated(
            userId,
            "Token balance updated with: " # Nat.toText(amount)
          );
          #ok(());
        };
        case (#err(error)) {
          #err("Failed to attach token balance: " # error);
        };
      }
    };

    // Get wallet balance
    public func getWalletBalance(userId: Principal): async Result.Result<Nat, Text> {
      let balanceResult = await walletManager.getWalletBalance(userId);
      switch (balanceResult) {
        case (#ok(balance)) {
          #ok(balance);
        };
        case (#err(error)) {
          #err("Failed to retrieve wallet balance: " # error);
        };
      }
    };
  };
};