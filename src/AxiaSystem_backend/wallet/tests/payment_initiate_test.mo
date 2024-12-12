import Matchers "mo:../../motoko-matchers/Matchers";
import MockWallet "mo:motoko-mock/MockWallet";
import PaymentModule "../../payment/modules/payment_module";
import Principal "mo:base/Principal";

actor class InitiatePaymentTest() {
    private let mockWallet = MockWallet.create();
    private let paymentManager = PaymentModule.PaymentManager(mockWallet, null, null);

    public func testValidPayment() : async Bool {
        let sender = Principal.fromText("aaaaa-aa");
        let receiver = Principal.fromText("bbbbb-bb");

        // Simulate a balance in the sender's wallet
        await mockWallet.setBalance(sender, 500);

        // Initiate a valid payment
        let result = await paymentManager.initiatePayment(sender, receiver, 100, null, ?("Test Payment"));

        // Assert success and check the result
        Matchers.expect(result).toMatch(#ok(_));
        true
    };

    public func testInsufficientFunds() : async Bool {
        let sender = Principal.fromText("aaaaa-aa");
        let receiver = Principal.fromText("bbbbb-bb");

        // Simulate insufficient balance in the sender's wallet
        await mockWallet.setBalance(sender, 50);

        // Attempt payment
        let result = await paymentManager.initiatePayment(sender, receiver, 100, null, ?("Insufficient Funds Test"));

        // Assert failure
        Matchers.expect(result).toMatch(#err("Failed to debit sender: Insufficient balance"));
        true
    };

    public func testZeroAmountPayment() : async Bool {
        let sender = Principal.fromText("aaaaa-aa");
        let receiver = Principal.fromText("bbbbb-bb");

        // Attempt payment with zero amount
        let result = await paymentManager.initiatePayment(sender, receiver, 0, null, ?("Zero Amount Test"));

        // Assert failure
        Matchers.expect(result).toMatch(#err("Invalid payment amount"));
        true
    };
};