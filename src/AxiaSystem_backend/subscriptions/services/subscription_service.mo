import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Result "mo:base/Result";
import _Time "mo:base/Time";
import _Iter "mo:base/Iter";
import _LoggingUtils "../../utils/logging_utils";
import UserCanisterProxy "../../user/utils/user_canister_proxy";
import SubscriptionModule "../modules/subscription_module";

module {
    public func createSubscriptionService(
        userProxy: UserCanisterProxy.UserCanisterProxy
    ): SubscriptionModule.SubscriptionManager {
        SubscriptionModule.SubscriptionManager(userProxy)
    };

    // Create a new subscription for a user
    public func createSubscription(
        subscriptionManager: SubscriptionModule.SubscriptionManager,
        userId: Principal,
        duration: Int
    ): async Result.Result<SubscriptionModule.Subscription, Text> {
        await subscriptionManager.createSubscription(userId, duration);
    };

    // Check if a user can create a new subscription
    public func canCreateSubscription(
        subscriptionManager: SubscriptionModule.SubscriptionManager,
        userId: Principal
    ): async Result.Result<Bool, Text> {
        await subscriptionManager.canCreateSubscription(userId);
    };

    // Update an existing subscription for a user
    public func updateSubscription(
        subscriptionManager: SubscriptionModule.SubscriptionManager,
        userId: Principal,
        newEndDate: Int
    ): async Result.Result<(), Text> {
        await subscriptionManager.updateSubscription(userId, newEndDate);
    };

    // Validate if a user's subscription is active
    public func validateSubscription(
        subscriptionManager: SubscriptionModule.SubscriptionManager,
        userId: Principal
    ): async Result.Result<(), Text> {
        await subscriptionManager.validateSubscription(userId);
    };

    // Expire all outdated subscriptions
    public func expireSubscriptions(
        subscriptionManager: SubscriptionModule.SubscriptionManager
    ): async Result.Result<Nat, Text> {
        await subscriptionManager.expireSubscriptions();
    };

    // Attach a subscription to a user
    public func attachSubscriptionToUser(
        subscriptionManager: SubscriptionModule.SubscriptionManager,
        userId: Principal,
        subscription: SubscriptionModule.Subscription
    ): async Result.Result<(), Text> {
        await subscriptionManager.attachSubscriptionToUser(userId, subscription);
    };

    // Get subscription details for a user
    public func getSubscriptionDetails(
        subscriptionManager: SubscriptionModule.SubscriptionManager,
        userId: Principal
    ): async Result.Result<SubscriptionModule.Subscription, Text> {
        await subscriptionManager.getSubscriptionDetails(userId);
    };

    // Cancel a subscription for a user
    public func cancelSubscription(
        subscriptionManager: SubscriptionModule.SubscriptionManager,
        userId: Principal
    ): async Result.Result<(), Text> {
        await subscriptionManager.cancelSubscription(userId);
    };

    // Get all active subscriptions
    public func getActiveSubscriptions(
        subscriptionManager: SubscriptionModule.SubscriptionManager
    ): async [(Principal, SubscriptionModule.Subscription)] {
        await subscriptionManager.getActiveSubscriptions();
    };

    // Get all subscriptions (active and expired)
    public func getAllSubscriptions(
        subscriptionManager: SubscriptionModule.SubscriptionManager
    ): async [(Principal, SubscriptionModule.Subscription)] {
        await subscriptionManager.getAllSubscriptions();
    };
};