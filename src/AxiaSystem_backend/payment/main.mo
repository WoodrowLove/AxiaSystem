import PaymentModule "./modules/payment_module";
import WalletCanisterProxy "../wallet/utils/wallet_canister_proxy";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import TokenCanisterProxy "../token/utils/token_canister_proxy";
import EventManager "../heartbeat/event_manager";
import EventTypes "../heartbeat/event_types";
import RefundModule "../modules/refund_module";
import TriadShared "../types/triad_shared";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import LoggingUtils "../utils/logging_utils";

// 🧠 NamoraAI Observability Imports
import Insight "../types/insight";
import Time "mo:base/Time";


persistent actor PaymentCanister {

    // 🧠 NamoraAI Observability Helper
    private func emitInsight(severity: Text, message: Text) : async () {
        let _insight : Insight.SystemInsight = {
            source = "payment";
            severity = severity;
            message = message;
            timestamp = Time.now();
        };
        Debug.print("🧠 PAYMENT INSIGHT [" # severity # "]: " # message);
        // await NamoraAI.pushInsight(insight);
    };

    // Helper function to convert TriadError to Text for legacy API compatibility
    private func triadErrorToText(error: TriadShared.TriadError): Text {
        switch (error) {
            case (#NotFound(details)) "Not found: " # details.resource # " with ID " # details.id;
            case (#Unauthorized(details)) "Unauthorized: " # details.operationType # " for principal " # Principal.toText(details.principal);
            case (#Conflict(details)) "Conflict: " # details.reason # " (current state: " # details.currentState # ")";
            case (#Invalid(details)) "Invalid " # details.field # ": " # details.reason # " (value: " # details.value # ")";
            case (#Upstream(details)) "Upstream error from " # details.systemName # ": " # details.error;
            case (#Transient(details)) "Transient error in " # details.operationType # " operation" # (switch (details.retryAfter) { case (?after) " (retry after " # Nat64.toText(after) # "ms)"; case (null) "" });
            case (#Internal(details)) "Internal error [" # details.code # "]: " # details.message;
            case (#Capacity(details)) "Capacity exceeded: " # details.resource # " (" # Nat.toText(details.current) # "/" # Nat.toText(details.limit) # ")";
            case (#Timeout(details)) "Timeout in " # details.operationType # " operation (" # Nat64.toText(details.duration) # "ms)";
        }
    };

    // Instantiate proxies for inter-canister communication
    private transient let walletProxy = WalletCanisterProxy.WalletCanisterProxy(
    Principal.fromText("xhc3x-m7777-77774-qaaiq-cai"), // Wallet Canister ID
    Principal.fromText("xad5d-bh777-77774-qaaia-cai")  // User Canister ID
);
    private transient let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("xad5d-bh777-77774-qaaia-cai"));
    private transient let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("v27v7-7x777-77774-qaaha-cai"));

   transient let logstore : LoggingUtils.LogStore = LoggingUtils.init();

    // Initialize the Payment Manager
    private transient let paymentManager = PaymentModule.PaymentManager(walletProxy, userProxy, tokenProxy);

    // Initialize the Event Manager  
    private transient let eventManager = EventManager.EventManager();

    // Initialize the Refund Manager
    private transient let refundManager = RefundModule.RefundManager("Payment", eventManager);

    // Initiate a payment
    public func initiatePayment(
    sender: Principal,
    receiver: Principal,
    amount: Nat,
    tokenId: ?Nat,
    description: ?Text
): async Result.Result<PaymentModule.PaymentTransaction, Text> {
    await emitInsight("info", "Payment initiation requested from " # Principal.toText(sender) # " to " # Principal.toText(receiver) # " for amount: " # Nat.toText(amount));
    
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
                await emitInsight("info", "Payment successfully initiated - Transaction ID: " # Nat.toText(transaction.id) # ", Amount: " # Nat.toText(amount));
                #ok(transaction)
            };
            case (#err(e)) {
                LoggingUtils.logInfo(
                    logstore,
                    "Failed to initiate payment: " # e,
                    "PaymentCanister",
                    ?sender
                );
                await emitInsight("error", "Payment initiation failed from " # Principal.toText(sender) # " to " # Principal.toText(receiver) # " - " # e);
                #err(e)
            };
        }
    } catch (error) {
        await emitInsight("error", "Payment system error - " # Error.message(error));
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

    // =====================================
    // REFUND MANAGEMENT FUNCTIONS
    // =====================================

    // Create a refund request for a payment
    public func createRefundRequest(
        paymentId: Nat,
        requestedBy: Principal, 
        amount: Nat,
        refundSource: ?RefundModule.RefundSource, // New parameter for refund source
        reason: ?Text
    ): async Result.Result<Nat, Text> {
        await emitInsight("info", "Refund request creation attempted for payment ID: " # Nat.toText(paymentId) # " by " # Principal.toText(requestedBy));
        
        try {
            // Default to user funds if not specified
            let source = switch (refundSource) {
                case (?src) src;
                case (null) #UserFunds({ 
                    fromUser = requestedBy; 
                    context = null 
                });
            };

            let result = await refundManager.createRefundRequest(paymentId, requestedBy, amount, source, reason);
            switch (result) {
                case (#ok(refundId)) {
                    await emitInsight("info", "Refund request created successfully with ID: " # Nat.toText(refundId));
                    #ok(refundId)
                };
                case (#err(e)) {
                    let errorText = triadErrorToText(e);
                    await emitInsight("error", "Refund request creation failed: " # errorText);
                    #err(errorText)
                };
            }
        } catch (error) {
            await emitInsight("error", "Refund request creation error: " # Error.message(error));
            #err("Failed to create refund request: " # Error.message(error))
        }
    };

    // Create a treasury-funded refund (for admin use)
    public func createTreasuryRefund(
        paymentId: Nat,
        requestedBy: Principal,
        amount: Nat,
        requiresApproval: Bool,
        reason: ?Text
    ): async Result.Result<Nat, Text> {
        await emitInsight("info", "Treasury refund creation attempted for payment ID: " # Nat.toText(paymentId));
        
        try {
            let treasurySource = #Treasury({ 
                requiresApproval = requiresApproval; 
                context = null 
            });
            let result = await refundManager.createRefundRequest(paymentId, requestedBy, amount, treasurySource, reason);
            
            switch (result) {
                case (#ok(refundId)) {
                    await emitInsight("info", "Treasury refund request created successfully with ID: " # Nat.toText(refundId));
                    #ok(refundId)
                };
                case (#err(e)) {
                    let errorText = triadErrorToText(e);
                    await emitInsight("error", "Treasury refund creation failed: " # errorText);
                    #err(errorText)
                };
            }
        } catch (error) {
            await emitInsight("error", "Treasury refund creation error: " # Error.message(error));
            #err("Failed to create treasury refund: " # Error.message(error))
        }
    };

    // List refund requests with filtering
    public func listRefundRequests(
        status: ?Text,
        requestedBy: ?Principal,
        fromDate: ?Int,
        toDate: ?Int,
        offset: Nat,
        limit: Nat
    ): async Result.Result<[RefundModule.RefundRequest], Text> {
        try {
            await refundManager.listRefundRequests(status, requestedBy, fromDate, toDate, offset, limit)
        } catch (error) {
            #err("Failed to list refund requests: " # Error.message(error))
        }
    };

    // Get specific refund request
    public func getRefundRequest(requestId: Nat): async Result.Result<RefundModule.RefundRequest, Text> {
        try {
            await refundManager.getRefundRequest(requestId)
        } catch (error) {
            #err("Failed to get refund request: " # Error.message(error))
        }
    };

    // Approve a refund request (admin only)
    public func approveRefundRequest(
        requestId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await emitInsight("info", "Refund request approval attempted for ID: " # Nat.toText(requestId) # " by admin: " # Principal.toText(adminPrincipal));
        
        try {
            let result = await refundManager.approveRefundRequest(requestId, adminPrincipal, adminNote);
            switch (result) {
                case (#ok(())) {
                    await emitInsight("info", "Refund request ID: " # Nat.toText(requestId) # " approved successfully");
                    #ok(())
                };
                case (#err(e)) {
                    let errorText = triadErrorToText(e);
                    await emitInsight("error", "Refund request approval failed: " # errorText);
                    #err(errorText)
                };
            }
        } catch (error) {
            await emitInsight("error", "Refund request approval error: " # Error.message(error));
            #err("Failed to approve refund request: " # Error.message(error))
        }
    };

    // Deny a refund request (admin only)
    public func denyRefundRequest(
        requestId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await emitInsight("info", "Refund request denial attempted for ID: " # Nat.toText(requestId) # " by admin: " # Principal.toText(adminPrincipal));
        
        try {
            let result = await refundManager.denyRefundRequest(requestId, adminPrincipal, adminNote);
            switch (result) {
                case (#ok(())) {
                    await emitInsight("info", "Refund request ID: " # Nat.toText(requestId) # " denied successfully");
                    #ok(())
                };
                case (#err(e)) {
                    let errorText = triadErrorToText(e);
                    await emitInsight("error", "Refund request denial failed: " # errorText);
                    #err(errorText)
                };
            }
        } catch (error) {
            await emitInsight("error", "Refund request denial error: " # Error.message(error));
            #err("Failed to deny refund request: " # Error.message(error))
        }
    };

    // Process approved refund (execute the actual refund)
    public func processApprovedRefund(requestId: Nat): async Result.Result<(), Text> {
        await emitInsight("info", "Processing approved refund for request ID: " # Nat.toText(requestId));
        
        try {
            // Get the refund request
            let refundResult = await refundManager.getRefundRequest(requestId);
            switch (refundResult) {
                case (#ok(request)) {
                    if (request.status != "Approved") {
                        return #err("Only approved refunds can be processed");
                    };

                    // Mark as processing
                    ignore await refundManager.markRefundProcessed(requestId, false, ?"Processing");

                    // Execute the refund using the existing reversePayment logic
                    let reverseResult = await paymentManager.reversePayment(request.originId);
                    switch (reverseResult) {
                        case (#ok(())) {
                            // Mark as completed
                            ignore await refundManager.markRefundProcessed(requestId, true, null);
                            await emitInsight("info", "Refund processed successfully for request ID: " # Nat.toText(requestId));
                            #ok(())
                        };
                        case (#err(e)) {
                            // Mark as failed
                            ignore await refundManager.markRefundProcessed(requestId, false, ?e);
                            await emitInsight("error", "Refund processing failed for request ID: " # Nat.toText(requestId) # " - " # e);
                            #err("Failed to process refund: " # e)
                        };
                    }
                };
                case (#err(e)) {
                    await emitInsight("error", "Failed to get refund request: " # e);
                    #err("Failed to get refund request: " # e)
                };
            }
        } catch (error) {
            await emitInsight("error", "Refund processing error: " # Error.message(error));
            #err("Failed to process refund: " # Error.message(error))
        }
    };

    // Get refund statistics for admin dashboard
    public func getRefundStats(): async RefundModule.RefundStats {
        await refundManager.getRefundStats()
    };

 public shared func onPaymentProcessed(event: EventTypes.Event) : async () {
    switch (event.payload) {
      case (#PaymentProcessed { userId; amount; walletId }) {
        Debug.print("Payment processed for user: " # Principal.toText(userId) # ", Amount: " # Nat.toText(amount) #
        ", Wallet ID: " # walletId);
      };
      case (_) {}; // Ignore other events
    };
  };

  public func initializeEventListeners() : async () {
    // Subscribe to the event using the public shared function
    await eventManager.subscribe(#PaymentProcessed, onPaymentProcessed);
    // You can add more event subscriptions here if needed
  };
   /* public func runTests() : async () {
        await InitiatePaymentTest.run();
    
};*/
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