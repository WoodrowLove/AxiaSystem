
    import Principal "mo:base/Principal";
    import Text "mo:base/Text";
    import Trie "mo:base/Trie";
    import Int "mo:base/Int";
    import Bool "mo:base/Bool";
    import Result "mo:base/Result";

    module {

    // Shared User Type
    public type User = {
        id: Principal;
        username: Text;
        email: Text;
        hashedPassword: Text;
        createdAt: Int;
        updatedAt: Int;
        icpWallet: ?Text; // Optional ICP Wallet
        tokens: Trie.Trie<Nat, Nat>;
        isActive: Bool;
    };

    // Shared Identity Type
    public type Identity = {
        id: Principal;
        metadata: Trie.Trie<Text, Text>;
        createdAt: Int;
        updatedAt: Int;
    };

    public type Subscription = {
        id: Nat;
        startDate: Int;
        endDate: Int;
        status: Text; // "Active", "Expired"
    };

    // Shared UserCanisterInterface
    public type UserCanisterInterface = actor {
        createUser: (Text, Text, Text) -> async Result.Result<User, Text>;
        getUserById: (Principal) -> async Result.Result<User, Text>;
        updateUser: (Principal, ?Text, ?Text, ?Text) -> async Result.Result<User, Text>;
        deactivateUser: (Principal) -> async Result.Result<(), Text>;
        reactivateUser: (Principal) -> async Result.Result<(), Text>;
        deleteUser: (Principal) -> async Result.Result<(), Text>;
        listAllUsers: Bool -> async Result.Result<[User], Text>;
        resetPassword: (Principal, Text) -> async Result.Result<User, Text>;
    };

    // Shared IdentityCanisterInterface
    public type IdentityCanisterInterface = actor {
        createIdentity: (Principal, Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
        updateIdentity: (Principal, Trie.Trie<Text, Text>) -> async Result.Result<Identity, Text>;
        getIdentity: (Principal) -> async ?Identity;
        getAllIdentities: () -> async [Identity];
        deleteIdentity: (Principal) -> async Result.Result<(), Text>;
        findIdentityByMetadata: (Text, Text) -> async ?Identity;
    };

     // Define the interface for the Subscription Canister
    public type SubscriptionCanisterInterface = actor {
        createSubscription: (Principal, Int) -> async Result.Result<Subscription, Text>;
        isSubscribed: (Principal) -> async Result.Result<Bool, Text>;
        updateSubscription: (Principal, Int) -> async Result.Result<(), Text>;
        validateSubscription: (Principal) -> async Result.Result<(), Text>;
        expireSubscriptions: () -> async Result.Result<Nat, Text>;
        attachSubscriptionToUser: (Principal, Subscription) -> async Result.Result<(), Text>;
        getSubscriptionDetails: (Principal) -> async Result.Result<Subscription, Text>;
        cancelSubscription: (Principal) -> async Result.Result<(), Text>;
        getActiveSubscriptions: () -> async [(Principal, Subscription)];
        getAllSubscriptions: () -> async [(Principal, Subscription)];
    };
}