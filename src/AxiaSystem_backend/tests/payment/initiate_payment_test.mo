import M "mo:matchers/Matchers";
import T "mo:matchers/Testable";
import Suite "mo:matchers/Suite";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import PaymentModule "../../payment/modules/payment_module";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import LoggingUtils "../../utils/logging_utils";

// Mocks for dependencies
module WalletMock {
    public func debitWallet(user: Principal, amount: Nat, tokenId: Nat): async Result.Result<(), Text> {
        if (amount > 0) {
            return #ok(());
        };
        return #err("Invalid amount");
    };

    public func creditWallet(user: Principal, amount: Nat, tokenId: Nat): async Result.Result<(), Text> {
        if (amount > 0) {
            return #ok(());
        };
        return #err("Invalid amount");
    };
};

module PaymentTest {
    private let walletProxy = WalletMock;
    private let logStore = LoggingUtils.init();
    private let paymentManager = PaymentModule.PaymentManager(walletProxy, null, null);

    public func testInitiatePaymentValid() {
        let result = await paymentManager.initiatePayment(
            Principal.fromText("aaaaa-aa"),
            Principal.fromText("bbbbb-bb"),
            100,
            ?1,
            ?Text("Test payment")
        );

        Assert.equal(result, #ok({
            id = _; // Ignore ID for this test
            sender = Principal.fromText("aaaaa-aa");
            receiver = Principal.fromText("bbbbb-bb");
            amount = 100;
            tokenId = ?1;
            status = "Completed";
        }));
    };

    public func testInitiatePaymentInvalidAmount() {
        let result = await paymentManager.initiatePayment(
            Principal.fromText("aaaaa-aa"),
            Principal.fromText("bbbbb-bb"),
            0,
            ?1,
            ?Text("Test payment")
        );

        Assert.equal(result, #err("Invalid payment amount"));
    };
};

// Register tests
Test.suite("Payment Module Tests", func() {
    Test.test("Valid Payment", PaymentTest.testInitiatePaymentValid);
    Test.test("Invalid Payment Amount", PaymentTest.testInitiatePaymentInvalidAmount)
});