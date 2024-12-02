import Principal "mo:base/Principal";
import Char "mo:base/Char";
import Text "mo:base/Text";
import Array "mo:base/Array";
import _Option "mo:base/Option";
import _Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import LoggingUtils "logging_utils";

module {
public func isValidSymbol(symbol: Text): Bool { if (symbol.size() == 0 or symbol.size() > 5) { return false; }; return isAlphanumericText(symbol); };

  // Define admins as an array for this example
  public let admins: [Principal] = []; // Populate this with actual admin principals

  // Validate a token name (tokens must have valid alphanumeric names)
  public func isValidTokenName(tokenName: Text): Bool {
    if (tokenName.size() == 0 or tokenName.size() > 20) {
        return false;
    };
    return isAlphanumericText(tokenName);
  };

  // Validate a token symbol (symbols must be alphanumeric and non-empty) public func isValidSymbol(symbol: Text): Bool { if (symbol.size() == 0 or symbol.size() > 5) { return false; }; return isAlphanumericText(symbol); };

  // Validate an asset name (asset names must be alphanumeric and non-empty)
  public func isValidText(text: Text): Bool {
    if (text.size() == 0 or text.size() > 100) {
        return false;
    };
    return isAlphanumericText(text);
  };

  // Validate a Principal (Admin verification)
  public func isAdmin(principal: Principal): Bool {
    return Array.indexOf<Principal>(principal, admins, func(a: Principal, b: Principal): Bool { a == b }) != null;
  };

  // Validate a valid XRPL address
  public func isValidXrplAddress(address: Text): Bool {
    // XRPL addresses typically start with 'r' and are 34-35 characters in length
    return address.chars().next() == ?'r' and (address.size() >= 25 and address.size() <= 35);
  };

  // Validate a non-empty, non-null field
  public func isNotEmpty(text: ?Text): Bool {
    switch (text) {
        case (null) { false };
        case (?txt) { txt.size() > 0 };
    };
  };

  // Helper function to check if a character is alphanumeric (letter or number)
  public func isAlphanumeric(c: Char): Bool {
    let lowerC = Text.toLowercase(Char.toText(c));
    return (lowerC >= "a" and lowerC <= "z") or (c >= '0' and c <= '9');
  };

  // Helper function to check if a text string is alphanumeric
  public func isAlphanumericText(text: Text): Bool {
    for (char in text.chars()) {
        if (not isAlphanumeric(char)) {
            return false;
        };
    };
    return true;
  };

  // Validate fractional ownership (should be between 0 and 100)
  public func isValidFraction(fraction: Nat): Bool {
    return fraction > 0 and fraction <= 100;
  };

  // Validate positive integer
  public func isPositiveNat(value: Nat): Bool {
    return value > 0;
  };

  // Validate total supply (should be greater than zero)
  public func isValidTotalSupply(supply: Nat): Bool {
    return supply > 0;
  };

  // Check if the caller is a valid owner of the asset
  public func isValidOwner(caller: Principal, owner: Principal): Bool {
    return caller == owner;
  };

  // Validate amount for transactions (positive values)
  public func isValidTransactionAmount(amount: Nat): Bool {
    return amount > 0;
  };

  // Validate an asset name (asset names must be alphanumeric and non-empty)
  public func isValidAssetName(name: Text): Bool {
    if (name.size() == 0 or name.size() > 100) {
      return false;
    };
    return isAlphanumericText(name);
  };

  // Validate an asset description (asset descriptions must be non-empty)
  public func isValidAssetDescription(description: Text): Bool {
    if (description.size() == 0 or description.size() > 500) {
      return false;
    };
    return isAlphanumericText(description);
  };

  // Validate a Principal for asset transfers (non-null)
    public func isValidPrincipal(principal: Principal): Bool {
        // Check that the principal is not `Principal.null`
        return Principal.toText(principal).size() > 0;
 
   };

public func isValidOwnershipDistribution(distribution: [(Principal, Nat)]): Bool {
  // Check if the distribution is not empty
  if (distribution.size() == 0) {
    return false;
  };

  // Check if all principals are valid and all share amounts are positive
  for ((principal, shares) in distribution.vals()) {
    if (not isValidPrincipal(principal) or shares == 0) {
      return false;
    };
  };

  // Check if the total shares do not exceed 100%
  let totalShares = Array.foldLeft<(Principal, Nat), Nat>(
    distribution, 
    0, 
    func(acc, curr) { acc + curr.1 }
  );
  if (totalShares > 100) {
    return false;
  };

// Check if there are no duplicate principals
let uniquePrincipals = Buffer.Buffer<Principal>(distribution.size());
for ((p, _) in distribution.vals()) {
  if (not Buffer.contains(uniquePrincipals, p, Principal.equal)) {
    uniquePrincipals.add(p);
  };
};
if (uniquePrincipals.size() != distribution.size()) {
  return false;
};

true
};

public func isValidEmail(email: Text): Bool {
    let emailParts = Text.split(email, #char '@');
    
    let localPart = Iter.toArray(emailParts);
    if (localPart.size() != 2) {
        return false;
    };

    let local = localPart[0];
    let domain = localPart[1];

    if (local.size() == 0 or domain.size() == 0) {
        return false;
    };

    let domainParts = Text.split(domain, #char '.');
    let domainArray = Iter.toArray(domainParts);
    
    if (domainArray.size() < 2) {
        return false;
    };

    // Check if all parts are alphanumeric (you can add more specific rules if needed)
    for (part in domainArray.vals()) {
        if (not isAlphanumericText(part)) {
            return false;
        };
    };

    return true;
};

// Validate a token symbol (symbols must be alphanumeric and between 1 to 5 characters)
public func isValidTokenSymbol(symbol: Text): Bool {
    if (symbol.size() == 0 or symbol.size() > 5) {
        return false;
    };
    return isAlphanumericText(symbol);
};

// Handle internal error (logging the error or performing necessary actions)
public func handleInternalError(errorMsg: Text): () {
    // Log the error message (assuming you have a logging mechanism)
    LoggingUtils.logError({ var entries = [] }, "ValidationUtils", errorMsg, null);
    // You can also add other error handling mechanisms if needed
};

// Validate decimals (should be between 0 and 18)
public func isValidDecimals(decimals: Nat): Bool {
    return decimals >= 0 and decimals <= 18;
}


}



/*Key Functions:

	•	Admin Validation (isAdmin): Ensures that the caller is one of the predefined system administrators. This is essential for controlling access to sensitive internal methods.
	•	Token and Asset Name Validation:
	•	isValidTokenName: Ensures that the token name is alphanumeric, between 1 and 20 characters long.
	•	isValidText: General validation for text fields like asset names, which must be alphanumeric and within a reasonable length.
	•	XRPL Address Validation (isValidXrplAddress): Ensures that a given XRPL address conforms to the expected format, typically starting with an ‘r’ and falling within a specific length.
	•	Ownership and Permission Validation (isValidOwner): Verifies that the caller is the actual owner of an asset.
	•	Fraction Validation (isValidFraction): Ensures that fractional ownership transfers involve a valid fraction (between 1 and 100).
	•	Positive Number Validation:
	•	isPositiveNat: Checks if a number is greater than zero.
	•	isValidTransactionAmount: Ensures that transaction amounts are positive.
	•	isValidTotalSupply: Ensures that the total supply for a token is greater than zero.

Security & Best Practices:

	•	Admin Controls: Admin validation prevents unauthorized access to sensitive system functions, ensuring that only authorized principals can access certain features.
	•	Data Integrity: The utility ensures that token names, asset names, addresses, and amounts are properly validated before any transaction or action is executed, minimizing the risk of errors or malicious data being submitted to the system.
	•	Standardized Validation: By centralizing validation in this utility, the system can ensure consistency across all parts of the canister when handling input validation.

Use Cases:

	•	Public API Methods: This utility is used throughout public API methods to ensure that inputs (such as token names, amounts, and addresses) meet the expected standards before processing the request.
	•	Private/Internal Operations: For internal operations, such as asset updates or ownership transfers, this utility ensures that admins and valid users are the only ones allowed to execute the operations.

This utility ensures that the system maintains a high level of data integrity and security by validating all critical fields before processing any operations.*/