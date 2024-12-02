import PaymentModule "./modules/payment_module";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";

actor PaymentCanister {
    // Instantiate proxies for inter-canister communication
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("wallet-canister-id"));
    private let userProxy = UserCanisterProxy.UserCanisterProxyManager(Principal.fromText("user-canister-id"));
    private let tokenProxy = TokenCanisterProxy;

    // Initialize the Payment Manager
    private let paymentManager = PaymentModule.PaymentManager(walletProxy, userProxy, tokenProxy);

    // Initiate a payment
    public func initiatePayment(
        sender: Principal,
        receiver: Principal,
        amount: Nat,
        tokenId: ?Nat
    ): async Result.Result<PaymentModule.Payment, Text> {
        await paymentManager.initiatePayment(sender, receiver, amount, tokenId);
    };

    // Get the status of a payment
    public func getPaymentStatus(paymentId: Nat): async Result.Result<Text, Text> {
        await paymentManager.getPaymentStatus(paymentId);
    };

    // Retrieve payment history for a user
    public func getPaymentHistory(userId: Principal): async Result.Result<[PaymentModule.Payment], Text> {
        let history = await paymentManager.getPaymentHistory(userId);
        switch (history) {
            case (#ok(payments)) {
                #ok(Array.tabulate(payments.size(), func(i) = payments[i]));
            };
            case (#err(error)) {
                #err(error);
            };
        }
    };
};