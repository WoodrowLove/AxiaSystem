import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";

module {
    // Define the user structure
    public type User = {
        id : Principal;
        username : Text;
        email : Text;
        passwordHash : Text;
        createdAt : Time.Time;
        updatedAt : Time.Time;
        isActive : Bool;
        isVerified : Bool;
    };

    public type Session = {
        userId: Principal;
        token: Text;
        expiresAt: Int;
    };

     // Define the Token type to match the one in the token canister
    public type Token = {
        id: Nat;
        name: Text;
        symbol: Text;
        totalSupply: Nat;
        decimals: Nat;
        owner: Principal;
        isActive: Bool;
    };


    public class UserState() {
        private var users: [User] = [];
        private var sessions: [Session] = [];
        // Create an instance of TokenCanisterProxy
        private var _tokenProxy: ? TokenCanisterProxy.TokenCanisterProxy = null;

        // Create a new user
        public func createUser(
    userId: Principal,
    username: Text,
    email: Text,
    passwordHash: Text,
    createWallet: (Principal) -> async Result.Result<Text, Text> // Wallet creation API
): async Result.Result<User, Text> {
    switch (Array.find<User>(users, func(user: User): Bool {
        user.id == userId or user.email == email
    })) {
        case (null) {
            let walletResult = await createWallet(userId);
            switch (walletResult) {
                case (#err(walletError)) {
                    return #err("Failed to create wallet: " # walletError);
                };
                case (#ok(_walletAddress)) {
                    let newUser: User = {
                        id = userId;
                        username = username;
                        email = email;
                        passwordHash = passwordHash;
                        createdAt = Time.now();
                        updatedAt = Time.now();
                        isActive = true;
                        isVerified = false;
                    };
                    users := Array.append(users, [newUser]);
                    return #ok(newUser);
                };
            };
        };
        case (?_) {
            return #err("User already exists with the same ID or email.");
        };
    };
};


        // Retrieve a user by ID
        public func getUserById(userId: Principal): Result.Result<User, Text> {
            switch (Array.find<User>(users, func(user: User): Bool {
                user.id == userId
            })) {
                case (?user) #ok(user);
                case null #err("User not found.");
            }
        };

        // Retrieve a user by email
        public func getUserByEmail(email: Text): Result.Result<User, Text> {
            switch (Array.find<User>(users, func(user: User): Bool {
                user.email == email
            })) {
                case (?user) #ok(user);
                case null #err("User not found.");
            }
        };

        public func updateUser(userId: Principal, username: ?Text, email: ?Text): Result.Result<User, Text> {
            var userFound = false;

            users := Array.map<User, User>(users, func(user: User): User {
                if (user.id == userId) {
                    userFound := true;
                    {
                        user with
                        username = switch (username) {
                            case (?newUsername) newUsername;
                            case null user.username;
                        };
                        email = switch (email) {
                            case (?newEmail) newEmail;
                            case null user.email;
                        };
                        updatedAt = Time.now()
                    }
                } else {
                    user
                }
            });

            if (userFound) {
                let userResult = getUserById(userId);
                switch (userResult) {
                    case (#ok(user)) #ok(user);
                    case (#err(error)) #err("User not found after update: " # error);
                }
            } else {
                #err("User not found.")
            }
        };

        // Deactivate a user
        public func deactivateUser(userId: Principal): Result.Result<(), Text> {
            var userFound = false;

            users := Array.map<User, User>(users, func(user: User): User {
                if (user.id == userId) {
                    userFound := true;
                    { user with isActive = false; updatedAt = Time.now() }
                } else {
                    user
                }
            });

            if (userFound) {
                #ok(())
            } else {
                #err("User not found.")
            }
        };

        // Verify a user (e.g., after KYC)
        public func verifyUser(userId: Principal): Result.Result<(), Text> {
            var userFound = false;

            users := Array.map<User, User>(users, func(user: User): User {
                if (user.id == userId) {
                    userFound := true;
                    { user with isVerified = true; updatedAt = Time.now() }
                } else {
                    user
                }
            });

            if (userFound) {
                #ok(())
            } else {
                #err("User not found.")
            }
        };

        // Delete a user
        public func deleteUser(userId: Principal): Result.Result<(), Text> {
            let initialSize = Array.size(users);
            users := Array.filter<User>(users, func(user: User): Bool {
                user.id != userId
            });

            if (Array.size(users) < initialSize) {
                #ok(())
            } else {
                #err("User not found.")
            }
        };

        // List all users (for admin purposes)
        public func listAllUsers(): [User] {
            users
        };

        // Create a session
        public func createSession(userId: Principal): Result.Result<Text, Text> {
    let token = generateSessionToken();
    let expiresAt = Time.now() + 3600_000_000_000; // 1 hour expiration in nanoseconds
    sessions := Array.filter<Session>(sessions, func(session: Session): Bool { session.userId != userId }); // Remove old sessions
    let session: Session = {
        userId = userId;
        token = token;
        expiresAt = expiresAt;
    };
    sessions := Array.append(sessions, [session]);
    return #ok(token);
};

        private func generateSessionToken() : Text {
    let now = Int.abs(Time.now()); // Convert Time to Nat
    let randomSeed = Nat.toText(now) # "salt";
    let hashBlob = Text.encodeUtf8(randomSeed);
    let hashNat = Blob.hash(hashBlob); // Use Blob.hash instead of Hash.hash
    Nat32.toText(hashNat) // Blob.hash returns Nat32
};

        // Get a session by token
        public func getSession(sessionToken: Text): Result.Result<Session, Text> {
            switch (Array.find<Session>(sessions, func(session: Session): Bool {
                session.token == sessionToken
            })) {
                case (?session) #ok(session);
                case null #err("Session not found.");
            }
        };

        // Delete a session by token
        public func deleteSession(sessionToken: Text): Result.Result<(), Text> {
            let initialSize = Array.size(sessions);
            sessions := Array.filter<Session>(sessions, func(session: Session): Bool {
                session.token != sessionToken
            });

            if (Array.size(sessions) < initialSize) {
                #ok(())
            } else {
                #err("Session not found.")
            }
        };

       public func validateSession(token: Text): Result.Result<Session, Text> {
    switch (Array.find<Session>(sessions, func(session: Session): Bool {
        session.token == token and session.expiresAt > Time.now()
    })) {
        case (?session) #ok(session);
        case null #err("Invalid or expired session.");
    };
};
        
         public func filterUsersByStatus(isActive: Bool): [User] {
            Array.filter<User>(users, func(user: User): Bool {
                user.isActive == isActive
            })
        };

      public func getTokenStatistics(
    getAllTokens: () -> async [Token]
): async { totalTokens: Nat; activeTokens: Nat } {
    let allTokens = await getAllTokens();
    {
        totalTokens = Array.size(allTokens);
        activeTokens = Array.size(Array.filter<Token>(allTokens, func(token: Token): Bool {
            token.isActive
        }));
    };
};

public func attachTokensToUser(
    userId: Principal,
    tokenId: Nat,
    amount: Nat,
    updateTokenSupply: (Nat, Nat) -> async Result.Result<(), Text> // Token module API
): async Result.Result<(), Text> {
    switch (Array.find<User>(users, func(user: User): Bool { user.id == userId })) {
        case (null) {
            return #err("User not found.");
        };
        case (?user) {
            // Update token supply
            let updateResult = await updateTokenSupply(tokenId, amount);
            switch (updateResult) {
                case (#err(error)) {
                    return #err("Failed to update token supply: " # error);
                };
                case (#ok(_)) {
                    // Attach token to user
                    let updatedUser: User = {
                        user with
                        updatedAt = Time.now()
                    };
                    users := Array.map<User, User>(users, func(existingUser: User): User {
                        if (existingUser.id == userId) updatedUser else existingUser
                    });
                    return #ok(());
                };
            };
        };
    };
};


    };
}