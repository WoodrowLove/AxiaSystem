import SubscriptionModule "modules/subscription_module";
import SubscriptionService "services/subscription_service";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import RefundModule "../modules/refund_module";
import TreasuryRefundProcessor "../modules/treasury_refund_processor";
import Principal "mo:base/Principal";
import EventManager "../heartbeat/event_manager";
import LoggingUtils "../utils/logging_utils";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Error "mo:base/Error";
import _Iter "mo:base/Iter";

persistent actor {
    // Initialize Event Manager
    private transient let _eventManager = EventManager.EventManager();

    // Initialize the User Proxy for user-related operations
    private transient let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("xad5d-bh777-77774-qaaia-cai"));

    // Initialize Subscription Service with the correct dependency
    private transient let subscriptionService = SubscriptionService.createSubscriptionService(userProxy);

    // Initialize Refund Manager for subscription refunds
    private transient let refundManager = RefundModule.RefundManager("Subscription", _eventManager);

    // Treasury and Wallet interfaces for refund processing
    private transient let treasuryCanister: TreasuryRefundProcessor.TreasuryInterface = 
        actor (Principal.toText(Principal.fromText("xhc3x-m7777-77774-qaaiq-cai")));
    
    private transient let walletCanister: TreasuryRefundProcessor.WalletInterface = 
        actor (Principal.toText(Principal.fromText("xjaw7-xp777-77774-qaajq-cai")));

    // Initialize Treasury Refund Processor
    private transient let refundProcessor = TreasuryRefundProcessor.TreasuryRefundProcessor(
        treasuryCanister,
        walletCanister,
        _eventManager
    );

    // Logging utility
    private transient let _logStore = LoggingUtils.init();

    // Public API: Create a subscription
    public func createSubscription(userId: Principal, duration: Int): async Result.Result<SubscriptionModule.Subscription, Text> {
        await subscriptionService.createSubscription(userId, duration);
    };

    // Public API: Check if a user is subscribed
    public func isSubscribed(userId: Principal): async Result.Result<Bool, Text> {
        await subscriptionService.isSubscribed(userId);
    };

    // Public API: Update a subscription
    public func updateSubscription(userId: Principal, newEndDate: Int): async Result.Result<(), Text> {
        await subscriptionService.updateSubscription(userId, newEndDate);
    };

    // Public API: Validate a subscription
    public func validateSubscription(userId: Principal): async Result.Result<(), Text> {
        await subscriptionService.validateSubscription(userId);
    };

    // Public API: Expire outdated subscriptions
    public func expireSubscriptions(): async Result.Result<Nat, Text> {
        await subscriptionService.expireSubscriptions();
    };

    // Public API: Attach a subscription to a user
    public func attachSubscriptionToUser(userId: Principal, subscription: SubscriptionModule.Subscription): async Result.Result<(), Text> {
        await subscriptionService.attachSubscriptionToUser(userId, subscription);
    };

    // Public API: Get subscription details
    public func getSubscriptionDetails(userId: Principal): async Result.Result<SubscriptionModule.Subscription, Text> {
        await subscriptionService.getSubscriptionDetails(userId);
    };

    // Public API: Cancel a subscription
    public func cancelSubscription(userId: Principal): async Result.Result<(), Text> {
        await subscriptionService.cancelSubscription(userId);
    };

    // Public API: Get all active subscriptions
    public func getActiveSubscriptions(): async [(Principal, SubscriptionModule.Subscription)] {
        await subscriptionService.getActiveSubscriptions();
    };

    // Public API: Get all subscriptions (active and expired)
    public func getAllSubscriptions(): async [(Principal, SubscriptionModule.Subscription)] {
        await subscriptionService.getAllSubscriptions();
    };

    // SUBSCRIPTION REFUND FUNCTIONS

    // Create a subscription refund request
    public func createSubscriptionRefund(
        subscriptionId: Nat,
        userId: Principal,
        refundAmount: Nat,
        refundType: Text, // "Cancellation" | "Prorated" | "ServiceCredit"
        reason: ?Text
    ): async Result.Result<Nat, Text> {
        LoggingUtils.logInfo(
            _logStore,
            "SubscriptionsCanister",
            "Subscription refund request for user: " # Principal.toText(userId) # 
            " amount: " # Nat.toText(refundAmount) # " type: " # refundType,
            ?userId
        );

        try {
            let result = await refundManager.createSubscriptionRefund(
                subscriptionId,
                userId,
                refundAmount,
                refundType,
                reason
            );
            
            switch (result) {
                case (#ok(refundId)) {
                    LoggingUtils.logInfo(
                        _logStore,
                        "SubscriptionsCanister",
                        "Subscription refund request created with ID: " # Nat.toText(refundId),
                        ?userId
                    );
                    #ok(refundId)
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        _logStore,
                        "SubscriptionsCanister",
                        "Failed to create subscription refund: " # e,
                        ?userId
                    );
                    #err(e)
                };
            }
        } catch (error) {
            let errorMsg = "Subscription refund creation error: " # Error.message(error);
            LoggingUtils.logError(_logStore, "SubscriptionsCanister", errorMsg, ?userId);
            #err(errorMsg)
        }
    };

    // Calculate prorated refund amount for early cancellation
    public func calculateProratedRefund(
        userId: Principal,
        subscriptionCost: Nat
    ): async Result.Result<Nat, Text> {
        try {
            let subscriptionResult = await subscriptionService.getSubscriptionDetails(userId);
            switch (subscriptionResult) {
                case (#ok(subscription)) {
                    let currentTime = Time.now();
                    let remainingTime = subscription.endDate - currentTime;
                    let totalDuration = subscription.endDate - subscription.startDate;
                    
                    if (remainingTime <= 0) {
                        #ok(0) // No refund for expired subscriptions
                    } else {
                        // Calculate prorated amount using absolute values
                        let remainingTimeNat = Int.abs(remainingTime);
                        let totalDurationNat = Int.abs(totalDuration);
                        let refundAmount = (subscriptionCost * remainingTimeNat) / totalDurationNat;
                        #ok(refundAmount)
                    };
                };
                case (#err(e)) #err("Cannot calculate refund: " # e);
            }
        } catch (error) {
            #err("Error calculating prorated refund: " # Error.message(error))
        }
    };

    // Cancel subscription with automatic refund
    public func cancelSubscriptionWithRefund(
        userId: Principal,
        subscriptionCost: Nat,
        reason: ?Text
    ): async Result.Result<{ cancellationResult: (); refundId: ?Nat }, Text> {
        try {
            // First cancel the subscription
            let cancelResult = await subscriptionService.cancelSubscription(userId);
            switch (cancelResult) {
                case (#ok(())) {
                    // Calculate prorated refund
                    let refundAmountResult = await calculateProratedRefund(userId, subscriptionCost);
                    switch (refundAmountResult) {
                        case (#ok(refundAmount)) {
                            if (refundAmount > 0) {
                                // Create refund request
                                let refundResult = await createSubscriptionRefund(
                                    0, // subscriptionId - you might want to add this to your subscription type
                                    userId,
                                    refundAmount,
                                    "Prorated",
                                    reason
                                );
                                
                                switch (refundResult) {
                                    case (#ok(refundId)) {
                                        #ok({ cancellationResult = (); refundId = ?refundId })
                                    };
                                    case (#err(e)) {
                                        // Subscription was cancelled but refund failed
                                        LoggingUtils.logError(
                                            _logStore,
                                            "SubscriptionsCanister",
                                            "Subscription cancelled but refund failed: " # e,
                                            ?userId
                                        );
                                        #ok({ cancellationResult = (); refundId = null })
                                    };
                                }
                            } else {
                                #ok({ cancellationResult = (); refundId = null }) // No refund needed
                            };
                        };
                        case (#err(e)) {
                            // Subscription was cancelled but refund calculation failed
                            LoggingUtils.logError(
                                _logStore,
                                "SubscriptionsCanister",
                                "Refund calculation failed: " # e,
                                ?userId
                            );
                            #ok({ cancellationResult = (); refundId = null })
                        };
                    }
                };
                case (#err(e)) #err("Failed to cancel subscription: " # e);
            }
        } catch (error) {
            #err("Error during subscription cancellation with refund: " # Error.message(error))
        }
    };

    // Process all approved subscription refunds
    public func processSubscriptionRefunds(): async Result.Result<[Nat], Text> {
        LoggingUtils.logInfo(
            _logStore,
            "SubscriptionsCanister",
            "Processing approved subscription refunds",
            null
        );

        try {
            let result = await refundProcessor.processApprovedTreasuryRefunds(refundManager);
            switch (result) {
                case (#ok(processedIds)) {
                    LoggingUtils.logInfo(
                        _logStore,
                        "SubscriptionsCanister",
                        "Processed " # Nat.toText(processedIds.size()) # " subscription refunds",
                        null
                    );
                    #ok(processedIds)
                };
                case (#err(e)) {
                    LoggingUtils.logError(
                        _logStore,
                        "SubscriptionsCanister",
                        "Failed to process subscription refunds: " # e,
                        null
                    );
                    #err(e)
                };
            }
        } catch (error) {
            #err("Error processing subscription refunds: " # Error.message(error))
        }
    };

    // Auto-process eligible subscription refunds
    public func autoProcessSubscriptionRefunds(): async Result.Result<[Nat], Text> {
        try {
            await refundProcessor.autoProcessEligibleRefunds(refundManager)
        } catch (error) {
            #err("Error auto-processing subscription refunds: " # Error.message(error))
        }
    };

    // List subscription refund requests
    public func listSubscriptionRefunds(
        status: ?Text,
        requestedBy: ?Principal,
        fromDate: ?Int,
        toDate: ?Int,
        offset: Nat,
        limit: Nat
    ): async Result.Result<[RefundModule.RefundRequest], Text> {
        await refundManager.listRefundRequests(status, requestedBy, fromDate, toDate, offset, limit)
    };

    // Approve a subscription refund
    public func approveSubscriptionRefund(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await refundManager.approveRefundRequest(refundId, adminPrincipal, adminNote)
    };

    // Deny a subscription refund
    public func denySubscriptionRefund(
        refundId: Nat,
        adminPrincipal: Principal,
        adminNote: ?Text
    ): async Result.Result<(), Text> {
        await refundManager.denyRefundRequest(refundId, adminPrincipal, adminNote)
    };

    // Get subscription refund statistics
    public func getSubscriptionRefundStats(): async RefundModule.RefundStats {
        await refundManager.getRefundStats()
    };
};