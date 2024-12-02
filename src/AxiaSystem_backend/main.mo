import TokenCanisterProxy "./token/utils/token_canister_proxy";
import UserCanisterProxy "./user/utils/user_canister_proxy";
import WalletCanisterProxy "./wallet/utils/wallet_canister_proxy";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import _List "mo:base/List";
import Int "mo:base/Int";

actor AxiaSystem_backend {
    private let _tokenProxy = TokenCanisterProxy;
    private let _userProxy = UserCanisterProxy.UserCanisterProxyManager(Principal.fromText("br5f7-7uaaa-aaaaa-qaaca-cai"));
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai"));

    // Exposed APIs to connect with frontend or other services
    public func createUserWallet(userId: Principal, initialBalance: Nat): async Result.Result<Text, Text> {
        let result = await walletProxy.createWallet(userId, initialBalance);
        switch (result) {
            case (#ok(wallet)) #ok("Wallet created with ID: " # Int.toText(wallet.id));
            case (#err(error)) #err(error);
        }
    };

    public func creditUserWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
        await walletProxy.creditWallet(userId, amount, tokenId)
    };

    public func debitUserWallet(userId: Principal, amount: Nat, tokenId: Nat): async Result.Result<Nat, Text> {
        await walletProxy.debitWallet(userId, amount, tokenId)
    };

   public func getWalletTransactionHistory(userId: Principal): async Result.Result<[WalletCanisterProxy.Transaction], Text> {
    let result = await walletProxy.getTransactionHistory(userId);
    switch (result) {
        case (#ok(transactions)) #ok(transactions);
        case (#err(e)) #err(e);
    }
};
    }

