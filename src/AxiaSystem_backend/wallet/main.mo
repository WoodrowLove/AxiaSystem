import WalletModule "./modules/wallet_module";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import List "mo:base/List";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";

actor WalletCanister {
    private let userProxy = UserCanisterProxy.UserCanisterProxyManager(Principal.fromText("user-canister-id"));
    private let tokenProxy = {
        getAllTokens = TokenCanisterProxy.getAllTokens;
        getToken = TokenCanisterProxy.getToken;
        updateToken = TokenCanisterProxy.updateToken;
        mintTokens = TokenCanisterProxy.mintTokens;
        attachTokensToUser = TokenCanisterProxy.attachTokensToUser;
    };
    private let walletManager = WalletModule.WalletManager(userProxy, tokenProxy);

    public func createWallet(userId: Principal, initialBalance: Nat): async Result.Result<WalletModule.Wallet, Text> {
        await walletManager.createWallet(userId, initialBalance)
    };

    public func getWalletByOwner(ownerId: Principal): async Result.Result<Nat, Text> {
    walletManager.getWalletBalance(ownerId)
};

    public func updateBalance(ownerId: Principal, amount: Int): async Result.Result<Nat, Text> {
        await walletManager.updateBalance(ownerId, amount)
    };

    public func getTransactionHistory(ownerId: Principal): async Result.Result<[WalletModule.WalletTransaction], Text> {
        let result = await walletManager.getTransactionHistory(ownerId);
        switch (result) {
            case (#ok(list)) #ok(List.toArray(list));
            case (#err(e)) #err(e);
        }
    };

    public func deleteWallet(ownerId: Principal): async Result.Result<(), Text> {
        await walletManager.deleteWallet(ownerId)
    };
};