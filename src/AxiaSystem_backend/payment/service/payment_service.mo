import PaymentModule "../modules/payment_module";
import WalletCanisterProxy "../../wallet/utils/wallet_canister_proxy";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";
import UserCanisterProxy "../../user/utils/user_canister_proxy";
import LoggingUtils "../../utils/logging_utils";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Error "mo:base/Error";

module {
    public class PaymentService(
        paymentManager: PaymentModule.PaymentManager,
        walletProxy: WalletCanisterProxy.WalletCanisterProxy,
        _tokenProxy: TokenCanisterProxy.TokenCanisterProxy,
        _userProxy: UserCanisterProxy.UserCanisterProxyManager
    ) {
        private let logStore = LoggingUtils.init();

        // Initiate a Payment
    public func initiatePayment(
    sender: Principal,
    receiver: Principal,
    amount: Nat,
    tokenId: ?Nat,
    description: ?Text
): async Result.Result<PaymentModule.PaymentTransaction, Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentService",
        "Attempting to initiate payment from " # Principal.toText(sender) # " to " # Principal.toText(receiver),
        ?sender
    );

    if (amount <= 0) {
        return #err("Payment amount must be greater than zero");
    };

    let result = await paymentManager.initiatePayment(sender, receiver, amount, tokenId, description);
    switch (result) {
        case (#ok(transaction)) {
            LoggingUtils.logInfo(
                logStore,
                "PaymentService",
                "Payment successfully initiated. Transaction ID: " # Nat.toText(transaction.id),
                ?sender
            );
            return #ok(transaction);
        };
        case (#err(e)) {
            if (e == "Timeout") {
                LoggingUtils.logWarning(
                    logStore,
                    "PaymentService",
                    "Payment initiation failed due to timeout. Retrying...",
                    ?sender
                );
                let timeoutResult = await timeoutPendingPayments();
                switch (timeoutResult) {
                    case (#ok(transactionId)) {
                        let timeoutTransaction : PaymentModule.PaymentTransaction = {
                            id = transactionId;
                            sender = sender;
                            receiver = receiver;
                            amount = amount;
                            tokenId = tokenId;
                            timestamp = Time.now();
                            status = "Failed";
                            description = ?("Payment timed out. " # Option.get(description, ""));
                        };
                        return #ok(timeoutTransaction);
                    };
                    case (#err(timeoutError)) {
                        return #err("Timeout handling failed: " # timeoutError);
                    };
                };
            } else {
                LoggingUtils.logError(
                    logStore,
                    "PaymentService",
                    "Failed to initiate payment: " # e,
                    ?sender
                );
                return #err(e);
            };
        };
    };
};

        // Complete a Payment
        public func completePayment(paymentId: Nat): async Result.Result<(), Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentService",
        "Completing payment ID: " # Nat.toText(paymentId),
        null
    );

    let maxRetries = 3;
    var retries = 0;

    while (retries < maxRetries) {
        let result = await paymentManager.completePayment(paymentId);
        switch (result) {
            case (#ok(())) {
                LoggingUtils.logInfo(
                    logStore,
                    "PaymentService",
                    "Payment successfully completed for ID: " # Nat.toText(paymentId),
                    null
                );
                return #ok(())
            };
            case (#err(e)) {
                retries += 1;
                LoggingUtils.logError(
                    logStore,
                    "PaymentService",
                    "Failed to complete payment. Attempt " # Nat.toText(retries) # " of " # Nat.toText(maxRetries) # ": " # e,
                    null
                );

                if (retries >= maxRetries) {
                    return #err("Failed to complete payment after " # Nat.toText(maxRetries) # " attempts: " # e);
                };
            };
        };
    };

    #err("Unexpected error during payment completion.")
};

        // Retrieve Payment History
        public func getPaymentHistory(userId: Principal): async [PaymentModule.PaymentTransaction] {
            LoggingUtils.logInfo(
                logStore,
                "PaymentService",
                "Retrieving payment history for user: " # Principal.toText(userId),
                ?userId
            );
            await paymentManager.getPaymentHistory(userId);
        };

        // Reverse Payment
        public func reversePayment(paymentId: Nat): async Result.Result<(), Text> {
            LoggingUtils.logInfo(
                logStore,
                "PaymentService",
                "Reversing payment ID: " # Nat.toText(paymentId),
                null
            );

            let reverseResult = await paymentManager.reversePayment(paymentId);
            switch (reverseResult) {
                case (#err(e)) {
                    LoggingUtils.logError(
                        logStore,
                        "PaymentService",
                        "Failed to reverse payment: " # e,
                        null
                    );
                    return #err("Failed to reverse payment: " # e);
                };
                case (#ok(_)) {
                    LoggingUtils.logInfo(
                        logStore,
                        "PaymentService",
                        "Payment reversed successfully for ID: " # Nat.toText(paymentId),
                        null
                    );
                    return #ok(());
                };
            };
        };

        // Get All Payments
       public func getAllPayments(): async Result.Result<[PaymentModule.PaymentTransaction], Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentService",
        "Retrieving all payment transactions",
        null
    );

    try {
        let transactions = await paymentManager.getAllPayments();
        LoggingUtils.logInfo(
            logStore,
            "PaymentService",
            "Successfully retrieved all payments. Total: " # Nat.toText(Array.size(transactions)),
            null
        );
        #ok(transactions)
    } catch (e) {
        let errorMsg = "Failed to retrieve payments: " # Error.message(e);
        LoggingUtils.logError(
            logStore,
            "PaymentService",
            errorMsg,
            null
        );
        #err(errorMsg)
    }
};


        // Synchronize Wallet Balances during Payments
        public func synchronizeBalances(
            sender: Principal,
            receiver: Principal,
            tokenId: Nat,
            amount: Nat
        ): async Result.Result<(), Text> {
            if (amount <= 0) {
                return #err("Invalid amount");
            };

            // Debit sender's wallet
            let debitResult = await walletProxy.debitWallet(sender, amount, tokenId);
            switch (debitResult) {
                case (#err(e)) {
                    LoggingUtils.logError(logStore, "PaymentService", "Failed to debit sender: " # e, ?sender);
                    return #err("Failed to debit sender: " # e);
                };
                case (#ok(_)) {};
            };

            // Credit receiver's wallet
            let creditResult = await walletProxy.creditWallet(receiver, amount, tokenId);
            switch (creditResult) {
                case (#err(e)) {
                    // Rollback debit if credit fails
                    ignore await walletProxy.creditWallet(sender, amount, tokenId);
                    LoggingUtils.logError(logStore, "PaymentService", "Failed to credit receiver: " # e, ?receiver);
                    return #err("Failed to credit receiver: " # e);
                };
                case (#ok(_)) #ok(());
            };
        };

        public func cleanupPendingPayments(): async Result.Result<(), Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentService",
        "Cleaning up pending payments",
        null
    );

    let pendingPayments = await paymentManager.getAllPayments();
    let now = Time.now();

    let stalePayments = Array.filter(pendingPayments, func(tx: PaymentModule.PaymentTransaction): Bool {
        tx.status == "Pending" and now - tx.timestamp > (60 * 60 * 24 * 7); // Timeout: 7 days
    });

    for (payment in stalePayments.vals()) {
        LoggingUtils.logInfo(
            logStore,
            "PaymentService",
            "Marking payment as failed due to timeout. Payment ID: " # Nat.toText(payment.id),
            null
        );

        let reverseResult = await paymentManager.reversePayment(payment.id);
        switch (reverseResult) {
            case (#ok(())) {
                LoggingUtils.logInfo(
                    logStore,
                    "PaymentService",
                    "Successfully reversed stale payment ID: " # Nat.toText(payment.id),
                    null
                );
            };
            case (#err(e)) {
                LoggingUtils.logError(
                    logStore,
                    "PaymentService",
                    "Failed to reverse stale payment ID: " # Nat.toText(payment.id) # ". Error: " # e,
                    null
                );
            };
        };
    };

    #ok(())
};


public func timeoutPendingPayments(): async Result.Result<Nat, Text> {
    LoggingUtils.logInfo(
        logStore,
        "PaymentService",
        "Initiating cleanup for pending payments",
        null
    );

    let result = await paymentManager.timeoutPendingPayments();
    switch (result) {
        case (#ok(count)) {
            LoggingUtils.logInfo(
                logStore,
                "PaymentService",
                Nat.toText(count) # " pending payments cleaned up successfully",
                null
            );
            return #ok(count);
        };
        case (#err(e)) {
            LoggingUtils.logError(
                logStore,
                "PaymentService",
                "Failed to cleanup pending payments: " # e,
                null
            );
            return #err("Failed to cleanup pending payments: " # e);
        };
    };
};

    };
};