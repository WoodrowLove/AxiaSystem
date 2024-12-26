import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Result "mo:base/Result";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Iter "mo:base/Iter";
import Trie "mo:base/Trie";
import _Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Char "mo:base/Char";
import UserModule "../modules/user_module";
import UserState "../state/user_state";
import ValidationUtils "../../utils/validation_utils";
import TokenCanisterProxy "../../token/utils/token_canister_proxy";
import _SharedTypes "../../shared_types";

module {
  public class UserService(_userManager: UserModule.UserManager, userState: UserState.UserState) {
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(Principal.fromText("be2us-64aaa-aaaaa-qaabq-cai")); // Initialize the token canister proxy

    private func natHash(n: Nat): Nat32 {
    let text = Nat.toText(n);
    var hash: Nat32 = 5381;
    for (char in text.chars()) {
        let c: Nat32 = Char.toNat32(char) & 0xFF;
        hash := ((hash << 5) +% hash) +% c;
    };
    return hash;
};

    // User Registration
    public func registerUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
  if (not ValidationUtils.isValidEmail(email)) {
    return #err("Invalid email format");
  };

  switch ( userState.getUserByEmail(email)) {
    case (#ok(_)) return #err("User with this email already exists");
    case (#err(_)) { /* Continue with registration */ };
  };

  let hashedPassword = hashPassword(password);
  let currentTime = Time.now();
  let userId = Principal.fromText(Text.concat(email, Nat64.toText(Nat64.fromIntWrap(currentTime))));

  // Define the createWallet function
  let createWallet = func (_userId: Principal) : async Result.Result<Text, Text> {
    // Implement wallet creation logic here
    // For now, we'll just return a dummy success result
    #ok("Wallet created successfully")
  };

  let createUserResult = await userState.createUser(
    userId,
    username,
    email,
    hashedPassword,
    createWallet
  );

  switch (createUserResult) {
    case (#ok(user)) {
      // Construct the UserModule.User from the created user
      let newUser: UserModule.User = {
        id = user.id;
        username = user.username;
        email = user.email;
        hashedPassword = user.hashedPassword;
        createdAt = Nat64.toNat(Nat64.fromIntWrap(user.createdAt));
        updatedAt = Nat64.toNat(Nat64.fromIntWrap(user.updatedAt));
        icpWallet = generateIcpWallet(); // You might want to get this from the created wallet
        xrplWallet = ?generateXrplWallet(); // You might want to get this from the created wallet
        tokens = Trie.empty<Nat, Nat>(); // Initialize an empty tokens Trie
      };
      #ok(newUser)
    };
    case (#err(error)) #err(error);
  }
};

    // User Login
    public func loginUser(email: Text, password: Text): async Result.Result<Text, Text> {
      switch (userState.getUserByEmail(email)) {
        case (#ok(user)) {
          if (verifyPassword(password, user.hashedPassword)) {
            let sessionToken = generateSessionToken(user.id);
            #ok(sessionToken)
          } else {
            #err("Invalid credentials")
          }
        };
        case (#err(error)) #err(error);
      }
    };

    public func attachTokensToUser(tokenId: Nat, userId: Principal, amount: Nat): async Result.Result<(), Text> {
    switch (await userState.getUserById(userId)) {
        case (#err(e)) #err("User not found: " # e);
        case (#ok(user)) {
            // User.tokens is already a Trie, no need for a switch
            let userTokens = user.tokens;
            
            // Update user's token balance
let currentAmount = Trie.get(userTokens, { key = tokenId; hash = natHash(tokenId) }, Nat.equal);
let newAmount = Option.get(currentAmount, 0) + amount;
let updatedTokens = Trie.put(
    userTokens,
    { key = tokenId; hash = natHash(tokenId) },
    Nat.equal,
    newAmount
).0;

            // Create updated user object
            let _updatedUser = {
                user with
                tokens = updatedTokens; 
                updatedAt = Time.now();
            };

            // Update user state
            switch (await tokenProxy.getToken(tokenId)) {
                        case null #err("Token not found: ID " # Nat.toText(tokenId));
                        case (?token) {
                            let updatedToken = { token with totalSupply = token.totalSupply + amount };
                            let tokenUpdateResult = await tokenProxy.updateToken(updatedToken);
                            switch (tokenUpdateResult) {
                                case (#err(e)) #err("User updated, but failed to update token: " # e);
                                case (#ok(_)) #ok(());
                            };
                        };
                    };
                };
            };
        };
  

    // Generate ICP wallet placeholder
    private func generateIcpWallet(): ?Text {
      let uniqueId = Int.toText(Time.now());
      ?("icp_wallet_" # uniqueId)
    };

    // Generate XRPL wallet placeholder
    private func generateXrplWallet(): ?Text {
      let uniqueId = Int.toText(Time.now());
      ?("xrpl_wallet_" # uniqueId)
    };

    // Generate session token
    private func generateSessionToken(userId: Principal): Text {
      let timeStamp = Int.toText(Time.now());
      let data = Principal.toText(userId) # timeStamp;
      let hashBlob = Text.encodeUtf8(data);
      let hash = Blob.hash(hashBlob);
      let hashArray = Array.tabulate<Nat8>(32, func(i) = Nat8.fromNat(Nat32.toNat(hash)));
      let hexHash = blobToHex(Blob.fromArray(hashArray));
      "session_" # hexHash;
    };

    private func blobToHex(blob: Blob): Text {
      let hex = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"];
      let array = Blob.toArray(blob);
      let hexChars = Array.foldLeft<Nat8, [Text]>(array, [], func (acc, byte) {
        let highNibble = Nat8.toNat(byte / 16);
        let lowNibble = Nat8.toNat(byte % 16);
        Array.append(acc, [hex[highNibble], hex[lowNibble]])
      });
      Text.join("", Iter.fromArray(hexChars))
    };

    // Utility: Hash password
    private func hashPassword(password: Text): Text {
      let passwordBlob = Text.encodeUtf8(password);
      let hash = Blob.hash(passwordBlob); // Use Blob.hash instead of Hash.hash
      let hashBlob = Blob.fromArray(Array.tabulate<Nat8>(32, func(i) = Nat8.fromNat(Nat32.toNat(hash))));
      let hexHash = blobToHex(hashBlob);
      "hashed_" # hexHash;
    };

    // Utility: Verify password
    private func verifyPassword(password: Text, hashedPassword: Text): Bool {
      let hash = hashPassword(password);
      hash == hashedPassword;
    };
  };
};