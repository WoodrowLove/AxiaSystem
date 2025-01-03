import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import _Hash "mo:base/Hash";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Trie "mo:base/Trie";
import Option "mo:base/Option";
import ValidationUtils "../../utils/validation_utils";
import UUID "mo:uuid/UUID";
import TokenState "../../token/state/token_state";
import LoggingUtils "..../../../../utils/logging_utils";

module {
    public type User = {
        id: Principal;
        username: Text;
        email: Text;
        hashedPassword: Text;
        createdAt: Int;
        updatedAt: Int;
        icpWallet: ?Text; // Placeholder for ICP wallet address
        //xrplWallet: ?Text; // Placeholder for XRPL wallet address
        tokens: Trie.Trie<Nat, Nat>;
    };

    public type UserManagerInterface = {
        createUser: (Text, Text, Text) -> async Result.Result<User, Text>;
        updateUser: (Principal, ?Text, ?Text, ?Text) -> async Result.Result<User, Text>;
        deleteUser: (Principal) -> async Result.Result<(), Text>;
        getUserById: (Principal) -> async ?User;
        getAllUsers: () -> [User];
        attachTokensToUser: (Nat, Principal, Nat, TokenState.TokenState) -> async Result.Result<(), Text>;
    };

    public class UserManager() : UserManagerInterface {
        private var users: [User] = [];
        private let logStore = LoggingUtils.init();
        private var _eventLog: [Text] = [];
    

        // Create a new user
    public func createUser(username: Text, email: Text, password: Text): async Result.Result<User, Text> {
    if (not ValidationUtils.isValidEmail(email)) {
        return #err("Invalid email format");
    };

    switch (findUserByEmail(email)) {
        case (null) {};
        case (?_) { return #err("User with this email already exists") };
    };

    let hashedPassword = hashPassword(password);

    // Generate a UUID
    let uuidBytes = Blob.toArray(Blob.fromArray(Array.tabulate<Nat8>(16, func(_) = Nat8.fromNat(Int.abs(Time.now() % 256)))));
    let uuid : UUID.UUID = uuidBytes;
    let uuidText = UUID.toText(uuid);

    // Call the wallet canister to create a wallet
let walletCanister = actor(Principal.toText(Principal.fromText("ahw5u-keaaa-aaaaa-qaaha-cai"))) : actor {
    createWallet: (Principal) -> async Result.Result<Text, Text>
};
    
    let walletResult = await walletCanister.createWallet(Principal.fromText(uuidText));

    switch (walletResult) {
        case (#err(e)) {
            LoggingUtils.logError(
                logStore,
                "UserModule",
                "Failed to create wallet for user: " # e,
                null
            );
            return #err("Failed to create wallet for user");
        };
        case (#ok(walletAddress)) {
            let user: User = {
                id = Principal.fromText(uuidText);
                username = username;
                email = email;
                hashedPassword = hashedPassword;
                createdAt = Time.now();
                updatedAt = Time.now();
                icpWallet = ?walletAddress; // Assign wallet address
                // xrplWallet = null; // Placeholder for XRPL integration
                tokens = Trie.empty();
            };

            users := Array.append<User>(users, [user]);

            LoggingUtils.logInfo(
                logStore,
                "UserModule",
                "User created successfully: " # username,
                null
            );

            return #ok(user);
        };
    };
};

        public func updateUser(id: Principal, newUsername: ?Text, newEmail: ?Text, newPassword: ?Text): async Result.Result<User, Text> {
    var found = false;
    var updatedUser: ?User = null;

    users := Array.map<User, User>(users, func(user: User): User {
        if (user.id == id) {
            found := true;
            let updated: User = {
                id = user.id;
                username = switch newUsername { case null { user.username }; case (?u) { u } };
                email = switch newEmail { case null { user.email }; case (?e) { e } };
                hashedPassword = switch newPassword { case null { user.hashedPassword }; case (?p) { hashPassword(p) } };
                createdAt = user.createdAt;
                updatedAt = Time.now();  // Changed this line
                icpWallet = user.icpWallet;
                //xrplWallet = user.xrplWallet;
                tokens = user.tokens;
            };
        updatedUser := ?updated;
        updated
    } else {
        user
    }
});

           if (not found) {
    return #err("User not found");
};

return #ok(switch (updatedUser) { 
    case null { Debug.trap("Inconsistent state") };
    case (?u) { u };
});
        };

       public func deleteUser(id: Principal): async Result.Result<(), Text> {
    let initialSize = users.size();
    users := Array.filter<User>(users, func(user: User): Bool { user.id != id });
    if (initialSize == users.size()) {
        return #err("User not found");
    };
    return #ok(());
};

        public func getUserById(id: Principal): async ?User {
   return Array.find<User>(users, func(user: User): Bool { user.id == id })
};

        // Get all users
        public func getAllUsers(): [User] {
            users;
        };

        // Utility: Find a user by email
        private func findUserByEmail(email: Text): ?User {
            Array.find<User>(users, func(user: User): Bool { user.email == email })
        };

        // Utility: Hash password
        private func hashPassword(password: Text): Text {
            return "hashed_" # password;
        };

// Generate placeholder ICP wallet
private func _generateIcpWallet(): ?Text {
    // This can be replaced with actual ICP wallet generation logic
    let uniqueId = Int.toText(Time.now());
    ?("icp_wallet_" # uniqueId)
};

/* Generate placeholder XRPL wallet
private func generateXrplWallet(): ?Text {
    // This can be replaced with actual XRPL wallet generation logic
    let uniqueId = Int.toText(Time.now());
    ?("xrpl_wallet_" # uniqueId)
}; */

public func resetPassword(userId: Principal, newPassword: Text): async Result.Result<User, Text> {
    var updatedUser: ?User = null;

    users := Array.map<User, User>(users, func(user: User): User {
        if (user.id == userId) {
            let updated: User = {
                id = user.id;
                username = user.username;
                email = user.email;
                hashedPassword = hashPassword(newPassword);
                createdAt = user.createdAt;
                updatedAt = Time.now();
                icpWallet = user.icpWallet;
               // xrplWallet = user.xrplWallet;
                tokens = user.tokens;
            };
            updatedUser := ?updated;
            updated
        } else {
            user
        }
    });

    if (updatedUser == null) {
        return #err("User not found");
    };

    return #ok(switch updatedUser {
        case (?u) { u };
        case null { Debug.trap("Inconsistent state") };
    });
};

private func _generateSessionToken(): Text {
    let now = Int.abs(Time.now()); // Convert Time to Nat
    let randomSeed = Nat32.fromNat(now % 0x100000000); // Generate a pseudo-random seed
    let randomValue = customHash(now); // Use custom hash function

   let bytes = Array.append<Nat8>(
        Array.tabulate<Nat8>(4, func(i: Nat) = Nat8.fromNat(Nat32.toNat((randomSeed >> Nat32.fromNat(24 - 8 * i)) & 0xFF))),
        Array.tabulate<Nat8>(4, func(i: Nat) = Nat8.fromNat(Nat32.toNat((randomValue >> Nat32.fromNat(24 - 8 * i)) & 0xFF)))
    );

    let _token = Text.fromIter(
    Iter.map(
        bytes.vals(),
        func (byte: Nat8): Char {
            Char.fromNat32(Nat32.fromNat(Nat8.toNat(byte)))
        }
    )
);
};

// Custom hash function for Nat
private func customHash(n: Nat): Nat32 {
    var hash: Nat32 = 5381;
    var i = 0;
    var remaining = n;
    while (i < 8) {
        hash := ((hash << 5) +% hash) +% Nat32.fromNat(remaining % 256);
        remaining /= 256;
        i += 1;
    };
    hash
};

public func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat, tokenState: TokenState.TokenState): async Result.Result<(), Text> {
    let userOpt = await getUserById(userId);
    switch (userOpt) {
        case null #err("User not found");
        case (?user) {
            // Update user's token balance
            let currentAmount = Trie.get(user.tokens, { key = tokenId; hash = customHash(tokenId) }, Nat.equal);
            let newAmount = Option.get(currentAmount, 0) + amount;
            let updatedTokens = Trie.put(
                user.tokens,
                { key = tokenId; hash = customHash(tokenId) },
                Nat.equal,
                newAmount
            ).0;

            // Create updated user object
            let updatedUser = { user with tokens = updatedTokens; updatedAt = Time.now() };

            // Update user state
            let userUpdateResult = await updateUser(user.id, ?updatedUser.username, ?updatedUser.email, ?updatedUser.hashedPassword);
            switch (userUpdateResult) {
                case (#err(e)) #err("Failed to update user: " # e);
                case (#ok(_)) {
                    // Update token state
                    let tokenOpt = tokenState.getToken(tokenId);
                    switch (tokenOpt) {
                        case null #err("Token not found: ID " # Nat.toText(tokenId));
                        case (?token) {
                            let updatedToken = { token with totalSupply = token.totalSupply + amount };
                            let tokenUpdateResult = tokenState.updateToken(updatedToken);
                            switch (tokenUpdateResult) {
                                case (#err(e)) #err("User updated, but failed to update token: " # e);
                                case (#ok(_)) #ok(());
                            };
                        };
                    };
                };
            };
        };
    };
};
    }
};