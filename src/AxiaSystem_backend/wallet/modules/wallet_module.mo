import Nat "mo:base/Nat";
import Int "mo:base/Int";
import List "mo:base/List";
import Trie "mo:base/Trie";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import _Nat64 "mo:base/Nat64";
import UserCanisterProxy "../../user/utils/user_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";
import EventManager "../../heartbeat/event_manager";


module {
  public type WalletTransaction = {
    id: Nat;
    amount: Int;
    timestamp: Nat;
    description: Text;
  };

  public type Wallet = {
    id: Int;
    owner: Principal;
    balance: Nat;
    transactions: List.List<WalletTransaction>;
  };

  type TokenCanisterProxyType = {
    getAllTokens: () -> async [TokenCanisterProxy.Token];
    getToken: (Nat) -> async ?TokenCanisterProxy.Token;
    updateToken: (TokenCanisterProxy.Token) -> async Result.Result<(), Text>;
    mintTokens: (Principal, Nat) -> async Result.Result<(), Text>;
    attachTokensToUser: (Nat, Principal, Nat) -> async Result.Result<(), Text>;
};

  public class WalletManager(userProxy: UserCanisterProxy.UserCanisterProxyManager, tokenProxy: TokenCanisterProxyType) {
    private var wallets: Trie.Trie<Principal, Wallet> = Trie.empty();
    let eventManager = EventManager.EventManager();

    // Create a new wallet for a user
public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<Wallet, Text> {
  let userIdKey = { key = userId; hash = Principal.hash(userId) };

  switch (Trie.find(wallets, userIdKey, Principal.equal)) {
    case (?_) { #err("Wallet already exists for this user.") };
    case null {
      // Validate the user exists
      let userCheck = await userProxy.getUserById(userId);
      switch userCheck {
        case (#err(error)) { return #err("Failed to validate user: " # error); };
        case (#ok(_)) {
          let walletId = Time.now(); // Using the current timestamp as the wallet ID
          let newWallet = {
            id = walletId;
            owner = userId;
            balance = initialBalance;
            transactions = List.nil<WalletTransaction>();
          };
          wallets := Trie.put(wallets, userIdKey, Principal.equal, newWallet).0;

          // Emit wallet created event
          await eventManager.emitWalletCreated(
            userId,
            "Wallet created with initial balance: " # Nat.toText(initialBalance)
          );

          #ok(newWallet)
        };
      }
    };
  }
};

    // Adjust wallet balance
public func updateBalance(userId: Principal, amount: Int): async Result.Result<Nat, Text> {
    let userIdKey = { key = userId; hash = Principal.hash(userId) };

    switch (Trie.find(wallets, userIdKey, Principal.equal)) {
        case (?wallet) {
            let newBalanceInt = Int.add(wallet.balance, amount);
            if (newBalanceInt < 0) {
                return #err("Insufficient balance for this operation.");
            };

            let newBalance = Int.abs(newBalanceInt);
            let updatedWallet = { wallet with balance = newBalance };
            wallets := Trie.put(wallets, userIdKey, Principal.equal, updatedWallet).0;

            // Emit wallet updated event
            await eventManager.emitWalletUpdated(
                userId,
                "Wallet balance updated to: " # Nat.toText(newBalance)
            );

            return #ok(newBalance);
        };
        case null {
            return #err("Wallet not found.");
        };
    };
};

    // Get transaction history for a wallet
    public func getTransactionHistory(userId: Principal): async Result.Result<List.List<WalletTransaction>, Text> {
      let userIdKey = { key = userId; hash = Principal.hash(userId) };

      switch (Trie.find(wallets, userIdKey, Principal.equal)) {
        case (?wallet) #ok(wallet.transactions);
        case null #err("Wallet not found.");
      }
    };

    // Record a transaction
    public func recordTransaction(userId: Principal, transaction: WalletTransaction): async Result.Result<Wallet, Text> {
      let userIdKey = { key = userId; hash = Principal.hash(userId) };

      switch (Trie.find(wallets, userIdKey, Principal.equal)) {
        case (?wallet) {
          let updatedTransactions = List.push(transaction, wallet.transactions);
          let updatedWallet = { wallet with transactions = updatedTransactions };
          wallets := Trie.put(wallets, userIdKey, Principal.equal, updatedWallet).0;
          #ok(updatedWallet)
        };
        case null #err("Wallet not found.");
      }
    };

    // Retrieve all wallets (admin use only)
    public func getAllWallets(): [Wallet] {
      Array.tabulate<Wallet>(Trie.size(wallets), func (i) {
        switch (Trie.nth(wallets, i)) {
          case (?(_, wallet)) wallet;
          case null Debug.trap("Unexpected null while retrieving wallet.");
        }
      })
    };

    // Remove a wallet (for user deletion or other purposes)
public func deleteWallet(userId: Principal): async Result.Result<(), Text> {
    let userIdKey = { key = userId; hash = Principal.hash(userId) };

    switch (Trie.find(wallets, userIdKey, Principal.equal)) {
        case (?_wallet) {
            let (newWallets, _) = Trie.remove(wallets, userIdKey, Principal.equal);
            wallets := newWallets;

            // Emit wallet deleted event
            await eventManager.emitWalletDeleted(
                userId,
                "Wallet deleted"
            );

            return #ok(());
        };
        case null {
            return #err("Wallet not found.");
        };
    };
};

    // Debit a wallet (withdraw funds)
public func debitWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
    if (amount == 0) {
        return #err("Amount must be greater than zero.");
    };

    let userIdKey = { key = userId; hash = Principal.hash(userId) };

    switch (Trie.find(wallets, userIdKey, Principal.equal)) {
        case (?wallet) {
            if (wallet.balance < amount) {
                #err("Insufficient funds in wallet.");
            } else {
                let newBalance : Nat = wallet.balance - amount;
                let updatedWallet = { wallet with balance = newBalance };
                wallets := Trie.put(wallets, userIdKey, Principal.equal, updatedWallet).0;

                // Emit WalletUpdated event
                await eventManager.emitWalletUpdated(
                    userId,
                    "Wallet debited: " # Nat.toText(amount)
                );

                #ok(newBalance);
            }
        };
        case null #err("Wallet not found.");
    }
};


// Credit a wallet (add funds)
public func creditWallet(userId: Principal, amount: Nat): async Result.Result<Nat, Text> {
    if (amount == 0) {
        return #err("Amount must be greater than zero.");
    };

    let userIdKey = { key = userId; hash = Principal.hash(userId) };

    switch (Trie.find(wallets, userIdKey, Principal.equal)) {
        case (?wallet) {
            let newBalance = wallet.balance + amount;
            let updatedWallet = { wallet with balance = newBalance };
            wallets := Trie.put(wallets, userIdKey, Principal.equal, updatedWallet).0;

            // Emit WalletUpdated event
            await eventManager.emitWalletUpdated(
                userId,
                "Wallet credited: " # Nat.toText(amount)
            );

            #ok(newBalance);
        };
        case null #err("Wallet not found.");
    }
};

// Attach token-related balances to a wallet (inter-canister call)
public func attachTokenBalance(
    userId: Principal,
    tokenId: Nat,
    amount: Nat
): async Result.Result<(), Text> {
    let tokenUpdate = await tokenProxy.attachTokensToUser(tokenId, userId, amount);
    switch tokenUpdate {
        case (#ok(())) {
            let userIdKey = { key = userId; hash = Principal.hash(userId) };

            switch (Trie.find(wallets, userIdKey, Principal.equal)) {
                case (?wallet) {
                    let updatedWallet = { wallet with balance = wallet.balance + amount };
                    wallets := Trie.put(wallets, userIdKey, Principal.equal, updatedWallet).0;

                    // Emit WalletUpdated event
                    await eventManager.emitWalletUpdated(
                        userId,
                        "Token balance attached: " # Nat.toText(amount)
                    );

                    #ok(());
                };
                case null #err("Wallet not found.");
            }
        };
        case (#err(e)) #err("Failed to attach token balance: " # e);
    }
};

// Retrieve the balance of a wallet
public func getWalletBalance(userId: Principal): async Result.Result<Nat, Text> {
  let userIdKey = { key = userId; hash = Principal.hash(userId) };

  switch (Trie.find(wallets, userIdKey, Principal.equal)) {
    case (?wallet) #ok(wallet.balance);
    case null #err("Wallet not found.");
  }
};

  };
};