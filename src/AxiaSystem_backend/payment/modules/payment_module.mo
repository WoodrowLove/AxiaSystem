import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Option "mo:base/Option";
import _ValidationUtils "../../utils/validation_utils";
import LoggingUtils "../../utils/logging_utils";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import UserCanisterProxy "../../user/utils/user_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";

module {
    public type PaymentTransaction = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        amount: Nat;
        tokenId: ?Nat;
        timestamp: Int;
        status: Text; // "Pending", "Completed", "Failed"
        description: ?Text;
    };

    public type Escrow = {
        id: Nat;
        payer: Principal;
        payee: Principal;
        amount: Nat;
        tokenId: ?Nat;
        releaseConditions: Text;
        status: Text; // "Held", "Released", "Cancelled"
        createdAt: Int;
        updatedAt: Int;
    };

    public type PaymentManagerInterface = {
        initiatePayment: (Principal, Principal, Nat, ?Nat, ?Text) -> async Result.Result<PaymentTransaction, Text>;
        completePayment: (Nat) -> async Result.Result<(), Text>;
        getPaymentHistory: (Principal) -> async [PaymentTransaction];
        initiateEscrow: (Principal, Principal, Nat, ?Nat, Text) -> async Result.Result<Escrow, Text>;
        releaseEscrow: (Nat) -> async Result.Result<(), Text>;
        cancelEscrow: (Nat) -> async Result.Result<(), Text>;
    };

    public class PaymentManager(
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        _userProxy: UserCanisterProxy.UserCanisterProxyManager,
        _tokenProxy: TokenCanisterProxy.TokenCanisterProxy
    ) : PaymentManagerInterface {
        private var transactions: [PaymentTransaction] = [];
        private var escrows: [Escrow] = [];
        private var logStore = LoggingUtils.init();

        // Initiate a payment
        public func initiatePayment(
    sender: Principal,
    receiver: Principal,
    amount: Nat,
    tokenId: ?Nat,
    description: ?Text
): async Result.Result<PaymentTransaction, Text> {
    if (amount <= 0) {
        return #err("Invalid payment amount");
    };

    // Ensure walletProxy is properly initialized at the class or actor level
    // let walletProxy = WalletCanisterProxy.WalletCanisterProxy(walletCanisterId);

    // Debit the sender's wallet
    let debitResult = await walletProxy.debitWallet(sender, amount, Option.get(tokenId, 0));
    switch (debitResult) {
        case (#err(e)) {
            LoggingUtils.logError(logStore, "PaymentModule", "Debit failed for sender " # Principal.toText(sender) # ": " # e, null);
            return #err("Failed to debit sender: " # e);
        };
        case (#ok(_)) {};
    };

    // Credit the receiver's wallet
    let creditResult = await walletProxy.creditWallet(receiver, amount, Option.get(tokenId, 0));
    switch (creditResult) {
        case (#err(e)) {
            // Rollback debit in case of failure
            ignore await walletProxy.creditWallet(sender, amount, Option.get(tokenId, 0));
            LoggingUtils.logError(logStore, "PaymentModule", "Credit failed for receiver " # Principal.toText(receiver) # ": " # e, null);
            return #err("Failed to credit receiver: " # e);
        };
        case (#ok(_)) {};
    };

    // Log and save the transaction
    let transaction: PaymentTransaction = {
        id = Int.abs(Time.now()); // Use timestamp as unique ID
        sender = sender;
        receiver = receiver;
        amount = amount;
        tokenId = tokenId;
        timestamp = Time.now();
        status = "Completed";
        description = description;
    };

    transactions := Array.append(transactions, [transaction]);
    LoggingUtils.logInfo(logStore, "PaymentModule", "Payment completed", null);

    #ok(transaction)
};

        // Get payment history for a user
        public func getPaymentHistory(userId: Principal): async [PaymentTransaction] {
            Array.filter<PaymentTransaction>(transactions, func (tx: PaymentTransaction): Bool {
                tx.sender == userId or tx.receiver == userId
            });
        };

        // Initiate an escrow
        public func initiateEscrow(
            payer: Principal,
            payee: Principal,
            amount: Nat,
            tokenId: ?Nat,
            releaseConditions: Text
        ): async Result.Result<Escrow, Text> {
            if (amount <= 0) {
                return #err("Invalid escrow amount");
            };

            // Debit the payer's wallet
            let debitResult = await walletProxy.debitWallet(payer, amount, Option.get(tokenId, 0));
            switch (debitResult) {
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "PaymentModule", "Debit failed for payer " # Principal.toText(payer) # ": " # e, null);
                    return #err("Failed to debit payer: " # e);
                };
                case (#ok(_)) {};
            };

            // Save escrow record
            let escrow: Escrow = {
                id = Int.abs(Time.now());
                payer = payer;
                payee = payee;
                amount = amount;
                tokenId = tokenId;
                releaseConditions = releaseConditions;
                status = "Held";
                createdAt = Time.now();
                updatedAt = Time.now();
            };

            escrows := Array.append(escrows, [escrow]);
            LoggingUtils.logInfo(logStore, "PaymentModule", "Escrow initiated: " # Nat.toText(escrow.id), null);

            #ok(escrow)
        };

        // Release an escrow
        public func releaseEscrow(escrowId: Nat): async Result.Result<(), Text> {
            let escrowOpt = Array.find<Escrow>(escrows, func (esc: Escrow): Bool { esc.id == escrowId });
            switch (escrowOpt) {
                case null #err("Escrow not found");
                case (?escrow) {
                    if (escrow.status != "Held") {
                        return #err("Escrow cannot be released in its current state");
                    };

                    // Credit the payee's wallet
                    let creditResult = await walletProxy.creditWallet(escrow.payee, escrow.amount, Option.get(escrow.tokenId, 0));
                    switch (creditResult) {
                        case (#err(e)) {
                            LoggingUtils.logError(logStore, "PaymentModule", "Failed to release escrow " # Nat.toText(escrowId) # ": " # e, null);
                            return #err("Failed to release escrow: " # e);
                        };
                        case (#ok(_)) {};
                    };

                    // Update escrow status
                    let updatedEscrow = { escrow with status = "Released"; updatedAt = Time.now() };
                    escrows := Array.map<Escrow, Escrow>(escrows, func (e: Escrow): Escrow {
                        if (e.id == escrowId) updatedEscrow else e
                    });

                    LoggingUtils.logInfo(logStore, "PaymentModule", "Escrow released: " # Nat.toText(escrowId), null);
                    #ok(())
                };
            };
        };

        // Cancel an escrow
        public func cancelEscrow(escrowId: Nat): async Result.Result<(), Text> {
            let escrowOpt = Array.find<Escrow>(escrows, func(e : Escrow) { e.id == escrowId });
            switch (escrowOpt) {
                case (?_escrow) {
                    escrows := Array.filter<Escrow>(escrows, func(e : Escrow) { e.id != escrowId });
                    #ok(())
                };
                case null #err("Escrow not found");
            };
        };

        // Complete a payment
        public func completePayment(paymentId: Nat): async Result.Result<(), Text> {
    let paymentOpt = Array.find<PaymentTransaction>(transactions, func(p : PaymentTransaction) { p.id == paymentId });
    switch (paymentOpt) {
        case (?_payment) {
            transactions := Array.filter<PaymentTransaction>(transactions, func(p : PaymentTransaction) { p.id != paymentId });
            #ok(())
        };
        case null #err("Payment not found")
    }
};
    };
};