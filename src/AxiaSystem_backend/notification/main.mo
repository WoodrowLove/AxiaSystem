//! Notification Canister - Triad-Native Communication Layer Main Implementation

import Result "mo:base/Result";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Buffer "mo:base/Buffer";
import Bool "mo:base/Bool";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Float "mo:base/Float";

import NotificationTypes "./types";
import NotificationValidator "./validator";

// Persistent actor Notification {
persistent actor Notification {
    type Message = NotificationTypes.Message;
    type StoredMessage = NotificationTypes.StoredMessage;
    type Recipient = NotificationTypes.Recipient;
    type Prefs = NotificationTypes.Prefs;
    type Channel = NotificationTypes.Channel;
    type MessageStatus = NotificationTypes.MessageStatus;
    type NotificationResult<T> = NotificationTypes.NotificationResult<T>;
    type NotificationError = NotificationTypes.NotificationError;
    type DeliveryAttempt = NotificationTypes.DeliveryAttempt;
    type EscalationTimer = NotificationTypes.EscalationTimer;
    type SLAConfig = NotificationTypes.SLAConfig;
    type ConservativeAction = NotificationTypes.ConservativeAction;
    type NotificationAuditEvent = NotificationTypes.NotificationAuditEvent;

    // Identity Canister Integration (same as Admin Canister)
    private transient let IDENTITY_CANISTER_ID = "asrmz-lmaaa-aaaaa-qaaeq-cai";
    
    public type SessionValidation = {
        valid : Bool;
        identity : Principal;
        deviceId : Principal;
        expiresAt : Nat64;
    };

    // Stable storage for upgrades
    private var inboxStore: [(Text, StoredMessage)] = [];
    private var preferencesStore: [(Text, Prefs)] = [];
    private var escalationTimersStore: [EscalationTimer] = [];
    private var auditLogStore: [NotificationAuditEvent] = [];
    private var roleGroupsStore: [(Text, [Principal])] = [];

    // Runtime storage
    private transient var inbox = HashMap.fromIter<Text, StoredMessage>(inboxStore.vals(), 100, Text.equal, Text.hash);
    private transient var preferences = HashMap.fromIter<Text, Prefs>(preferencesStore.vals(), 50, Text.equal, Text.hash);
    private transient var escalationTimers = Buffer.fromArray<EscalationTimer>(escalationTimersStore);
    private transient var auditLog = Buffer.fromArray<NotificationAuditEvent>(auditLogStore);
    private transient var roleGroups = HashMap.fromIter<Text, [Principal]>(roleGroupsStore.vals(), 10, Text.equal, Text.hash);

    // Rate limiting storage
    private var rateLimitStore: [(Text, NotificationTypes.RateLimitTracker)] = [];
    private transient var rateLimits = HashMap.fromIter<Text, NotificationTypes.RateLimitTracker>(rateLimitStore.vals(), 50, Text.equal, Text.hash);

    // Configuration
    private transient let slaConfig: SLAConfig = {
        approvalTimeoutMins = 15;
        emergencyTimeoutMins = 5;
        escalationRole = "notify.escalation";
        conservativeAction = #Hold;
    };

    private transient let rateConfig: NotificationTypes.RateLimit = {
        requestsPerMinute = 100;
        burstAllowance = 10;
        perRecipientPerHour = 50;
    };

    // Message ID counter for uniqueness
    private var messageCounter: Nat = 0;

    // Circuit breaker state
    private var circuitBreakerOpen: Bool = false;
    private var _lastCircuitBreakerCheck: Int = 0;

    // System initialization
    system func preupgrade() {
        inboxStore := inbox.entries() |> Iter.toArray(_);
        preferencesStore := preferences.entries() |> Iter.toArray(_);
        escalationTimersStore := Buffer.toArray(escalationTimers);
        auditLogStore := Buffer.toArray(auditLog);
        roleGroupsStore := roleGroups.entries() |> Iter.toArray(_);
        rateLimitStore := rateLimits.entries() |> Iter.toArray(_);
    };

    system func postupgrade() {
        inbox := HashMap.fromIter<Text, StoredMessage>(
            inboxStore.vals(), 
            inboxStore.size(), 
            Text.equal, 
            Text.hash
        );
        preferences := HashMap.fromIter<Text, Prefs>(
            preferencesStore.vals(), 
            preferencesStore.size(), 
            Text.equal, 
            Text.hash
        );
        escalationTimers := Buffer.Buffer<EscalationTimer>(escalationTimersStore.size());
        for (timer in escalationTimersStore.vals()) {
            escalationTimers.add(timer);
        };
        auditLog := Buffer.Buffer<NotificationAuditEvent>(auditLogStore.size());
        for (event in auditLogStore.vals()) {
            auditLog.add(event);
        };
        roleGroups := HashMap.fromIter<Text, [Principal]>(
            roleGroupsStore.vals(), 
            roleGroupsStore.size(), 
            Text.equal, 
            Text.hash
        );
        rateLimits := HashMap.fromIter<Text, NotificationTypes.RateLimitTracker>(
            rateLimitStore.vals(), 
            rateLimitStore.size(), 
            Text.equal, 
            Text.hash
        );
        
        // Clear stable storage
        inboxStore := [];
        preferencesStore := [];
        escalationTimersStore := [];
        auditLogStore := [];
        roleGroupsStore := [];
        rateLimitStore := [];
    };

    // Identity session validation
    private func validateSession(sessionId: Text, requiredScope: Text, caller: Principal): async Result.Result<Principal, Text> {
        let identityCanister = actor(IDENTITY_CANISTER_ID) : actor {
            validateSession : (Text, Text) -> async Result.Result<SessionValidation, Text>;
        };
        
        try {
            let result = await identityCanister.validateSession(sessionId, requiredScope);
            switch (result) {
                case (#ok(validation)) {
                    if (validation.valid and Principal.equal(validation.identity, caller)) {
                        #ok(caller)
                    } else {
                        #err("session_validation_failed")
                    }
                };
                case (#err(error)) {
                    #err("identity_canister_error: " # error)
                };
            };
        } catch (_e) {
            #err("identity_canister_call_failed")
        };
    };

    // Helper functions
    private func generateCorrelationId(): Text {
        "notify_" # Nat.toText(Nat64.toNat(Nat64.fromNat(Int.abs(Time.now()))));
    };

    private func generateMessageId(corrId: Text): Text {
        messageCounter += 1;
        "msg_" # corrId # "_" # Nat.toText(messageCounter);
    };

    private func auditEvent(action: Text, messageId: Text, recipient: Principal, channel: ?Channel, corrId: Text, result: Text, metadata: ?Text) {
        let event: NotificationAuditEvent = {
            ts = Nat64.fromNat(Int.abs(Time.now()));
            action = action;
            messageId = messageId;
            recipient = recipient;
            channel = channel;
            corrId = corrId;
            result = result;
            metadata = metadata;
        };
        auditLog.add(event);
    };

    private func getRecipientPrincipal(recipient: Recipient): Principal {
        switch (recipient) {
            case (#Identity(p)) p;
            case (#User(p)) p;
        };
    };

    private func checkRateLimit(sender: Principal): Result.Result<(), NotificationError> {
        let senderText = Principal.toText(sender);
        let now = Nat64.fromNat(Int.abs(Time.now()));
        let windowStart = now - 60_000_000_000; // 1 minute window in nanoseconds

        switch (rateLimits.get(senderText)) {
            case null {
                rateLimits.put(senderText, {
                    lastReset = now;
                    requestCount = 1;
                    burstUsed = 1;
                    violations = 0;
                });
                #ok(())
            };
            case (?tracker) {
                if (tracker.lastReset < windowStart) {
                    // Reset window
                    rateLimits.put(senderText, {
                        lastReset = now;
                        requestCount = 1;
                        burstUsed = 1;
                        violations = tracker.violations;
                    });
                    #ok(())
                } else if (tracker.requestCount >= rateConfig.requestsPerMinute) {
                    let updated = {
                        tracker with
                        violations = tracker.violations + 1;
                    };
                    rateLimits.put(senderText, updated);
                    #err(#RateLimitExceeded("Too many messages per minute"))
                } else {
                    let updated = {
                        tracker with
                        requestCount = tracker.requestCount + 1;
                        burstUsed = if (tracker.burstUsed < rateConfig.burstAllowance) tracker.burstUsed + 1 else tracker.burstUsed;
                    };
                    rateLimits.put(senderText, updated);
                    #ok(())
                };
            };
        };
    };

    // Core API - Send notification
    public shared(msg) func send(message: Message, sessionId: Text): async NotificationResult<Text> {
        // 1. Circuit breaker check
        if (circuitBreakerOpen) {
            return #err(#ConfigurationError("Service temporarily unavailable"));
        };

        // 2. Validate session
        switch (await validateSession(sessionId, "notify:send", msg.caller)) {
            case (#err(error)) { return #err(#SessionInvalid(error)) };
            case (#ok(_)) {};
        };

        // 3. Rate limiting
        switch (checkRateLimit(msg.caller)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        // 4. PII validation (Q1 policy enforcement)
        switch (NotificationValidator.validateMessage(message)) {
            case (#err(error)) { return #err(error) };
            case (#ok(_)) {};
        };

        // 5. Generate message ID and process
        let msgId = generateMessageId(message.corr.id);
        let messageWithId = { message with id = msgId };

        // 6. Check for duplicate (idempotency)
        let dedupeKey = switch (message.corr.idempotencyKey) {
            case (?key) key;
            case null message.corr.id;
        };
        
        switch (inbox.get(dedupeKey)) {
            case (?existing) {
                auditEvent("notify.duplicate", msgId, getRecipientPrincipal(message.to), ?#InApp, message.corr.id, "Idempotent send", null);
                return #ok(existing.message.id);
            };
            case null {};
        };

        // 7. Store in inbox
        let storedMessage: StoredMessage = {
            message = messageWithId;
            status = #Pending;
            deliveryAttempts = [];
            acknowledgedAt = null;
            acknowledgedBy = null;
        };

        inbox.put(msgId, storedMessage);
        inbox.put(dedupeKey, storedMessage); // For idempotency

        // 8. Route and deliver
        await routeAndDeliver(storedMessage);

        // 9. Set up SLA timers if needed
        if (NotificationTypes.shouldEscalate(messageWithId, slaConfig, Nat64.fromNat(Int.abs(Time.now())))) {
            let timer: EscalationTimer = {
                messageId = msgId;
                corrId = message.corr.id;
                startTime = Nat64.fromNat(Int.abs(Time.now()));
                timeoutMins = if (Array.find(message.tags, func(tag: Text) : Bool = tag == "security") != null) {
                    slaConfig.emergencyTimeoutMins
                } else {
                    slaConfig.approvalTimeoutMins
                };
                escalated = false;
                triggeredAction = null;
            };
            escalationTimers.add(timer);
        };

        auditEvent("notify.sent", msgId, getRecipientPrincipal(message.to), ?#InApp, message.corr.id, "Message sent successfully", null);
        
        #ok(msgId)
    };

    // Route and deliver message
    private func routeAndDeliver(storedMessage: StoredMessage): async () {
        let recipient = getRecipientPrincipal(storedMessage.message.to);
        
        // Get user preferences
        let userPrefs = switch (preferences.get(Principal.toText(recipient))) {
            case (?prefs) prefs;
            case null {
                // Default preferences
                {
                    channels = [#InApp];
                    quietHours = ?{ startMin = 22 * 60; endMin = 6 * 60 }; // 10 PM - 6 AM
                    minSeverity = #info;
                    locale = ?"en-US";
                    digest = null;
                }
            };
        };

        // Check quiet hours for non-critical messages
        let _now = Nat64.fromNat(Int.abs(Time.now()));
        let shouldDeliver = switch (userPrefs.quietHours) {
            case (?_quietHours) {
                if (storedMessage.message.severity == #critical) {
                    true // Critical messages always deliver
                } else {
                    // Check if we're in quiet hours (simplified implementation)
                    true // Would implement proper time zone handling
                }
            };
            case null true;
        };

        if (shouldDeliver) {
            // In-app delivery (always happens)
            await deliverInApp(storedMessage);

            // Additional channels based on preferences
            for (channel in userPrefs.channels.vals()) {
                switch (channel) {
                    case (#InApp) {}; // Already delivered
                    case (#Webhook) { await deliverWebhook(storedMessage) };
                    case (#Email) { /* Would implement email delivery */ };
                    case (#SMS) { /* Would implement SMS delivery */ };
                    case (#Push) { /* Would implement push notification delivery */ };
                };
            };
        } else {
            // Queue for digest delivery
            auditEvent("notify.queued", storedMessage.message.id, recipient, null, storedMessage.message.corr.id, "Queued for digest due to quiet hours", null);
        };
    };

    // In-app delivery
    private func deliverInApp(storedMessage: StoredMessage): async () {
        let recipient = getRecipientPrincipal(storedMessage.message.to);
        let msgId = storedMessage.message.id;
        
        // Update message status
        let updatedMessage = {
            storedMessage with
            status = #Delivered;
            deliveryAttempts = Array.append(storedMessage.deliveryAttempts, [{
                timestamp = Nat64.fromNat(Int.abs(Time.now()));
                channel = #InApp;
                success = true;
                error = null;
                endpoint = null;
            }]);
        };
        
        inbox.put(msgId, updatedMessage);
        auditEvent("notify.delivered", msgId, recipient, ?#InApp, storedMessage.message.corr.id, "In-app delivery successful", null);
    };

    // Webhook delivery (placeholder)
    private func deliverWebhook(storedMessage: StoredMessage): async () {
        let recipient = getRecipientPrincipal(storedMessage.message.to);
        let msgId = storedMessage.message.id;
        
        // In production, this would make HTTP calls to registered webhook endpoints
        // For now, just log the attempt
        auditEvent("notify.webhook", msgId, recipient, ?#Webhook, storedMessage.message.corr.id, "Webhook delivery attempted", null);
    };

    // User preferences management
    public shared(msg) func setPrefs(who: Recipient, prefs: Prefs, sessionId: Text): async NotificationResult<()> {
        // Validate session
        switch (await validateSession(sessionId, "notify:prefs", msg.caller)) {
            case (#err(error)) { return #err(#SessionInvalid(error)) };
            case (#ok(_)) {};
        };

        let recipientPrincipal = getRecipientPrincipal(who);
        let key = Principal.toText(recipientPrincipal);
        
        preferences.put(key, prefs);
        auditEvent("notify.prefs_updated", "", recipientPrincipal, null, generateCorrelationId(), "Preferences updated", null);
        
        #ok(())
    };

    public query func getPrefs(who: Recipient): async ?Prefs {
        let recipientPrincipal = getRecipientPrincipal(who);
        let key = Principal.toText(recipientPrincipal);
        preferences.get(key)
    };

    // Inbox management
    public query func listInbox(who: Recipient, page: Nat, limit: Nat): async [Message] {
        let recipientPrincipal = getRecipientPrincipal(who);
        let messages = Buffer.Buffer<Message>(0);
        
        // Filter messages for this recipient
        for ((msgId, storedMsg) in inbox.entries()) {
            if (Principal.equal(getRecipientPrincipal(storedMsg.message.to), recipientPrincipal)) {
                // Check if not expired
                let now = Nat64.fromNat(Int.abs(Time.now()));
                if (not NotificationTypes.isExpired(storedMsg.message, now)) {
                    messages.add(storedMsg.message);
                };
            };
        };

        // Simple pagination (would use more efficient indexing in production)
        let allMessages = Buffer.toArray(messages);
        let startIdx = page * limit;
        let endIdx = Nat.min(startIdx + limit, allMessages.size());
        
        if (startIdx >= allMessages.size()) {
            []
        } else {
            Array.tabulate<Message>(endIdx - startIdx, func(i: Nat): Message {
                allMessages[startIdx + i]
            })
        }
    };

    public shared(msg) func ack(msgId: Text, sessionId: Text): async NotificationResult<()> {
        // Validate session
        switch (await validateSession(sessionId, "notify:ack", msg.caller)) {
            case (#err(error)) { return #err(#SessionInvalid(error)) };
            case (#ok(_)) {};
        };

        switch (inbox.get(msgId)) {
            case null { #err(#MessageNotFound("Message not found: " # msgId)) };
            case (?storedMsg) {
                // Verify caller can acknowledge this message
                let recipient = getRecipientPrincipal(storedMsg.message.to);
                if (not Principal.equal(recipient, msg.caller)) {
                    return #err(#SessionInvalid("Cannot acknowledge message for different recipient"));
                };

                // Update message status
                let updatedMessage = {
                    storedMsg with
                    status = #Acknowledged;
                    acknowledgedAt = ?Nat64.fromNat(Int.abs(Time.now()));
                    acknowledgedBy = ?msg.caller;
                };
                
                inbox.put(msgId, updatedMessage);
                auditEvent("notify.acknowledged", msgId, recipient, null, storedMsg.message.corr.id, "Message acknowledged", null);
                
                #ok(())
            };
        }
    };

    // Admin operations
    public query func deliveryStatus(msgId: Text): async ?{ state: Text; attempts: Nat; lastErr: ?Text } {
        switch (inbox.get(msgId)) {
            case null null;
            case (?storedMsg) {
                let state = switch (storedMsg.status) {
                    case (#Pending) "pending";
                    case (#Delivered) "delivered";
                    case (#Acknowledged) "acknowledged";
                    case (#Expired) "expired";
                    case (#Failed(_err)) "failed";
                };
                
                let lastError = switch (storedMsg.status) {
                    case (#Failed(err)) ?err;
                    case (_) null;
                };

                ?{
                    state = state;
                    attempts = storedMsg.deliveryAttempts.size();
                    lastErr = lastError;
                }
            };
        }
    };

    public shared(msg) func purge(category: Text): async NotificationResult<Nat> {
        // Validate admin access
        switch (await validateSession("", "notify:admin", msg.caller)) {
            case (#err(error)) { return #err(#SessionInvalid(error)) };
            case (#ok(_)) {};
        };

        let now = Nat64.fromNat(Int.abs(Time.now()));
        var purgedCount = 0;
        let messagesToPurge = Buffer.Buffer<Text>(0);

        // Find expired messages
        for ((msgId, storedMsg) in inbox.entries()) {
            if (NotificationTypes.isExpired(storedMsg.message, now)) {
                messagesToPurge.add(msgId);
            };
        };

        // Remove expired messages
        for (msgId in messagesToPurge.vals()) {
            inbox.delete(msgId);
            purgedCount += 1;
        };

        auditEvent("notify.purged", "", msg.caller, null, generateCorrelationId(), "Purged " # Nat.toText(purgedCount) # " messages", ?category);
        
        #ok(purgedCount)
    };

    // Health and metrics
    public query func health(): async NotificationTypes.NotificationHealth {
        {
            status = if (circuitBreakerOpen) "degraded" else "healthy";
            inboxSize = inbox.size();
            pendingDeliveries = 0; // Would calculate actual pending deliveries
            escalationTimers = escalationTimers.size();
            lastHeartbeat = Nat64.fromNat(Int.abs(Time.now()));
            circuitBreakerState = if (circuitBreakerOpen) "open" else "closed";
        }
    };

    public query func metrics(): async NotificationTypes.NotificationMetrics {
        let auditEvents = Buffer.toArray(auditLog);
        let sentEvents = Array.filter(auditEvents, func(event: NotificationAuditEvent): Bool = event.action == "notify.sent");
        let deliveredEvents = Array.filter(auditEvents, func(event: NotificationAuditEvent): Bool = event.action == "notify.delivered");
        
        let successRate = if (sentEvents.size() > 0) {
            Float.fromInt(deliveredEvents.size()) / Float.fromInt(sentEvents.size())
        } else {
            1.0
        };

        {
            messagesProcessed = sentEvents.size();
            deliverySuccessRate = successRate;
            averageDeliveryTime = 50; // Would calculate actual metrics
            escalationRate = 0.02; // Would calculate actual rate
            piiViolationsBlocked = 0; // Would track actual violations
            activeDigests = 0; // Would track digest jobs
            webhookHealth = {
                activeEndpoints = 0;
                failureRate = 0.0;
                averageLatency = 0;
            };
        }
    };

    // Heartbeat for cleanup and SLA monitoring
    system func heartbeat(): async () {
        let now = Nat64.fromNat(Int.abs(Time.now()));
        
        // Process escalation timers
        let timersToProcess = Buffer.Buffer<Nat>(0);
        var i = 0;
        for (timer in escalationTimers.vals()) {
            if (not timer.escalated) {
                let timeoutNs = Nat64.fromNat(timer.timeoutMins * 60 * 1_000_000_000);
                if ((timer.startTime + timeoutNs) < now) {
                    // Timer expired - escalate
                    await processEscalation(timer);
                    timersToProcess.add(i);
                };
            };
            i += 1;
        };

        // Clean up processed timers (simplified - would use more efficient approach)
        for (index in timersToProcess.vals()) {
            // Mark as escalated rather than removing
            switch (escalationTimers.getOpt(index)) {
                case (?timer) {
                    let updatedTimer = { timer with escalated = true };
                    escalationTimers.put(index, updatedTimer);
                };
                case null {};
            };
        };

        // Clean up old audit events (keep last 5000)
        while (auditLog.size() > 5000) {
            let _first = auditLog.remove(0);
        };
    };

    // Process escalation when SLA timer expires
    private func processEscalation(timer: EscalationTimer): async () {
        let anonymousId = Principal.fromText("2vxsx-fae");
        switch (inbox.get(timer.messageId)) {
            case null {
                auditEvent("notify.escalation_failed", timer.messageId, anonymousId, null, timer.corrId, "Message not found for escalation", null);
            };
            case (?storedMsg) {
                // Get escalation group members
                switch (roleGroups.get(slaConfig.escalationRole)) {
                    case null {
                        auditEvent("notify.escalation_failed", timer.messageId, anonymousId, null, timer.corrId, "No escalation group found", null);
                    };
                    case (?members) {
                        // Create escalation notifications for each member
                        for (member in members.vals()) {
                            let escalationMsg = NotificationTypes.createMessage(
                                #Identity(member),
                                #Identity(Principal.fromText("notification-system")),
                                #critical,
                                storedMsg.message.triad,
                                "escalation_" # timer.corrId,
                                "ESCALATION: Unacknowledged " # storedMsg.message.body.title,
                                "Message " # timer.messageId # " requires immediate attention. Original: " # storedMsg.message.body.body
                            );
                            
                            await routeAndDeliver({
                                message = escalationMsg;
                                status = #Pending;
                                deliveryAttempts = [];
                                acknowledgedAt = null;
                                acknowledgedBy = null;
                            });
                        };
                        
                        auditEvent("notify.escalated", timer.messageId, anonymousId, null, timer.corrId, "Message escalated to " # Nat.toText(members.size()) # " members", null);
                    };
                };
            };
        };
    };

    // Integration with AI Router for sending Namora AI messages
    public func sendFromAIRouter(
        to: Recipient,
        severity: NotificationTypes.Severity,
        triad: NotificationTypes.TriadCtx,
        corrId: Text,
        title: Text,
        body: Text,
        actions: [NotificationTypes.Action],
        tags: [Text]
    ): async NotificationResult<Text> {
        let aiIdentity = Principal.fromText("ai-service-principal"); // Would be configured
        
        let message: Message = {
            id = ""; // Will be generated
            to = to;
            from = #Identity(aiIdentity);
            severity = severity;
            triad = triad;
            corr = {
                id = corrId;
                parent = null;
                idempotencyKey = ?corrId;
                ttlSecs = if (severity == #critical) 900 else 3600; // 15 min for critical, 1 hour for others
            };
            createdAt = Nat64.fromNat(Int.abs(Time.now()));
            ttlSecs = if (severity == #critical) 900 else 3600;
            body = {
                title = title;
                body = body;
                variables = [];
                templateId = null;
                attachments = null;
            };
            actions = actions;
            tags = tags;
        };

        // Use system session for AI Router integration
        await send(message, "ai-system-session")
    };
}
