import SubscriptionModule "modules/subscription_module";
import SubscriptionService "services/subscription_service";
import UserCanisterProxy "../user/utils/user_canister_proxy";
import Principal "mo:base/Principal";
import EventManager "../heartbeat/event_manager";
import LoggingUtils "../utils/logging_utils";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import _Iter "mo:base/Iter";

actor {
    // Initialize Event Manager
    private let _eventManager = EventManager.EventManager();

    // Initialize the User Proxy for user-related operations
private let userProxy = UserCanisterProxy.UserCanisterProxy(Principal.fromText("xad5d-bh777-77774-qaaia-cai"));

// Initialize Subscription Service with the correct dependency
private let subscriptionService = SubscriptionService.createSubscriptionService(userProxy);

    // Logging utility
    private let _logStore = LoggingUtils.init();

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
};