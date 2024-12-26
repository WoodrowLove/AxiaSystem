import PaymentModule "./modules/payment_module";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import LoggingUtils "../utils/logging_utils";
import InitiatePaymentTest "../tests/payment/initiate_payment_test";

actor PaymentCanister {
    // Instantiate proxies for inter-canister communication
    private let walletProxy = WalletCanisterProxy.WalletCanisterProxy(Principal.fromText("bw4dl-smaaa-aaaaa-qaacq-cai"));
    private let userProxy = UserCanisterProxy.UserCanisterProxyManager(Principal.fromText("br5f7-7uaaa-aaaaa-qaaca-cai"));
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai"));

    let logstore : LoggingUtils.LogStore = LoggingUtils.init();

    // Initialize the Payment Manager
    private let paymentManager = PaymentModule.PaymentManager(walletProxy, userProxy, tokenProxy);

    // Initiate a payment
    public func initiatePayment(
    sender: Principal,
    receiver: Principal,
    amount: Nat,
    tokenId: ?Nat,
    description: ?Text
): async Result.Result<PaymentModule.PaymentTransaction, Text> {
    try {
        let result = await paymentManager.initiatePayment(sender, receiver, amount, tokenId, description);
        switch result {
            case (#ok(transaction)) {
    LoggingUtils.logInfo(
        logstore,
        "Payment initiated successfully. Transaction ID: " # Nat.toText(transaction.id),
        "PaymentCanister",
        ?sender
    );
    #ok(transaction)
};
case (#err(e)) {
    LoggingUtils.logInfo(
        logstore,
        "Failed to initiate payment: " # e,
        "PaymentCanister",
        ?sender
    );
    #err(e)
};
        }
    } catch (error) {
        #err("Failed to initiate payment: " # Error.message(error))
    }
};

    // Get the status of a payment
    public func getPaymentStatus(paymentId: Nat): async Result.Result<Text, Text> {
        try {
            await paymentManager.getPaymentStatus(paymentId);
        } catch (error) {
            #err("Failed to get payment status: " # Error.message(error))
        }
    };

    // Retrieve payment history for a user
    public func getPaymentHistory(userId: Principal): async Result.Result<[PaymentModule.PaymentTransaction], Text> {
        try {
            let history = await paymentManager.getPaymentHistory(userId);
            #ok(history)
        } catch (error) {
            #err("Failed to fetch payment history: " # Error.message(error))
        }
    };

    // Retrieve all payments with optional filters (e.g., status or date range)
   public func getAllPayments(
    user: Principal,
    filterByStatus: ?Text,
    fromDate: ?Nat,
    toDate: ?Nat
): async Result.Result<[PaymentModule.PaymentTransaction], Text> {
    try {
        let result = await paymentManager.getAllPayments();
        let filteredPayments = Array.filter<PaymentModule.PaymentTransaction>(result, func(tx: PaymentModule.PaymentTransaction): Bool {
            let matchesStatus = switch (filterByStatus) {
                case (?status) tx.status == status;
                case null true;
            };
            let matchesFromDate = switch (fromDate) {
                case (?from) tx.timestamp >= from;
                case null true;
            };
            let matchesToDate = switch (toDate) {
                case (?to) tx.timestamp <= to;
                case null true;
            };
            matchesStatus and matchesFromDate and matchesToDate
        });

        LoggingUtils.logInfo(
            logstore,
            "Filtered payments fetched successfully",
            "PaymentCanister",
            ?user
        );
        #ok(filteredPayments)
    } catch (error) {
        LoggingUtils.logError(
            logstore,
            "PaymentCanister",
            "Failed to fetch all payments: " # Error.message(error),
            ?user
        );
        #err("Failed to fetch all payments")
    }
};

    // Reverse a payment
    // Reverse a payment
public func reversePayment(paymentId: Nat): async Result.Result<(), Text> {
    try {
        let result = await paymentManager.reversePayment(paymentId);
        switch result {
            case (#ok(())) {
                LoggingUtils.logInfo(
                    logstore,
                    "Payment reversed successfully. ID: " # Nat.toText(paymentId),
                    "PaymentCanister",
                    null
                );
                #ok(())
            };
            case (#err(e)) {
                LoggingUtils.logError(
                    logstore,
                    "PaymentCanister",
                    "Failed to reverse payment: " # e,
                    null
                );
                #err(e)
            };
        }
    } catch (error) {
        LoggingUtils.logError(
            logstore,
            "PaymentCanister",
            "Unexpected error while reversing payment: " # Error.message(error),
            null
        );
        #err("Failed to reverse payment: " # Error.message(error))
    }
};

    // Optional: Synchronize balances for a user
    public func synchronizeBalances(
        sender: Principal,
        receiver: Principal,
        tokenId: Nat,
        amount: Nat
    ): async Result.Result<(), Text> {
        try {
            let result = await paymentManager.synchronizeBalances(sender, receiver, tokenId, amount);
            switch result {
                case (#ok(_)) {
                    #ok(())
                };
                case (#err(e)) {
                    #err("Failed to synchronize balances: " # e)
                };
            }
        } catch (error) {
            #err("Failed to synchronize balances: " # Error.message(error))
        }
    };

    // Instantiate the Event Manager
private let eventManager = EventManager.EventManager();

// Function to initialize event listeners
public func initializeEventListeners() : async () {
    // Define the event listener function locally
    let onPaymentProcessed = func(event: EventTypes.Event) : async () {
        switch (event.payload) {
            case (#PaymentProcessed { userId; amount; walletId }) {
                Debug.print("Payment processed for user: " # Principal.toText(userId) # ", Amount: " # Nat.toText(amount) #
                ", Wallet ID: " # walletId);
            };
            case (_) {}; // Ignore other events
        };
    };

    // Subscribe to the event
    await eventManager.subscribe(#PaymentProcessed, onPaymentProcessed);
    // You can add more event subscriptions here if needed

    };

    public func runTests() : async () {
        await InitiatePaymentTest.run();
    
};
}


/* Things to update;
    1.	Event-Driven Automation:
	•	Expand the event subscription logic to trigger automated workflows, such as notifying users or triggering additional inter-canister calls.
	2.	Improved Test Coverage:
	•	Extend runTests to include additional test cases for edge scenarios (e.g., invalid inputs, network failures).
	3.	Parameter Validation:
	•	Add validation for inputs like paymentId, amount, and tokenId to prevent invalid calls from propagating.
	4.	Dynamic Canister IDs:
	•	Allow dynamic updates to canister IDs (e.g., via a configuration method) to enhance flexibility in multi-environment deployments.
	5.	Batch Operations:
	•	Introduce batch operations (e.g., bulk payment initiation or retrieval) for scalability in high-transaction environments.
	6.	Expose Metrics:
	•	Add methods to expose system metrics (e.g., total transactions, failed payments) for monitoring and debugging. */