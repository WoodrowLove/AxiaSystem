import WalletModule "../modules/wallet_module";
import _UserCanisterProxy "../../user/utils/user_canister_proxy";
import _TokenCanisterProxy "../../token/utils/token_canister_proxy";
import Result "mo:base/Result";
import List "mo:base/List";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Time "mo:base/Time";

module {
  public class WalletService(walletManager: WalletModule.WalletManager) {

    // Create a wallet for a user
    public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<WalletModule.Wallet, Text> {
      let result = await walletManager.createWallet(userId, initialBalance);
      switch result {
        case (#ok(wallet)) {
          #ok(wallet);
        };
        case (#err(error)) {
          #err("Failed to create wallet: " # error);
        };
      }
    };

    // Get a wallet by owner ID
    public func getWalletByOwner(ownerId: Principal): async Result.Result<WalletModule.Wallet, Text> {
      switch (await walletManager.getWalletBalance(ownerId)) {
        case (#ok(balance)) {
          let wallet: WalletModule.Wallet = {
            id = Time.now();
            owner = ownerId;
            balance = balance;
            transactions = List.nil<WalletModule.WalletTransaction>();
          };
          #ok(wallet);
        };
        case (#err(error)) {
          #err("Failed to retrieve wallet: " # error);
        };
      }
    };

    // Update the wallet balance
    public func updateBalance(ownerId: Principal, amount: Int): async Result.Result<Nat, Text> {
      await walletManager.updateBalance(ownerId, amount);
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
      await walletManager.deleteWallet(ownerId);
    };

    // Credit a wallet (add funds)
    public func creditWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
      await walletManager.creditWallet(userId, amount);
    };

    // Debit a wallet (withdraw funds)
    public func debitWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
      await walletManager.debitWallet(userId, amount);
    };

    // Attach token balances to a wallet
    public func attachTokenBalance(userId: Principal, tokenId: Nat, amount: Nat): async Result.Result<(), Text> {
      await walletManager.attachTokenBalance(userId, tokenId, amount);
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