//! Notification System Types - Triad-Native Communication Layer

import Time "mo:base/Time";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Array "mo:base/Array";

module NotificationTypes {
    // Core communication types aligned with Communication Layer Manifest
    
    public type TriadCtx = {
        identityId : Principal;
        userId     : ?Principal;
        walletId   : ?Principal;
    };

    public type Corr = {
        id              : Text;           // global correlation id (UUIDv4 or similar)
        parent          : ?Text;
        idempotencyKey  : ?Text;          // dedupe across retries
        ttlSecs         : Nat32;          // optional expiry
    };

    public type Severity = { #info; #warn; #critical };

    public type Channel = { #InApp; #Webhook; #Email; #SMS; #Push };

    public type Recipient = { #Identity : Principal; #User : Principal };

    public type Prefs = {
        channels     : [Channel];
        quietHours   : ?{ startMin : Nat16; endMin : Nat16 }; // local day minutes
        minSeverity  : Severity;
        locale       : ?Text;    // e.g., "en-US"
        digest       : ?{ scheduleCron : Text; minSeverity : Severity };
    };

    public type Action = {
        labelText : Text;                    // "Approve", "Deny"
        command : {                          // deterministic action hook
            scope   : Text;                  // e.g., "gov:approve", "payment:approve"
            name    : Text;                  // method alias
            args    : Blob;                  // CBOR/JSON args (no PII)
        };
        url     : ?Text;                     // optional deep link (app://...)
    };

    public type MsgBody = {
        // MINIMIZED CONTENT. No raw PII; use references and redacted text.
        title       : Text;
        body        : Text;                  // templated, safe content only
        variables   : [(Text, Text)];        // redacted strings; validated by validator
        templateId  : ?Text;                 // for i18n rendering on client
        attachments : ?[Blob];               // discouraged; disable by default
    };

    public type Message = {
        id        : Text;                    // message id (server-generated)
        to        : Recipient;
        from      : Recipient;               // usually Namora AI Identity
        severity  : Severity;
        triad     : TriadCtx;
        corr      : Corr;
        createdAt : Nat64;
        ttlSecs   : Nat32;
        body      : MsgBody;
        actions   : [Action];
        tags      : [Text];                  // "approval", "security", "compliance"
    };

    public type MessageStatus = {
        #Pending;
        #Delivered;
        #Acknowledged;
        #Expired;
        #Failed : Text;
    };

    public type DeliveryAttempt = {
        timestamp : Nat64;
        channel   : Channel;
        success   : Bool;
        error     : ?Text;
        endpoint  : ?Text;  // For webhook/external channels
    };

    public type StoredMessage = {
        message : Message;
        status  : MessageStatus;
        deliveryAttempts : [DeliveryAttempt];
        acknowledgedAt : ?Nat64;
        acknowledgedBy : ?Principal;
    };

    // Escalation and SLA types
    public type SLAConfig = {
        approvalTimeoutMins : Nat;    // 15 min default
        emergencyTimeoutMins : Nat;   // 5 min default
        escalationRole : Text;        // "notify.escalation"
        conservativeAction : ConservativeAction;
    };

    public type ConservativeAction = {
        #Hold;
        #Deny;
        #RequireManualReview;
    };

    public type EscalationTimer = {
        messageId : Text;
        corrId : Text;
        startTime : Nat64;
        timeoutMins : Nat;
        escalated : Bool;
        triggeredAction : ?ConservativeAction;
    };

    // Digest and batching types
    public type DigestEntry = {
        messageIds : [Text];
        recipient : Recipient;
        scheduledFor : Nat64;
        createdAt : Nat64;
        delivered : Bool;
    };

    // Webhook and adapter types
    public type WebhookEndpoint = {
        url : Text;
        secret : Text;  // HMAC key
        active : Bool;
        retryConfig : WebhookRetryConfig;
    };

    public type WebhookRetryConfig = {
        maxRetries : Nat;
        backoffMs : Nat;
        timeoutMs : Nat;
    };

    public type WebhookPayload = {
        messageId : Text;
        message : Message;
        signature : Text;  // HMAC-SHA256
        timestamp : Nat64;
        actionTokens : ?[ActionToken];
    };

    public type ActionToken = {
        action : Text;     // "approve", "deny"
        token : Text;      // Short-lived, single-use
        expiresAt : Nat64;
    };

    // Audit and compliance types
    public type NotificationAuditEvent = {
        ts : Nat64;
        action : Text;  // "notify.sent", "notify.delivered", etc.
        messageId : Text;
        recipient : Principal;
        channel : ?Channel;
        corrId : Text;
        result : Text;
        metadata : ?Text;
    };

    // Retention and cleanup types
    public type RetentionCategory = {
        #Inbox;           // 90 days default
        #Sensitive;       // 30 days
        #Audit;          // 7 years (metadata only)
        #Operational;    // 2 years (anonymized)
    };

    public type RetentionRule = {
        category : RetentionCategory;
        retentionDays : Nat;
        purgeAfterExpiry : Bool;
        legalHoldExempt : Bool;
    };

    // Rate limiting and quotas
    public type RateLimit = {
        requestsPerMinute : Nat;
        burstAllowance : Nat;
        perRecipientPerHour : Nat;
    };

    public type RateLimitTracker = {
        lastReset : Nat64;
        requestCount : Nat;
        burstUsed : Nat;
        violations : Nat;
    };

    // Role-based recipient resolution
    public type RoleGroup = {
        role : Text;           // "notify.escalation", "notify.oncall"
        members : [Principal];
        lastUpdated : Nat64;
        active : Bool;
    };

    // Integration types for AI Router
    public type AIRouterIntegration = {
        routerCanisterId : Text;
        sessionRotationMins : Nat;  // 240 min = 4 hours
        allowedActions : [Text];     // Scoped actions this notification system can trigger
    };

    // Session management for AI Router integration
    public type NotificationSession = {
        sessionId : Text;
        principal : Principal;
        scope : Text;        // "notify:send", "notify:ack", "notify:admin"
        createdAt : Nat64;
        expiresAt : Nat64;
    };

    // Template system for i18n
    public type MessageTemplate = {
        id : Text;
        locale : Text;        // "en-US", "es-ES", etc.
        title : Text;
        body : Text;
        variables : [Text];   // Allowed variable names
        category : Text;      // "approval", "security", "alert"
    };

    // Error types
    public type NotificationError = {
        #SessionInvalid : Text;
        #RateLimitExceeded : Text;
        #PIIViolation : Text;
        #RecipientNotFound : Text;
        #MessageNotFound : Text;
        #DeliveryFailed : Text;
        #InvalidTemplate : Text;
        #ConfigurationError : Text;
    };

    public type NotificationResult<T> = Result.Result<T, NotificationError>;

    // Health and metrics types
    public type NotificationHealth = {
        status : Text;           // "healthy", "degraded", "unhealthy"
        inboxSize : Nat;
        pendingDeliveries : Nat;
        escalationTimers : Nat;
        lastHeartbeat : Nat64;
        circuitBreakerState : Text;
    };

    public type NotificationMetrics = {
        messagesProcessed : Nat;
        deliverySuccessRate : Float;
        averageDeliveryTime : Nat;
        escalationRate : Float;
        piiViolationsBlocked : Nat;
        activeDigests : Nat;
        webhookHealth : {
            activeEndpoints : Nat;
            failureRate : Float;
            averageLatency : Nat;
        };
    };

    // Helper functions for common operations
    public func createMessage(
        to: Recipient,
        from: Recipient,
        severity: Severity,
        triad: TriadCtx,
        corrId: Text,
        title: Text,
        body: Text
    ) : Message {
        {
            id = ""; // Will be set by notification system
            to = to;
            from = from;
            severity = severity;
            triad = triad;
            corr = {
                id = corrId;
                parent = null;
                idempotencyKey = ?corrId;
                ttlSecs = 3600; // 1 hour default
            };
            createdAt = Nat64.fromNat(Int.abs(Time.now()));
            ttlSecs = 3600;
            body = {
                title = title;
                body = body;
                variables = [];
                templateId = null;
                attachments = null;
            };
            actions = [];
            tags = [];
        }
    };

    public func createApprovalMessage(
        to: Recipient,
        from: Recipient,
        triad: TriadCtx,
        corrId: Text,
        title: Text,
        body: Text,
        approveScope: Text,
        denyScope: Text
    ) : Message {
        {
            id = "";
            to = to;
            from = from;
            severity = #critical;
            triad = triad;
            corr = {
                id = corrId;
                parent = null;
                idempotencyKey = ?corrId;
                ttlSecs = 900; // 15 min for approvals
            };
            createdAt = Nat64.fromNat(Int.abs(Time.now()));
            ttlSecs = 900;
            body = {
                title = title;
                body = body;
                variables = [];
                templateId = ?"approval.standard";
                attachments = null;
            };
            actions = [
                {
                    labelText = "Approve";
                    command = {
                        scope = approveScope;
                        name = "approve";
                        args = Text.encodeUtf8(corrId);
                    };
                    url = ?("app://approve?corr=" # corrId);
                },
                {
                    labelText = "Deny";
                    command = {
                        scope = denyScope;
                        name = "deny";
                        args = Text.encodeUtf8(corrId);
                    };
                    url = ?("app://deny?corr=" # corrId);
                }
            ];
            tags = ["approval"];
        }
    };

    public func severityToNat(severity: Severity) : Nat {
        switch (severity) {
            case (#info) 1;
            case (#warn) 2;
            case (#critical) 3;
        }
    };

    public func isExpired(message: Message, now: Nat64) : Bool {
        (message.createdAt + Nat64.fromNat(Nat32.toNat(message.ttlSecs))) < now
    };

    public func shouldEscalate(message: Message, config: SLAConfig, now: Nat64) : Bool {
        if (not (message.severity == #critical and 
                (Array.find(message.tags, func(tag: Text) : Bool = tag == "approval" or tag == "security") != null))) {
            return false;
        };
        
        let timeoutMins = if (Array.find(message.tags, func(tag: Text) : Bool = tag == "security") != null) {
            config.emergencyTimeoutMins
        } else {
            config.approvalTimeoutMins
        };
        
        let timeoutNs = Nat64.fromNat(timeoutMins * 60 * 1_000_000_000);
        (message.createdAt + timeoutNs) < now
    };

    public func generateMessageId(corrId: Text, timestamp: Nat64) : Text {
        "msg_" # corrId # "_" # Nat64.toText(timestamp)
    };

    public func validateNoPI(variables: [(Text, Text)]) : Bool {
        // Simple PII validation - would be more sophisticated in production
        for ((key, value) in variables.vals()) {
            // Check for common PII patterns
            if (Text.contains(key, #text "email") or 
                Text.contains(key, #text "phone") or 
                Text.contains(key, #text "name") or
                Text.contains(value, #text "@") or
                Text.size(value) == 10) { // Phone number length
                return false;
            };
        };
        true
    };
}
