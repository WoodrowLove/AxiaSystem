import _Debug "mo:base/Debug";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Result "mo:base/Result";
import _Iter "mo:base/Iter";
import Char "mo:base/Char";

import AIEnvelope "../types/ai_envelope";

module DataContractValidator {
    
    type AIRequest = AIEnvelope.AIRequest;
    type AIPayload = AIEnvelope.AIPayload;
    
    // Q1 Policy: Reference IDs + Hashed Features Only
    private let FORBIDDEN_FIELDS = [
        "username", "userName", "user_name",
        "email", "emailAddress", "email_address", 
        "phone", "phoneNumber", "phone_number",
        "ssn", "socialSecurity", "social_security",
        "address", "streetAddress", "street_address",
        "name", "firstName", "lastName", "first_name", "last_name",
        "dob", "dateOfBirth", "date_of_birth",
        "creditCard", "credit_card", "bankAccount", "bank_account",
        "ip", "ipAddress", "ip_address",
        "exactAmount", "exact_amount", "amount"
    ];
    
    private let _REQUIRED_FIELDS = [
        "userId", "amountTier", "riskFactors", "patternHash"
    ];
    
    public func validateRequest(request: AIRequest) : Result.Result<(), Text> {
        // 1. Validate envelope structure
        switch (validateEnvelope(request)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };
        
        // 2. Validate payload compliance
        switch (validatePayload(request.payload)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };
        
        // 3. Validate metadata compliance
        switch (validateMetadata(request.payload.metadata)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };
        
        #ok()
    };
    
    private func validateEnvelope(request: AIRequest) : Result.Result<(), Text> {
        // Basic envelope validation
        if (Text.size(request.correlationId) == 0) {
            return #err("correlationId is required");
        };
        
        if (Text.size(request.idempotencyKey) == 0) {
            return #err("idempotencyKey is required");
        };
        
        if (Text.size(request.sessionId) == 0) {
            return #err("sessionId is required");
        };
        
        if (Text.size(request.submitterId) == 0) {
            return #err("submitterId is required");
        };
        
        if (request.timeoutMs == 0 or request.timeoutMs > 5000) {
            return #err("timeoutMs must be between 1 and 5000 milliseconds");
        };
        
        #ok()
    };
    
    private func validatePayload(payload: AIPayload) : Result.Result<(), Text> {
        // 1. Check required fields
        if (Text.size(payload.userId) == 0) {
            return #err("userId is required and cannot be empty");
        };
        
        if (payload.amountTier < 1 or payload.amountTier > 5) {
            return #err("amountTier must be between 1 and 5 (Q1 policy compliance)");
        };
        
        if (payload.riskFactors.size() == 0) {
            return #err("riskFactors array cannot be empty");
        };
        
        if (Text.size(payload.patternHash) == 0) {
            return #err("patternHash is required and cannot be empty");
        };
        
        // 2. Validate userId appears to be hashed (basic check)
        if (not isHashedIdentifier(payload.userId)) {
            return #err("userId must be a hashed identifier (Q1 policy violation)");
        };
        
        // 3. Validate risk factors don't contain PII
        for (factor in payload.riskFactors.vals()) {
            switch (containsForbiddenContent(factor)) {
                case (#err(error)) { return #err("riskFactor contains PII: " # error) };
                case (#ok(_)) {};
            };
        };
        
        // 4. Validate pattern hash format
        if (not isValidPatternHash(payload.patternHash)) {
            return #err("patternHash format is invalid");
        };
        
        #ok()
    };
    
    private func validateMetadata(metadata: [(Text, Text)]) : Result.Result<(), Text> {
        for ((key, value) in metadata.vals()) {
            // Check key names for PII indicators
            let lowerKey = Text.map(key, func (c: Char) : Char {
                if (c >= 'A' and c <= 'Z') {
                    Char.fromNat32(Char.toNat32(c) + 32)
                } else {
                    c
                }
            });
            
            if (Array.find<Text>(FORBIDDEN_FIELDS, func(forbidden) = Text.contains(lowerKey, #text forbidden)) != null) {
                return #err("Metadata key '" # key # "' indicates potential PII (Q1 policy violation)");
            };
            
            // Check values for PII patterns
            switch (containsForbiddenContent(value)) {
                case (#err(error)) { return #err("Metadata value for key '" # key # "' contains PII: " # error) };
                case (#ok(_)) {};
            };
        };
        
        #ok()
    };
    
    private func isHashedIdentifier(userId: Text) : Bool {
        // Basic heuristics for identifying hashed values
        let length = Text.size(userId);
        
        // Common hash lengths: MD5(32), SHA-1(40), SHA-256(64), SHA-512(128)
        if (length != 32 and length != 40 and length != 64 and length != 128) {
            return false;
        };
        
        // Check if it's hexadecimal
        for (char in userId.chars()) {
            switch (char) {
                case ('0' or '1' or '2' or '3' or '4' or '5' or '6' or '7' or '8' or '9' or 
                      'a' or 'b' or 'c' or 'd' or 'e' or 'f' or 
                      'A' or 'B' or 'C' or 'D' or 'E' or 'F') {};
                case (_) { return false };
            }
        };
        
        true
    };
    
    private func isValidPatternHash(patternHash: Text) : Bool {
        // Similar to userId validation
        let length = Text.size(patternHash);
        length >= 32 and length <= 128 and isHexadecimal(patternHash)
    };
    
    private func isHexadecimal(text: Text) : Bool {
        for (char in text.chars()) {
            switch (char) {
                case ('0' or '1' or '2' or '3' or '4' or '5' or '6' or '7' or '8' or '9' or 
                      'a' or 'b' or 'c' or 'd' or 'e' or 'f' or 
                      'A' or 'B' or 'C' or 'D' or 'E' or 'F') {};
                case (_) { return false };
            }
        };
        true
    };
    
    private func containsForbiddenContent(content: Text) : Result.Result<(), Text> {
        let lowerContent = Text.map(content, func (c: Char) : Char {
            if (c >= 'A' and c <= 'Z') {
                Char.fromNat32(Char.toNat32(c) + 32)
            } else {
                c
            }
        });
        
        // Check for forbidden field patterns
        for (forbidden in FORBIDDEN_FIELDS.vals()) {
            if (Text.contains(lowerContent, #text forbidden)) {
                return #err("Content contains forbidden pattern: " # forbidden);
            };
        };
        
        // Check for email patterns
        if (Text.contains(lowerContent, #text "@") and Text.contains(lowerContent, #text ".")) {
            return #err("Content appears to contain email address");
        };
        
        // Check for phone patterns (basic)
        if (containsPhonePattern(lowerContent)) {
            return #err("Content appears to contain phone number");
        };
        
        // Check for SSN patterns
        if (containsSSNPattern(lowerContent)) {
            return #err("Content appears to contain SSN");
        };
        
        #ok()
    };
    
    private func containsPhonePattern(content: Text) : Bool {
        // Basic phone pattern detection: sequences of digits with common separators
        var digitCount = 0;
        for (char in content.chars()) {
            if (char >= '0' and char <= '9') {
                digitCount += 1;
            };
        };
        
        // If there are 10+ digits and separators, likely a phone number
        digitCount >= 10 and (
            Text.contains(content, #text "-") or 
            Text.contains(content, #text "(") or 
            Text.contains(content, #text ")") or
            Text.contains(content, #text " ")
        )
    };
    
    private func containsSSNPattern(content: Text) : Bool {
        // Basic SSN pattern: XXX-XX-XXXX or similar
        var digitCount = 0;
        for (char in content.chars()) {
            if (char >= '0' and char <= '9') {
                digitCount += 1;
            };
        };
        
        digitCount == 9 and Text.contains(content, #text "-")
    };
    
    // Public validation function for use by other modules
    public func isCompliant(payload: AIPayload) : Bool {
        switch (validatePayload(payload)) {
            case (#ok(_)) true;
            case (#err(_)) false;
        }
    };
    
    // Generate compliance report
    public func generateComplianceReport(payload: AIPayload) : {
        compliant: Bool;
        violations: [Text];
        recommendations: [Text];
    } {
        var violations: [Text] = [];
        var recommendations: [Text] = [];
        
        // Check each validation aspect
        switch (validatePayload(payload)) {
            case (#ok(_)) {
                // Compliant
            };
            case (#err(error)) {
                violations := Array.append(violations, [error]);
            };
        };
        
        switch (validateMetadata(payload.metadata)) {
            case (#ok(_)) {
                // Compliant
            };
            case (#err(error)) {
                violations := Array.append(violations, [error]);
            };
        };
        
        // Add recommendations based on violations
        if (violations.size() > 0) {
            recommendations := [
                "Ensure all user identifiers are properly hashed",
                "Use amount tiers (1-5) instead of exact amounts",
                "Remove any personally identifiable information",
                "Use categorical risk factors only",
                "Validate pattern hashes are properly generated"
            ];
        };
        
        {
            compliant = violations.size() == 0;
            violations = violations;
            recommendations = recommendations;
        }
    };
}
