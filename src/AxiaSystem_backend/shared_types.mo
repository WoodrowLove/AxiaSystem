import Trie "mo:base/Trie";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import List "mo:base/List";

module {
    // User related types
    public type User = {
        id: Principal;
        username: Text;
        email: Text;
        hashedPassword: Text;
        createdAt: Time.Time;
        updatedAt: Time.Time;
        icpWallet: ?Text;
        tokens: Trie.Trie<Nat, Nat>;
        isActive: Bool;
        isVerified: Bool;
        
    };

    public type Session = {
        userId: Principal;
        token: Text;
        expiresAt: Int;
    };

    // Token related types
    public type Token = {
        id: Nat;
        name: Text;
        symbol: Text;
        totalSupply: Nat;
        decimals: Nat;
        owner: Principal;
        isActive: Bool;
        balances: Trie.Trie<Principal, Nat>;
    };

     public type LockedToken = {
        tokenId: Nat;
        amount: Nat;
        lockedBy: Principal;
        owner: Principal;
    };


    public type LogEntry = {
        timestamp: Nat;
        event: Text;
        details: ?Text;
    };

    // WalletTransaction
    public type WalletTransaction = {
        id: Nat;
        amount: Int;
        timestamp: Nat;
        description: Text;
    };

    // Wallet (from wallet module)
    public type Wallet = {
        id: Int;
        owner: Principal;
        balance: Nat;
        transactions: List.List<WalletTransaction>;
    };

    // Transaction (from wallet canister proxy)
    public type Transaction = {
        id: Nat;
        amount: Int;
        timestamp: Nat;
        description: Text;
    };

     // PaymentTransaction
    public type PaymentTransaction = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        amount: Nat;
        tokenId: ?Nat;
        timestamp: Int;
        status: Text; // "Pending", "Completed", "Failed", "Reversed"
        description: ?Text;
    };

    // Payment
    public type Payment = {
        id: Nat;
        sender: Principal;
        receiver: Principal;
        amount: Nat;
        tokenId: ?Nat;
        status: Text; // "Pending", "Completed", "Failed", "Reversed"
        timestamp: Nat;
    };

    //Subscription Type
     public type Subscription = {
        id: Nat;
        userId: Principal;
        startDate: Int;
        endDate: Int;
        status: Text; // e.g., "active", "expired"
    };

    // TokenStateType
    public type TokenState = {
        getNextTokenId: () -> Nat;
        addToken: (Token) -> Result.Result<(), Text>;
        getToken: (Nat) -> ?Token;
        updateToken: (Token) -> Result.Result<(), Text>;
        getAllTokens: () -> [Token];
        removeToken: (Nat) -> Result.Result<(), Text>;
        lockTokens: (Nat, Nat, Principal) -> Result.Result<(), Text>;
        getLockedTokens: (Nat) -> ?LockedToken;
        releaseLockedTokens: (Nat) -> Result.Result<(), Text>;
        logTokenLockEvent: (Nat, Nat, Principal) -> ();
        updateTokenMetadata: (Nat, Text, Text, Principal) -> async Result.Result<Token, Text>;
        deactivateToken: (Nat) -> Result.Result<(), Text>;
        reactivateToken: (Nat) -> Result.Result<(), Text>;
        listAllLockedTokens: () -> [LockedToken];
        mintToken: (Nat, Nat) -> Result.Result<(), Text>;
        burnToken: (Nat, Nat) -> Result.Result<(), Text>;
        attachTokensToUser: (Nat, Principal, Nat) -> Result.Result<(), Text>;
    };

     // TokenCanisterProxyType
    public type TokenCanisterProxyType = {
        getAllTokens: () -> async [Token];
        getToken: (Nat) -> async ?Token;
        updateToken: (Token) -> async Result.Result<(), Text>;
        mintTokens: (Principal, Nat) -> async Result.Result<(), Text>;
        attachTokensToUser: (Nat, Principal, Nat) -> async Result.Result<(), Text>;
    };

    // Interface types
    public type UserManagerInterface = {
        createUser: (Text, Text, Text) -> async Result.Result<User, Text>;
        updateUser: (Principal, ?Text, ?Text, ?Text) -> async Result.Result<User, Text>;
        deleteUser: (Principal) -> async Result.Result<(), Text>;
        getUserById: (Principal) -> async ?User;
        getAllUsers: () -> [User];
        attachTokensToUser: (Nat, Principal, Nat, TokenState) -> async Result.Result<(), Text>;
    };

     // UserCanisterInterface
    // Define the interface for the user canister
public type UserCanisterInterface = actor {
    getUserById: (userId: Principal) -> async Result.Result<User, Text>;
    createUser: (username: Text, email: Text, passwordHash: Text) -> async Result.Result<User, Text>;
    attachWalletToUser: (userId: Principal, walletId: Nat) -> async Result.Result<(), Text>;
    detachWalletFromUser: (userId: Principal) -> async Result.Result<(), Text>;
    deactivateUser: (userId: Principal) -> async Result.Result<(), Text>;
    listAllUsers: () -> async Result.Result<[User], Text>;
    attachTokensToUser: (tokenId: Nat, userId: Principal, amount: Nat, tokenCanisterPrincipal: Principal) -> async Result.Result<(), Text>;
    updateUser: (userId: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text) -> async Result.Result<User, Text>;
    resetPassword: (userId: Principal, newPassword: Text) -> async Result.Result<User, Text>;
    validateSession: (token: Text) -> async Result.Result<Session, Text>;
    getSession: (sessionToken: Text) -> async Result.Result<Session, Text>;
    deleteUser: (userId: Principal) -> async Result.Result<(), Text>;
};

    public type TokenManagerInterface = {
        createToken : (Text, Text, Nat, Nat, Principal) -> async Result.Result<Token, Text>;
        getToken : (Nat) -> Result.Result<Token, Text>;
        updateTokenMetadata : (Nat, Text, Text, Principal) -> async Result.Result<Token, Text>;
        reactivateToken : (Nat, Principal) -> async Result.Result<Token, Text>;
        deactivateToken : (Nat, Principal) -> async Result.Result<Token, Text>;
        getEventLog : () -> [Text];
        logInfo : (Text, Text, ?Principal) -> ();
        logError : (Text, Text, ?Principal) -> ();
        getAllTokens : () -> [Token];
        releaseLockedTokens : (Nat) -> async Result.Result<(), Text>;
        attachTokensToUser : (Nat, Principal, Nat) -> async Result.Result<(), Text>;
        burnToken : (Nat, Nat) -> Result.Result<(), Text>;
        isTokenOwner : (Nat, Principal) -> Bool;
        lockTokens : (Nat, Nat, Principal) -> async Result.Result<Nat, Text>;
        logErrorText : (Text, Text, ?Text) -> ();
        logInfoText : (Text, Text, ?Text) -> ();
        mintToken : (Nat, Nat, ?Principal) -> async Result.Result<(), Text>;
        onError : Text -> async ();
        unlockTokens : (Nat, Nat, Principal) -> async Result.Result<Nat, Text>;
    };

     // TokenCanisterInterface
    public type TokenCanisterInterface = actor {
        createToken: (Text, Text, Nat, Nat, Principal) -> async Result.Result<Token, Text>;
        getAllTokens: () -> async [Token];
        getToken: (Nat) -> async ?Token;
        updateToken: (Token) -> async Result.Result<(), Text>;
        mintTokens: (Principal, Nat) -> async Result.Result<(), Text>;
        attachTokensToUser: (Nat, Principal, Nat) -> async Result.Result<(), Text>;
        deactivateToken: (Nat, Principal) -> async Result.Result<(), Text>;
        reactivateToken: (Nat, Principal) -> async Result.Result<(), Text>;
    };

    // WalletCanisterInterface
    public type WalletCanisterInterface = actor {
        createWallet: (userId: Principal, initialBalance: Nat) -> async Result.Result<Wallet, Text>;
        getWalletByOwner: (ownerId: Principal) -> async Result.Result<Wallet, Text>;
        updateBalance: (ownerId: Principal, amount: Int) -> async Result.Result<Nat, Text>;
        getTransactionHistory: (ownerId: Principal) -> async Result.Result<[Transaction], Text>;
        deleteWallet: (ownerId: Principal) -> async Result.Result<(), Text>;
        creditWallet: (userId: Principal, amount: Nat, tokenId: Nat) -> async Result.Result<Nat, Text>;
        debitWallet: (userId: Principal, amount: Nat, tokenId: Nat) -> async Result.Result<Nat, Text>;
        getBalance: (userId: Principal, tokenId: Nat) -> async Result.Result<Nat, Text>;
        addBalance: (userId: Principal, tokenId: Nat, amount: Nat) -> async Result.Result<Nat, Text>;
        deductBalance: (userId: Principal, tokenId: Nat, amount: Nat) -> async Result.Result<Nat, Text>;
    };

    // PaymentCanisterInterface
    public type PaymentCanisterInterface = actor {
        initiatePayment: (sender: Principal, receiver: Principal, amount: Nat, tokenId: ?Nat) -> async Result.Result<Payment, Text>;
        completePayment: (paymentId: Nat) -> async Result.Result<(), Text>;
        getPaymentStatus: (paymentId: Nat) -> async Result.Result<Text, Text>;
        getPaymentHistory: (userId: Principal) -> async Result.Result<[Payment], Text>;
        getAllPayments: (user: Principal, filterByStatus: ?Text, fromDate: ?Nat, toDate: ?Nat) -> async Result.Result<[Payment], Text>;
        reversePayment: (paymentId: Nat) -> async Result.Result<(), Text>;
        timeoutPendingPayments: () -> async Result.Result<Nat, Text>;
    };

    public type SubscriptionManager = actor {
        createSubscription: (Principal, Int) -> async Result.Result<Nat, Text>;
        unsubscribeUser: (Nat) -> async Result.Result<(), Text>;
        getAllSubscriptions: () -> async [(Nat, Principal)];
        isSubscribed: (Principal) -> async Result.Result<Bool, Text>;
        validateSubscription: (Principal) -> async Result.Result<(), Text>;
        expireSubscriptions: () -> async Result.Result<Nat, Text>;
        getSubscriptionDetails: (Principal) -> async Result.Result<Subscription, Text>;
    };
}