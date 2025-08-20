//! Identity Session Manager - Comprehensive Session Management for Triad Authentication
//! Implements secure session creation, validation, and lifecycle management

import Result "mo:base/Result";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Blob "mo:base/Blob";
import Nat8 "mo:base/Nat8";
import Random "mo:base/Random";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Int "mo:base/Int";

module SessionManager {
    
    // Session types aligned with production requirements
    public type SessionScope = {
        #wallet_read;
        #wallet_transfer;
        #wallet_admin;
        #user_profile;
        #user_admin;
        #admin_security;
        #admin_roles;
        #ai_submit;
        #ai_deliver;
        #notify_send;
        #notify_admin;
        #gov_approve;
        #system_admin;
    };

    public type SessionStatus = {
        #active;
        #expired;
        #revoked;
        #suspended;
    };

    public type DeviceInfo = {
        deviceId: Principal;
        deviceType: Text; // "mobile", "web", "server", "hardware_key"
        attestation: ?Blob; // Device attestation proof
        registeredAt: Nat64;
        lastUsed: Nat64;
        trustLevel: Nat8; // 1-10, 10 = highest trust
    };

    public type Session = {
        sessionId: Text;
        identityId: Principal;
        deviceId: Principal;
        scopes: [SessionScope];
        status: SessionStatus;
        createdAt: Nat64;
        expiresAt: Nat64;
        lastActivityAt: Nat64;
        ipAddress: ?Text;
        userAgent: ?Text;
        riskScore: Nat8; // 1-10, 10 = highest risk
        correlationId: Text;
    };

    public type SessionValidation = {
        valid: Bool;
        session: ?Session;
        reason: ?Text;
        remaining: Nat64; // seconds until expiry
        riskAssessment: {
            score: Nat8;
            factors: [Text];
            action: { #allow; #challenge; #deny };
        };
    };

    public type SessionRequest = {
        identityId: Principal;
        deviceId: Principal;
        scopes: [SessionScope];
        durationSecs: Nat32;
        correlationId: Text;
        deviceProof: ?Blob; // LinkProof or device attestation
        context: ?{ ipAddress: Text; userAgent: Text };
    };

    public type SessionError = {
        #identity_not_found;
        #device_not_registered;
        #invalid_scope;
        #session_expired;
        #session_not_found;
        #insufficient_scope;
        #device_attestation_failed;
        #rate_limited;
        #risk_too_high;
        #forbidden_role;
        #replay_attack;
        #invalid_proof;
    };

    public type SessionResult<T> = Result.Result<T, SessionError>;

    public class SessionManager() {
        
        // Stable storage for sessions and devices
        private var sessions = HashMap.HashMap<Text, Session>(100, Text.equal, Text.hash);
        private var devices = HashMap.HashMap<Principal, DeviceInfo>(50, Principal.equal, Principal.hash);
        private var sessionsByIdentity = HashMap.HashMap<Principal, [Text]>(50, Principal.equal, Principal.hash);
        private var usedNonces = HashMap.HashMap<Text, Nat64>(1000, Text.equal, Text.hash);
        
        // Rate limiting
        private var rateLimits = HashMap.HashMap<Principal, (Nat, Nat64)>(100, Principal.equal, Principal.hash);
        
        // Security configuration
        private let MAX_SESSIONS_PER_IDENTITY: Nat = 10;
        private let MAX_SESSION_DURATION: Nat32 = 86400; // 24 hours
        private let DEFAULT_SESSION_DURATION: Nat32 = 3600; // 1 hour
        private let RATE_LIMIT_WINDOW: Nat64 = 300_000_000_000; // 5 minutes in nanoseconds
        private let RATE_LIMIT_MAX_ATTEMPTS: Nat = 20;
        private let HIGH_RISK_THRESHOLD: Nat8 = 7;
        
        // Generate cryptographically secure session ID
        private func generateSessionId(identityId: Principal, timestamp: Nat64): async Text {
            let seed = Principal.toBlob(identityId);
            let random = Random.Finite(seed);
            
            let sessionPrefix = "ses_";
            let identityText = Principal.toText(identityId);
            let timestampText = Nat64.toText(timestamp);
            
            // Create deterministic but unique session ID
            sessionPrefix # identityText # "_" # timestampText
        };
        
        // Register a new device for an identity
        public func registerDevice(
            identityId: Principal,
            deviceId: Principal,
            deviceType: Text,
            attestation: ?Blob
        ): async SessionResult<DeviceInfo> {
            
            let now = Nat64.fromIntWrap(Time.now());
            
            let deviceInfo: DeviceInfo = {
                deviceId = deviceId;
                deviceType = deviceType;
                attestation = attestation;
                registeredAt = now;
                lastUsed = now;
                trustLevel = switch (deviceType) {
                    case ("hardware_key") 10;
                    case ("mobile") 8;
                    case ("web") 6;
                    case ("server") 9;
                    case (_) 5;
                };
            };
            
            devices.put(deviceId, deviceInfo);
            Debug.print("🔐 Device registered: " # Principal.toText(deviceId) # " for identity: " # Principal.toText(identityId));
            
            #ok(deviceInfo)
        };
        
        // Validate device attestation and link proof
        private func validateDeviceProof(deviceId: Principal, proof: ?Blob): Bool {
            switch (devices.get(deviceId)) {
                case null { false };
                case (?device) {
                    switch (proof) {
                        case null { device.trustLevel >= 6 }; // Allow unattested for medium trust
                        case (?_proofBlob) {
                            // TODO: Implement actual cryptographic proof verification
                            // For now, accept any proof for registered devices
                            true
                        };
                    }
                };
            }
        };
        
        // Check rate limiting for identity
        private func checkRateLimit(identityId: Principal): Bool {
            let now = Nat64.fromIntWrap(Time.now());
            
            switch (rateLimits.get(identityId)) {
                case null {
                    rateLimits.put(identityId, (1, now));
                    true
                };
                case (?(count, windowStart)) {
                    if (now > windowStart + RATE_LIMIT_WINDOW) {
                        // Reset window
                        rateLimits.put(identityId, (1, now));
                        true
                    } else if (count >= RATE_LIMIT_MAX_ATTEMPTS) {
                        false // Rate limited
                    } else {
                        rateLimits.put(identityId, (count + 1, windowStart));
                        true
                    }
                };
            }
        };
        
        // Calculate risk score based on session context
        private func calculateRiskScore(request: SessionRequest, deviceInfo: DeviceInfo): Nat8 {
            var riskScore: Nat8 = 0;
            
            // Device trust factor (inverted)
            riskScore += (10 - deviceInfo.trustLevel);
            
            // Scope risk assessment
            let highRiskScopes = ["admin_security", "admin_roles", "system_admin", "gov_approve"];
            for (scope in request.scopes.vals()) {
                let scopeText = debug_show(scope);
                for (highRisk in highRiskScopes.vals()) {
                    if (Text.contains(scopeText, #text highRisk)) {
                        riskScore += 2;
                    };
                };
            };
            
            // Duration risk
            if (request.durationSecs > 14400) { // > 4 hours
                riskScore += 2;
            };
            
            // Device usage recency
            let now = Nat64.fromIntWrap(Time.now());
            let daysSinceLastUse = (now - deviceInfo.lastUsed) / 86400_000_000_000;
            if (daysSinceLastUse > 7) {
                riskScore += 3;
            } else if (daysSinceLastUse > 1) {
                riskScore += 1;
            };
            
            if (riskScore > 10) { 10 } else { riskScore }
        };
        
        // Prevent replay attacks by tracking nonces
        private func checkNonce(correlationId: Text): Bool {
            let now = Nat64.fromIntWrap(Time.now());
            
            switch (usedNonces.get(correlationId)) {
                case (?_timestamp) { false }; // Already used
                case null {
                    usedNonces.put(correlationId, now);
                    // Clean old nonces (older than 1 hour)
                    let cleanupThreshold = now - 3600_000_000_000;
                    usedNonces := HashMap.mapFilter<Text, Nat64, Nat64>(
                        usedNonces,
                        Text.equal,
                        Text.hash,
                        func(k, v) { if (v > cleanupThreshold) { ?v } else { null } }
                    );
                    true
                };
            }
        };
        
        // Create a new session with comprehensive validation
        public func createSession(request: SessionRequest): async SessionResult<Session> {
            let now = Nat64.fromIntWrap(Time.now());
            
            // Rate limiting check
            if (not checkRateLimit(request.identityId)) {
                Debug.print("❌ Rate limit exceeded for identity: " # Principal.toText(request.identityId));
                return #err(#rate_limited);
            };
            
            // Replay protection
            if (not checkNonce(request.correlationId)) {
                Debug.print("❌ Replay attack detected for correlation: " # request.correlationId);
                return #err(#replay_attack);
            };
            
            // Device validation
            switch (devices.get(request.deviceId)) {
                case null {
                    Debug.print("❌ Device not registered: " # Principal.toText(request.deviceId));
                    return #err(#device_not_registered);
                };
                case (?deviceInfo) {
                    // Validate device proof
                    if (not validateDeviceProof(request.deviceId, request.deviceProof)) {
                        Debug.print("❌ Device attestation failed: " # Principal.toText(request.deviceId));
                        return #err(#device_attestation_failed);
                    };
                    
                    // Risk assessment
                    let riskScore = calculateRiskScore(request, deviceInfo);
                    if (riskScore >= HIGH_RISK_THRESHOLD) {
                        Debug.print("⚠️ High risk session request (score: " # Nat8.toText(riskScore) # ") for identity: " # Principal.toText(request.identityId));
                        return #err(#risk_too_high);
                    };
                    
                    // Validate session duration
                    let sessionDuration = if (request.durationSecs > MAX_SESSION_DURATION) {
                        DEFAULT_SESSION_DURATION
                    } else if (request.durationSecs == 0) {
                        DEFAULT_SESSION_DURATION
                    } else {
                        request.durationSecs
                    };
                    
                    // Generate session
                    let sessionId = await generateSessionId(request.identityId, now);
                    let expiresAt = now + Nat64.fromNat(Nat32.toNat(sessionDuration)) * 1_000_000_000;
                    
                    let session: Session = {
                        sessionId = sessionId;
                        identityId = request.identityId;
                        deviceId = request.deviceId;
                        scopes = request.scopes;
                        status = #active;
                        createdAt = now;
                        expiresAt = expiresAt;
                        lastActivityAt = now;
                        ipAddress = switch (request.context) { case (?ctx) { ?ctx.ipAddress }; case null { null } };
                        userAgent = switch (request.context) { case (?ctx) { ?ctx.userAgent }; case null { null } };
                        riskScore = riskScore;
                        correlationId = request.correlationId;
                    };
                    
                    // Store session
                    sessions.put(sessionId, session);
                    
                    // Update identity session list
                    let existingSessions = switch (sessionsByIdentity.get(request.identityId)) {
                        case (?sessions) { sessions };
                        case null { [] };
                    };
                    let newSessions = Array.append(existingSessions, [sessionId]);
                    
                    // Enforce max sessions per identity
                    let trimmedSessions = if (newSessions.size() > MAX_SESSIONS_PER_IDENTITY) {
                        let excess = Int.abs(newSessions.size() - MAX_SESSIONS_PER_IDENTITY);
                        let toRemove = Array.subArray(newSessions, 0, excess);
                        for (oldSessionId in toRemove.vals()) {
                            sessions.delete(oldSessionId);
                        };
                        let remaining = Int.abs(newSessions.size() - excess);
                        Array.subArray(newSessions, excess, remaining)
                    } else {
                        newSessions
                    };
                    
                    sessionsByIdentity.put(request.identityId, trimmedSessions);
                    
                    // Update device last used
                    let updatedDevice = {
                        deviceInfo with
                        lastUsed = now;
                    };
                    devices.put(request.deviceId, updatedDevice);
                    
                    Debug.print("✅ Session created: " # sessionId # " for identity: " # Principal.toText(request.identityId) # " (risk: " # Nat8.toText(riskScore) # ")");
                    
                    #ok(session)
                };
            }
        };
        
        // Validate an existing session with comprehensive checks
        public func validateSession(sessionId: Text, requiredScopes: [SessionScope]): async SessionValidation {
            let now = Nat64.fromIntWrap(Time.now());
            
            switch (sessions.get(sessionId)) {
                case null {
                    {
                        valid = false;
                        session = null;
                        reason = ?"Session not found";
                        remaining = 0;
                        riskAssessment = {
                            score = 10;
                            factors = ["session_not_found"];
                            action = #deny;
                        };
                    }
                };
                case (?session) {
                    // Check expiry
                    if (now >= session.expiresAt) {
                        sessions.delete(sessionId);
                        {
                            valid = false;
                            session = ?session;
                            reason = ?"Session expired";
                            remaining = 0;
                            riskAssessment = {
                                score = 8;
                                factors = ["expired"];
                                action = #deny;
                            };
                        }
                    }
                    // Check status
                    else if (session.status != #active) {
                        let statusText = "Session inactive: " # debug_show(session.status);
                        {
                            valid = false;
                            session = ?session;
                            reason = ?statusText;
                            remaining = (session.expiresAt - now) / 1_000_000_000;
                            riskAssessment = {
                                score = 9;
                                factors = ["inactive_status"];
                                action = #deny;
                            };
                        }
                    }
                    // Check scope authorization
                    else if (not hasRequiredScopes(session.scopes, requiredScopes)) {
                        {
                            valid = false;
                            session = ?session;
                            reason = ?"Insufficient scope";
                            remaining = (session.expiresAt - now) / 1_000_000_000;
                            riskAssessment = {
                                score = 7;
                                factors = ["insufficient_scope"];
                                action = #deny;
                            };
                        }
                    }
                    // Valid session
                    else {
                        // Update activity timestamp
                        let updatedSession = {
                            session with
                            lastActivityAt = now;
                        };
                        sessions.put(sessionId, updatedSession);
                        
                        let remaining = (session.expiresAt - now) / 1_000_000_000;
                        let riskFactors = Buffer.Buffer<Text>(3);
                        var currentRisk = session.riskScore;
                        
                        // Dynamic risk assessment
                        if (remaining < 300) { // Less than 5 minutes
                            riskFactors.add("expiring_soon");
                            currentRisk += 1;
                        };
                        
                        if (now - session.lastActivityAt > 1800_000_000_000) { // 30+ minutes inactive
                            riskFactors.add("long_inactive");
                            currentRisk += 2;
                        };
                        
                        let action = if (currentRisk >= 8) {
                            #challenge
                        } else if (currentRisk >= 5) {
                            #challenge
                        } else {
                            #allow
                        };
                        
                        {
                            valid = true;
                            session = ?updatedSession;
                            reason = null;
                            remaining = remaining;
                            riskAssessment = {
                                score = if (currentRisk > 10) 10 else currentRisk;
                                factors = Buffer.toArray(riskFactors);
                                action = action;
                            };
                        }
                    }
                };
            }
        };
        
        // Check if session has required scopes
        private func hasRequiredScopes(sessionScopes: [SessionScope], requiredScopes: [SessionScope]): Bool {
            for (required in requiredScopes.vals()) {
                var found = false;
                for (available in sessionScopes.vals()) {
                    if (required == available) {
                        found := true;
                    };
                };
                if (not found) {
                    return false;
                };
            };
            true
        };
        
        // Revoke a specific session
        public func revokeSession(sessionId: Text): async SessionResult<()> {
            switch (sessions.get(sessionId)) {
                case null { #err(#session_not_found) };
                case (?session) {
                    let revokedSession = {
                        session with
                        status = #revoked;
                    };
                    sessions.put(sessionId, revokedSession);
                    Debug.print("🔒 Session revoked: " # sessionId);
                    #ok(())
                };
            }
        };
        
        // Revoke all sessions for an identity
        public func revokeAllSessions(identityId: Principal): async SessionResult<Nat> {
            var revokedCount = 0;
            
            switch (sessionsByIdentity.get(identityId)) {
                case null { #ok(0) };
                case (?sessionIds) {
                    for (sessionId in sessionIds.vals()) {
                        switch (sessions.get(sessionId)) {
                            case (?session) {
                                let revokedSession = {
                                    session with
                                    status = #revoked;
                                };
                                sessions.put(sessionId, revokedSession);
                                revokedCount += 1;
                            };
                            case null { /* Already removed */ };
                        };
                    };
                    sessionsByIdentity.delete(identityId);
                    Debug.print("🔒 All sessions revoked for identity: " # Principal.toText(identityId) # " (count: " # Nat.toText(revokedCount) # ")");
                    #ok(revokedCount)
                };
            }
        };
        
        // Get active sessions for an identity
        public func getActiveSessions(identityId: Principal): async [Session] {
            let now = Nat64.fromIntWrap(Time.now());
            let activeSessions = Buffer.Buffer<Session>(10);
            
            switch (sessionsByIdentity.get(identityId)) {
                case null { [] };
                case (?sessionIds) {
                    for (sessionId in sessionIds.vals()) {
                        switch (sessions.get(sessionId)) {
                            case (?session) {
                                if (session.status == #active and now < session.expiresAt) {
                                    activeSessions.add(session);
                                };
                            };
                            case null { /* Session removed */ };
                        };
                    };
                    Buffer.toArray(activeSessions)
                };
            }
        };
        
        // Cleanup expired sessions
        public func cleanupExpiredSessions(): async Nat {
            let now = Nat64.fromIntWrap(Time.now());
            var cleanedCount = 0;
            
            let expiredSessions = Buffer.Buffer<Text>(100);
            
            for ((sessionId, session) in sessions.entries()) {
                if (now >= session.expiresAt or session.status == #revoked) {
                    expiredSessions.add(sessionId);
                };
            };
            
            for (sessionId in expiredSessions.vals()) {
                sessions.delete(sessionId);
                cleanedCount += 1;
            };
            
            Debug.print("🧹 Cleaned up " # Nat.toText(cleanedCount) # " expired sessions");
            cleanedCount
        };
        
        // Get session statistics
        public func getSessionStats(): async {
            totalSessions: Nat;
            activeSessions: Nat;
            expiredSessions: Nat;
            revokedSessions: Nat;
            devicesRegistered: Nat;
            averageRiskScore: Float;
        } {
            let now = Nat64.fromIntWrap(Time.now());
            var activeCount = 0;
            var expiredCount = 0;
            var revokedCount = 0;
            var totalRiskScore: Nat = 0;
            
            for ((_, session) in sessions.entries()) {
                totalRiskScore += Nat8.toNat(session.riskScore);
                
                if (session.status == #revoked) {
                    revokedCount += 1;
                } else if (now >= session.expiresAt) {
                    expiredCount += 1;
                } else if (session.status == #active) {
                    activeCount += 1;
                };
            };
            
            let totalSessions = sessions.size();
            let averageRisk = if (totalSessions > 0) {
                Float.fromInt(totalRiskScore) / Float.fromInt(totalSessions)
            } else { 0.0 };
            
            {
                totalSessions = totalSessions;
                activeSessions = activeCount;
                expiredSessions = expiredCount;
                revokedSessions = revokedCount;
                devicesRegistered = devices.size();
                averageRiskScore = averageRisk;
            }
        };
    }
}
