//! Data Contract Validator - PII Protection for Notification System

import Text "mo:base/Text";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Int "mo:base/Int";

import NotificationTypes "./types";

module NotificationValidator {
    type Message = NotificationTypes.Message;
    type MsgBody = NotificationTypes.MsgBody;
    type NotificationError = NotificationTypes.NotificationError;
    type NotificationResult<T> = NotificationTypes.NotificationResult<T>;

    // Q1 Policy Enforcement: Forbidden PII patterns
    private let FORBIDDEN_KEYS: [Text] = [
        "email", "phone", "name", "firstName", "lastName", 
        "address", "street", "city", "zipcode", "postal",
        "ssn", "taxId", "creditCard", "bankAccount", "routing",
        "birthDate", "age", "gender", "nationality"
    ];

    private let FORBIDDEN_VALUE_PATTERNS: [Text] = [
        "@",        // Email indicator
        "gmail",    // Email domains
        "yahoo", 
        "outlook",
        "hotmail"
    ];

    // Maximum allowed variable value lengths (to prevent embedding PII in long strings)
    private let MAX_VARIABLE_LENGTH: Nat = 50;

    // Allowed reference patterns (these are safe)
    private let ALLOWED_PATTERNS: [Text] = [
        "P-",       // Payment reference
        "T-",       // Transaction reference  
        "U-",       // User reference
        "W-",       // Wallet reference
        "tier",     // Amount tier
        "level",    // Risk level
        "factor",   // Risk factor
        "hash",     // Hash values
        "id"        // Generic IDs
    ];

    // Main validation function
    public func validateMessage(message: Message) : NotificationResult<()> {
        // 1. Validate message body
        switch (validateMessageBody(message.body)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        // 2. Validate variables in body
        switch (validateVariables(message.body.variables)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        // 3. Validate action commands don't contain PII
        switch (validateActions(message.actions)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        #ok(())
    };

    // Validate message body content
    private func validateMessageBody(body: MsgBody) : NotificationResult<()> {
        // Check title for PII
        if (containsPII(body.title)) {
            return #err(#PIIViolation("PII detected in message title"));
        };

        // Check body text for PII
        if (containsPII(body.body)) {
            return #err(#PIIViolation("PII detected in message body"));
        };

        // Validate template ID is safe
        switch (body.templateId) {
            case (?templateId) {
                if (containsPII(templateId)) {
                    return #err(#PIIViolation("PII detected in template ID"));
                };
            };
            case null {};
        };

        #ok(())
    };

    // Validate variable substitutions
    private func validateVariables(variables: [(Text, Text)]) : NotificationResult<()> {
        // Use Array.find for more efficient validation checks
        let violatingKey = Array.find<(Text, Text)>(variables, func((key, value)) {
            isForbiddenKey(key) or 
            containsPII(value) or 
            Text.size(value) > MAX_VARIABLE_LENGTH or
            not isAllowedReference(value)
        });

        switch (violatingKey) {
            case (?((key, value))) {
                if (isForbiddenKey(key)) {
                    return #err(#PIIViolation("Forbidden variable key: " # key));
                } else if (containsPII(value)) {
                    return #err(#PIIViolation("PII detected in variable value: " # key));
                } else if (Text.size(value) > MAX_VARIABLE_LENGTH) {
                    return #err(#PIIViolation("Variable value too long (possible PII): " # key));
                } else {
                    return #err(#PIIViolation("Variable value doesn't match allowed patterns: " # key # "=" # value));
                }
            };
            case null {
                #ok(())
            };
        }
    };

    // Validate action command arguments
    private func validateActions(actions: [NotificationTypes.Action]) : NotificationResult<()> {
        // Use Array.find to efficiently locate any violating action
        let violatingAction = Array.find<NotificationTypes.Action>(actions, func(action) {
            containsPII(action.labelText) or 
            containsPII(action.command.scope) or 
            containsPII(action.command.name)
        });

        switch (violatingAction) {
            case (?action) {
                if (containsPII(action.labelText)) {
                    return #err(#PIIViolation("PII detected in action label"));
                } else {
                    return #err(#PIIViolation("PII detected in action command"));
                }
            };
            case null {
                #ok(())
            };
        }
    };

    // Helper function to convert to lowercase (simplified)
    private func toLowerText(text: Text): Text {
        // Simple lowercase conversion for ASCII characters
        Text.map(text, func (c: Char): Char {
            let code = Char.toNat32(c);
            if (code >= 65 and code <= 90) { // A-Z
                Char.fromNat32(code + 32) // Convert to a-z
            } else {
                c
            }
        })
    };

    // Check if a key name is forbidden
    private func isForbiddenKey(key: Text) : Bool {
        let lowerKey = toLowerText(key);
        
        // Use Array.find for more efficient pattern matching
        switch (Array.find<Text>(FORBIDDEN_KEYS, func(forbidden) {
            Text.contains(lowerKey, #text forbidden)
        })) {
            case (?_found) true;
            case null false;
        }
    };

    // Check if text contains PII patterns
    private func containsPII(text: Text) : Bool {
        let lowerText = toLowerText(text);
        
        // Use Array.find for efficient pattern detection
        let foundPattern = Array.find<Text>(FORBIDDEN_VALUE_PATTERNS, func(pattern) {
            Text.contains(lowerText, #text pattern)
        });

        switch (foundPattern) {
            case (?_pattern) true;
            case null {
                // Check for potential phone numbers and emails
                hasPhonePattern(text) or hasEmailPattern(text)
            };
        }
    };

    // Check if value matches allowed reference patterns
    private func isAllowedReference(value: Text) : Bool {
        // Empty values are not allowed
        if (Text.size(value) == 0) {
            return false;
        };

        // Use Array.find to check against allowed patterns efficiently
        let matchesPattern = Array.find<Text>(ALLOWED_PATTERNS, func(pattern) {
            Text.startsWith(value, #text pattern)
        });

        switch (matchesPattern) {
            case (?_pattern) true;
            case null {
                // Allow simple numeric values (for tiers, levels, etc.)
                if (isNumeric(value) and Text.size(value) <= 3) {
                    true
                } else if (isHashLike(value)) {
                    // Allow hash-like patterns (32+ character alphanumeric)
                    true
                } else {
                    false
                }
            };
        }
    };

    // Check for phone number patterns
    private func hasPhonePattern(text: Text) : Bool {
        var digitCount = 0;
        var consecutiveDigits = 0;
        
        for (char in text.chars()) {
            if (Char.isDigit(char)) {
                digitCount += 1;
                consecutiveDigits += 1;
                
                // 10+ consecutive digits likely a phone number
                if (consecutiveDigits >= 10) {
                    return true;
                };
            } else {
                consecutiveDigits := 0;
            };
        };

        // Total of 10+ digits in string (even with separators)
        digitCount >= 10
    };

    // Check for email patterns
    private func hasEmailPattern(text: Text) : Bool {
        // Simple email detection
        if (Text.contains(text, #char '@')) {
            let parts = Text.split(text, #char '@');
            let partsArray = Iter.toArray(parts);
            
            // Must have exactly 2 parts (local@domain)
            if (partsArray.size() == 2) {
                let domain = partsArray[1];
                // Check for common TLDs
                if (Text.contains(domain, #text ".com") or 
                    Text.contains(domain, #text ".org") or
                    Text.contains(domain, #text ".net") or
                    Text.contains(domain, #text ".edu")) {
                    return true;
                };
            };
        };
        
        false
    };

    // Check if string is purely numeric
    private func isNumeric(text: Text) : Bool {
        if (Text.size(text) == 0) {
            return false;
        };
        
        for (char in text.chars()) {
            if (not Char.isDigit(char)) {
                return false;
            };
        };
        
        true
    };

    // Check if string looks like a hash (long alphanumeric)
    private func isHashLike(text: Text) : Bool {
        let len = Text.size(text);
        
        // Hashes are typically 32+ characters
        if (len < 32) {
            return false;
        };
        
        // Should be alphanumeric only
        for (char in text.chars()) {
            if (not (Char.isAlphabetic(char) or Char.isDigit(char))) {
                return false;
            };
        };
        
        true
    };

    // Sanitize text by removing potential PII (for logging/debugging)
    public func sanitizeForLogging(text: Text) : Text {
        if (containsPII(text)) {
            return "[REDACTED-PII]";
        };
        
        // Truncate long strings that might contain PII
        if (Text.size(text) > 100) {
            // Simple truncation - take first 100 characters
            "[TRUNCATED:" # Int.toText(Text.size(text)) # "chars]"
        } else {
            text
        }
    };

    // Generate validation report for monitoring
    public func generateValidationReport(
        messagesChecked: Nat,
        violationsBlocked: Nat,
        commonViolationTypes: [(Text, Nat)]
    ) : {
        totalChecked: Nat;
        violationsBlocked: Nat;
        successRate: Float;
        topViolations: [(Text, Nat)];
        complianceRating: Text;
    } {
        let successRate = if (messagesChecked > 0) {
            1.0 - (Float.fromInt(violationsBlocked) / Float.fromInt(messagesChecked))
        } else {
            1.0
        };

        let complianceRating = if (successRate >= 0.99) {
            "EXCELLENT"
        } else if (successRate >= 0.95) {
            "GOOD"  
        } else if (successRate >= 0.90) {
            "ACCEPTABLE"
        } else {
            "NEEDS_ATTENTION"
        };

        {
            totalChecked = messagesChecked;
            violationsBlocked = violationsBlocked;
            successRate = successRate;
            topViolations = commonViolationTypes;
            complianceRating = complianceRating;
        }
    };

    // Advanced batch validation with detailed reporting using Result type
    public func validateMessageBatch(messages: [Message]) : Result.Result<{
        validCount: Nat;
        invalidCount: Nat;
        validationErrors: [(Text, NotificationError)];
    }, Text> {
        var validCount = 0;
        var invalidCount = 0;
        var validationErrors: [(Text, NotificationError)] = [];

        for (message in messages.vals()) {
            switch (validateMessage(message)) {
                case (#ok(_)) {
                    validCount += 1;
                };
                case (#err(error)) {
                    invalidCount += 1;
                    let messageId = switch (message.triad.userId) {
                        case (?userId) "msg-" # debug_show(userId);
                        case null "msg-unknown";
                    };
                    validationErrors := Array.append(validationErrors, [(messageId, error)]);
                };
            };
        };

        #ok({
            validCount = validCount;
            invalidCount = invalidCount;
            validationErrors = validationErrors;
        })
    };

    // Enhanced PII detection with detailed violation reporting
    public func detectPIIViolations(message: Message) : Result.Result<[{
        location: Text;
        violationType: Text;
        details: Text;
    }], Text> {
        var violations: [{location: Text; violationType: Text; details: Text}] = [];

        // Check message title
        if (containsPII(message.body.title)) {
            violations := Array.append(violations, [{
                location = "title";
                violationType = "PII_IN_TITLE";
                details = "Potential PII detected in message title";
            }]);
        };

        // Check message body
        if (containsPII(message.body.body)) {
            violations := Array.append(violations, [{
                location = "body";
                violationType = "PII_IN_BODY";
                details = "Potential PII detected in message body";
            }]);
        };

        // Check variables
        for ((key, value) in message.body.variables.vals()) {
            if (isForbiddenKey(key)) {
                violations := Array.append(violations, [{
                    location = "variable:" # key;
                    violationType = "FORBIDDEN_KEY";
                    details = "Variable key '" # key # "' is forbidden";
                }]);
            };
            
            if (containsPII(value)) {
                violations := Array.append(violations, [{
                    location = "variable:" # key;
                    violationType = "PII_IN_VALUE";
                    details = "Potential PII detected in variable value";
                }]);
            };
        };

        // Check actions
        for (i in Iter.range(0, message.actions.size() - 1)) {
            let action = message.actions[i];
            if (containsPII(action.labelText)) {
                violations := Array.append(violations, [{
                    location = "action[" # debug_show(i) # "].label";
                    violationType = "PII_IN_ACTION";
                    details = "Potential PII detected in action label";
                }]);
            };
        };

        #ok(violations)
    };

    // Test helper: Create safe test message variables
    public func createSafeTestVariables() : [(Text, Text)] {
        [
            ("paymentRef", "P-48271"),
            ("transactionId", "T-99881"),
            ("amountTier", "4"),
            ("riskLevel", "high"),
            ("userRef", "U-hash-abc123def456"),
            ("correlationId", "corr-789xyz-timestamp")
        ]
    };

    // Test helper: Create unsafe test message variables (for testing)
    public func createUnsafeTestVariables() : [(Text, Text)] {
        [
            ("email", "user@example.com"),         // Forbidden key + email
            ("phone", "555-123-4567"),             // Phone number
            ("firstName", "John"),                 // Forbidden key
            ("amount", "$50000"),                  // Exact amount
            ("address", "123 Main St")             // Forbidden key + PII
        ]
    };
}
