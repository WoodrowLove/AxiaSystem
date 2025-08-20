import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Buffer "mo:base/Buffer";

import AICommunicationBridge "ai_communication_bridge";

// AI Router Actor - Central communication hub for sophos_ai integration
// Handles secure message passing, session management, and routing
persistent actor AIRouter {
    
    type AIMessage = AICommunicationBridge.AIMessage;
    type AIResponse = AICommunicationBridge.AIResponse;
    type MessageId = AICommunicationBridge.MessageId;
    type CorrelationId = AICommunicationBridge.CorrelationId;
    type SessionId = AICommunicationBridge.SessionId;
    type Priority = AICommunicationBridge.Priority;
    type SecurityContext = AICommunicationBridge.SecurityContext;
    
    public type AIRouterConfig = {
        maxConcurrentMessages : Nat;
        sessionTimeout : Int; // seconds
        rateLimitPerSession : Nat;
        enablePushNotifications : Bool;
        enablePullPolling : Bool;
        batchSize : Nat;
        retryAttempts : Nat;
    };
    
    private let defaultConfig : AIRouterConfig = {
        maxConcurrentMessages = 1000;
        sessionTimeout = 14400; // 4 hours
        rateLimitPerSession = 100; // per minute
        enablePushNotifications = true;
        enablePullPolling = true;
        batchSize = 10;
        retryAttempts = 3;
    };
    
    // Stable storage for persistence
    private var messages : [(MessageId, AIMessage)] = [];
    private var responses : [(CorrelationId, AIResponse)] = [];
    private var sessions : [(SessionId, SessionData)] = [];
    private var messageQueue : [QueuedMessage] = [];
    private var config : AIRouterConfig = defaultConfig;
    
    // Runtime state (transient)
    private transient var messageMap = HashMap.fromIter<MessageId, AIMessage>(messages.vals(), 1000, Text.equal, Text.hash);
    private transient var responseMap = HashMap.fromIter<CorrelationId, AIResponse>(responses.vals(), 1000, Text.equal, Text.hash);
    private transient var sessionMap = HashMap.fromIter<SessionId, SessionData>(sessions.vals(), 100, Text.equal, Text.hash);
    private transient var queueBuffer = Buffer.fromArray<QueuedMessage>(messageQueue);
    
    public type SessionData = {
        sessionId : SessionId;
        principalId : Text;
        createdAt : Int;
        lastActivity : Int;
        messageCount : Nat;
        rateLimitReset : Int;
        permissions : [Text];
        status : SessionStatus;
    };
    
    public type SessionStatus = {
        #Active;
        #Expired;
        #Suspended;
        #Terminated;
    };
    
    public type QueuedMessage = {
        message : AIMessage;
        queuedAt : Int;
        attempts : Nat;
        priority : Priority;
        targetEndpoint : Text;
    };
    
    public type RouterStatus = {
        activeMessages : Nat;
        queuedMessages : Nat;
        activeSessions : Nat;
        totalMessagesProcessed : Nat;
        averageResponseTime : Float;
        lastActivity : Int;
        systemHealth : Float;
    };
    
    // System lifecycle
    system func preupgrade() {
        messages := Iter.toArray(messageMap.entries());
        responses := Iter.toArray(responseMap.entries());
        sessions := Iter.toArray(sessionMap.entries());
        messageQueue := Buffer.toArray(queueBuffer);
    };
    
    system func postupgrade() {
        messages := [];
        responses := [];
        sessions := [];
        messageQueue := [];
    };
    
    // Initialize the AI Router
    public func initializeRouter() : async Result.Result<Text, Text> {
        Debug.print("AI Router: Initializing communication bridge with sophos_ai");
        
        // Set up default session for system operations
        let systemSession : SessionData = {
            sessionId = "system_session";
            principalId = "system";
            createdAt = Time.now();
            lastActivity = Time.now();
            messageCount = 0;
            rateLimitReset = Time.now() + 60_000_000_000; // 1 minute
            permissions = ["ai:submit", "ai:deliver", "ai:poll"];
            status = #Active;
        };
        
        sessionMap.put("system_session", systemSession);
        
        Debug.print("AI Router: Initialized successfully");
        #ok("AI Router initialized with system session")
    };
    
    // Submit message for AI processing
    public shared func submit(message : AIMessage, sessionId : SessionId) : async Result.Result<CorrelationId, Text> {
        // Validate session
        switch (sessionMap.get(sessionId)) {
            case null {
                return #err("Invalid session ID");
            };
            case (?sessionData) {
                if (sessionData.status != #Active) {
                    return #err("Session not active");
                };
                
                // Check rate limiting
                if (not checkRateLimit(sessionData)) {
                    return #err("Rate limit exceeded");
                };
                
                // Validate message
                if (not AICommunicationBridge.validateMessage(message)) {
                    return #err("Invalid message format");
                };
                
                // Generate correlation ID
                let correlationId = AICommunicationBridge.createCorrelationId();
                
                // Store message
                messageMap.put(message.id, message);
                
                // Queue for processing
                let queuedMessage : QueuedMessage = {
                    message = message;
                    queuedAt = Time.now();
                    attempts = 0;
                    priority = message.priority;
                    targetEndpoint = "sophos_ai";
                };
                
                // Add to queue (simplified - in production would use proper priority queue)
                queueBuffer.add(queuedMessage);
                
                // Update session activity
                updateSessionActivity(sessionId);
                
                Debug.print("AI Router: Message submitted with correlation ID: " # correlationId);
                #ok(correlationId)
            };
        }
    };
    
    // Poll for response (Pull mode)
    public query func poll(correlationId : CorrelationId) : async ?AIResponse {
        responseMap.get(correlationId)
    };
    
    // Deliver response from sophos_ai (Push mode)
    public shared func deliver(response : AIResponse, sessionId : SessionId) : async Result.Result<(), Text> {
        // Validate session
        switch (sessionMap.get(sessionId)) {
            case null {
                return #err("Invalid session ID");
            };
            case (?sessionData) {
                if (sessionData.status != #Active) {
                    return #err("Session not active");
                };
                
                // Store response
                responseMap.put(response.correlationId, response);
                
                // Process response
                let processResult = AICommunicationBridge.processResponse(response);
                if (not processResult) {
                    return #err("Failed to process AI response");
                };
                
                // Update session activity
                updateSessionActivity(sessionId);
                
                Debug.print("AI Router: Response delivered for correlation ID: " # response.correlationId);
                #ok(())
            };
        }
    };
    
    // Create new session
    public shared func createSession(principalId : Text, permissions : [Text]) : async Result.Result<SessionId, Text> {
        let sessionId = "session_" # Int.toText(Time.now());
        let currentTime = Time.now();
        
        let sessionData : SessionData = {
            sessionId = sessionId;
            principalId = principalId;
            createdAt = currentTime;
            lastActivity = currentTime;
            messageCount = 0;
            rateLimitReset = currentTime + 60_000_000_000; // 1 minute
            permissions = permissions;
            status = #Active;
        };
        
        sessionMap.put(sessionId, sessionData);
        
        Debug.print("AI Router: Created session " # sessionId # " for principal " # principalId);
        #ok(sessionId)
    };
    
    // Get messages for sophos_ai to pull
    public shared func pullMessages(sessionId : SessionId, maxCount : ?Nat) : async Result.Result<[AIMessage], Text> {
        // Validate session
        switch (sessionMap.get(sessionId)) {
            case null {
                return #err("Invalid session ID");
            };
            case (?sessionData) {
                if (sessionData.status != #Active) {
                    return #err("Session not active");
                };
                
                let limit = switch (maxCount) {
                    case (?count) { count };
                    case null { config.batchSize };
                };
                
                // Get messages from queue (simplified implementation)
                let queueSize = queueBuffer.size();
                let actualLimit = if (queueSize < limit) { queueSize } else { limit };
                
                var messagesToReturn : [AIMessage] = [];
                if (actualLimit > 0) {
                    var tempMessages : [AIMessage] = [];
                    for (i in Iter.range(0, actualLimit - 1)) {
                        switch (queueBuffer.getOpt(0)) {
                            case (?queuedMessage) {
                                tempMessages := Array.append(tempMessages, [queuedMessage.message]);
                                ignore queueBuffer.remove(0);
                            };
                            case null {};
                        };
                    };
                    messagesToReturn := tempMessages;
                };
                
                // Update session activity
                updateSessionActivity(sessionId);
                
                Debug.print("AI Router: Returning " # debug_show(messagesToReturn.size()) # " messages for pull");
                #ok(messagesToReturn)
            };
        }
    };
    
    // Get router status
    public query func getRouterStatus() : async RouterStatus {
        let currentTime = Time.now();
        var activeSessions = 0;
        
        for ((_, sessionData) in sessionMap.entries()) {
            if (sessionData.status == #Active) {
                activeSessions += 1;
            };
        };
        
        {
            activeMessages = messageMap.size();
            queuedMessages = queueBuffer.size();
            activeSessions = activeSessions;
            totalMessagesProcessed = messageMap.size(); // Simplified
            averageResponseTime = 150.0; // Simplified - would calculate from actual data
            lastActivity = currentTime;
            systemHealth = 0.95; // Simplified health calculation
        }
    };
    
    // Configuration management
    public shared func updateConfig(newConfig : AIRouterConfig) : async Result.Result<(), Text> {
        config := newConfig;
        Debug.print("AI Router: Configuration updated");
        #ok(())
    };
    
    public query func getConfig() : async AIRouterConfig {
        config
    };
    
    // Session management
    public shared func terminateSession(sessionId : SessionId) : async Result.Result<(), Text> {
        switch (sessionMap.get(sessionId)) {
            case null {
                return #err("Session not found");
            };
            case (?sessionData) {
                let updatedSession = {
                    sessionData with
                    status = #Terminated;
                    lastActivity = Time.now();
                };
                sessionMap.put(sessionId, updatedSession);
                
                Debug.print("AI Router: Terminated session " # sessionId);
                #ok(())
            };
        }
    };
    
    // Cleanup expired sessions
    public shared func cleanupExpiredSessions() : async Nat {
        let currentTime = Time.now();
        var cleanedCount = 0;
        
        for ((sessionId, sessionData) in sessionMap.entries()) {
            let sessionTimeoutNanos = config.sessionTimeout * 1_000_000_000;
            if (sessionData.lastActivity + sessionTimeoutNanos < currentTime) {
                let expiredSession = {
                    sessionData with
                    status = #Expired;
                };
                sessionMap.put(sessionId, expiredSession);
                cleanedCount += 1;
            };
        };
        
        Debug.print("AI Router: Cleaned up " # debug_show(cleanedCount) # " expired sessions");
        cleanedCount
    };
    
    // Monitoring and diagnostics
    public query func getActiveMessages() : async [(MessageId, AIMessage)] {
        Iter.toArray(messageMap.entries())
    };
    
    public query func getQueuedMessages() : async [QueuedMessage] {
        Buffer.toArray(queueBuffer)
    };
    
    public query func getActiveSessions() : async [(SessionId, SessionData)] {
        Iter.toArray(sessionMap.entries())
    };
    
    // Helper functions
    private func checkRateLimit(sessionData : SessionData) : Bool {
        let currentTime = Time.now();
        
        // Simple rate limiting - reset counter every minute
        if (currentTime > sessionData.rateLimitReset) {
            // Reset rate limit
            let updatedSession = {
                sessionData with
                messageCount = 1;
                rateLimitReset = currentTime + 60_000_000_000;
            };
            sessionMap.put(sessionData.sessionId, updatedSession);
            true
        } else {
            // Check if under limit
            if (sessionData.messageCount < config.rateLimitPerSession) {
                let updatedSession = {
                    sessionData with
                    messageCount = sessionData.messageCount + 1;
                };
                sessionMap.put(sessionData.sessionId, updatedSession);
                true
            } else {
                false
            }
        }
    };
    
    private func updateSessionActivity(sessionId : SessionId) {
        switch (sessionMap.get(sessionId)) {
            case null {};
            case (?sessionData) {
                let updatedSession = {
                    sessionData with
                    lastActivity = Time.now();
                };
                sessionMap.put(sessionId, updatedSession);
            };
        }
    };
    
    // Health check for system monitoring
    public func healthCheck() : async {
        status : Text;
        timestamp : Int;
        messageQueueSize : Nat;
        activeSessions : Nat;
        systemLoad : Float;
    } {
        let status = if (messageMap.size() > config.maxConcurrentMessages) {
            "OVERLOADED"
        } else if (sessionMap.size() == 0) {
            "IDLE"
        } else {
            "HEALTHY"
        };
        
        var activeSessions = 0;
        for ((_, sessionData) in sessionMap.entries()) {
            if (sessionData.status == #Active) {
                activeSessions += 1;
            };
        };
        
        {
            status = status;
            timestamp = Time.now();
            messageQueueSize = queueBuffer.size();
            activeSessions = activeSessions;
            systemLoad = Float.fromInt(messageMap.size()) / Float.fromInt(config.maxConcurrentMessages);
        }
    };
}
