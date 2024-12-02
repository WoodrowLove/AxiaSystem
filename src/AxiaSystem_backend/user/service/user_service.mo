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
import UserModule "../modules/user_module";
import UserState "../state/user_state";
import ValidationUtils "../../utils/validation_utils";
import TokenCanisterProxy "../../token/utils/token_canister_proxy"; // Import the token proxy file

module {
  public class UserService(userManager: UserModule.UserManager, userState: UserState.UserState) {
    private let tokenProxy = TokenCanisterProxy.TokenCanisterProxy(token_canister_principal); // Initialize the token canister proxy

    // User Registration
    public func registerUser(username: Text, email: Text, password: Text): async Result.Result<UserModule.User, Text> {
      if (not ValidationUtils.isValidEmail(email)) {
        return #err("Invalid email format");
      };

      if (userState.getUserByEmail(email) != #err("User not found.")) {
        return #err("User with this email already exists");
      };

      let hashedPassword = hashPassword(password);
      let currentTime = Time.now();
      let userId = Principal.fromText(Text.concat(email, Nat64.toText(Nat64.fromIntWrap(currentTime))));
      let newUser: UserModule.User = {
        id = userId;
        username = username;
        email = email;
        hashedPassword = hashedPassword;
        createdAt = Nat64.toNat(Nat64.fromIntWrap(currentTime));
        updatedAt = Nat64.toNat(Nat64.fromIntWrap(currentTime));
        icpWallet = generateIcpWallet();
        xrplWallet = generateXrplWallet();
        tokens = Trie.empty<Nat, Nat>(); // Initialize an empty tokens Trie
      };

      switch (userState.createUser(newUser.id, username, email, hashedPassword)) {
        case (#ok(_)) #ok(newUser);
        case (#err(error)) #err(error);
      }
    };

    // User Login
    public func loginUser(email: Text, password: Text): async Result.Result<Text, Text> {
      switch (userState.getUserByEmail(email)) {
        case (#ok(user)) {
          if (verifyPassword(password, user.passwordHash)) {
            let sessionToken = generateSessionToken(user.id);
            #ok(sessionToken)
          } else {
            #err("Invalid credentials")
          }
        };
        case (#err(error)) #err(error);
      }
    };

    // Attach Tokens to User
    public async func attachTokensToUser(userId: Principal, tokenId: Nat, amount: Nat): Result.Result<(), Text> {
      let userOpt = await userState.getUserById(userId);
      switch (userOpt) {
        case null { return #err("User not found."); };
        case (?user) {
          let tokenOpt = await tokenProxy.getToken(tokenId);
          switch (tokenOpt) {
            case null { return #err("Token not found."); };
            case (?token) {
              let updatedTokens = Trie.put(user.tokens, { key = tokenId; hash = Text.hash(Nat.toText(tokenId)) }, Nat.equal, amount).0;
              let updatedUser = { user with tokens = updatedTokens };
              let updateResult = userState.updateUser(userId, ?updatedUser.username, ?updatedUser.email);

              switch (updateResult) {
                case (#ok(_)) #ok(());
                case (#err(e)) #err("Failed to update user: " # e);
              }
            };
          }
        };
      }
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