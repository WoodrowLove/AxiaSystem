import _Debug "mo:base/Debug";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import _HashMap "mo:base/HashMap";
import _Buffer "mo:base/Buffer";
import _Result "mo:base/Result";
import _Iter "mo:base/Iter";
import Int "mo:base/Int";

import AIEnvelope "../types/ai_envelope";

module DataLifecycleManager {
    
    type AIRequest = AIEnvelope.AIRequest;
    type AIRequestType = AIEnvelope.AIRequestType;
    type AuditEntry = AIEnvelope.AuditEntry;
    
    // Q4 Policy: Tiered Retention Strategy (functions to avoid non-static expressions)
    public func getRetentionRawRequestsNs() : Time.Time { 90 * 24 * 60 * 60 * 1000000000 }; // 90 days
    public func getRetentionSensitiveDataNs() : Time.Time { 30 * 24 * 60 * 60 * 1000000000 }; // 30 days
    public func getRetentionOperationalInsightsNs() : Time.Time { 2 * 365 * 24 * 60 * 60 * 1000000000 }; // 2 years
    public func getRetentionAuditDataNs() : Time.Time { 7 * 365 * 24 * 60 * 60 * 1000000000 }; // 7 years
    
    public type RetentionCategory = {
        #RawRequests;      // 90 days
        #SensitiveData;    // 30 days
        #OperationalInsights; // 2 years
        #AuditData;        // 7 years
    };
    
    public type RetentionRecord = {
        id: Text;
        category: RetentionCategory;
        createdAt: Time.Time;
        expiresAt: Time.Time;
        dataSize: Nat;
        encrypted: Bool;
        legalHold: Bool;
    };
    
    public type CleanupJob = {
        id: Text;
        scheduledFor: Time.Time;
        category: RetentionCategory;
        recordIds: [Text];
        status: CleanupStatus;
    };
    
    public type CleanupStatus = {
        #Scheduled;
        #Running;
        #Completed;
        #Failed: Text;
    };
    
    public type LegalHold = {
        id: Text;
        reason: Text;
        requestedBy: Text;
        createdAt: Time.Time;
        recordIds: [Text];
        active: Bool;
    };
    
    // State management functions (to be used by containing actor)
    public func createRetentionRecord(correlationId: Text, request: AIRequest) : RetentionRecord {
        let category = categorizeRequest(request);
        let now = Time.now();
        let retention = getRetentionPeriod(category);
        
        {
            id = correlationId;
            category = category;
            createdAt = now;
            expiresAt = now + retention;
            dataSize = estimateDataSize(request);
            encrypted = isEncryptionRequired(category);
            legalHold = false;
        }
    };
    
    public func createCleanupJob(correlationId: Text, category: RetentionCategory, expiresAt: Time.Time) : CleanupJob {
        let now = Time.now();
        {
            id = "cleanup-" # correlationId # "-" # Int.toText(now);
            scheduledFor = expiresAt;
            category = category;
            recordIds = [correlationId];
            status = #Scheduled;
        }
    };
    
    public func createLegalHold(recordIds: [Text], reason: Text, requestedBy: Text) : LegalHold {
        {
            id = "hold-" # Int.toText(Time.now());
            reason = reason;
            requestedBy = requestedBy;
            createdAt = Time.now();
            recordIds = recordIds;
            active = true;
        }
    };
    
    // Process scheduled cleanups (called by heartbeat)
    public func shouldCleanupJob(job: CleanupJob, now: Time.Time) : Bool {
        job.scheduledFor <= now and job.status == #Scheduled
    };
    
    public func executeCleanupJob(job: CleanupJob, isRecordUnderLegalHold: (Text) -> Bool) : CleanupJob {
        // Check if any records are under legal hold
        for (recordId in job.recordIds.vals()) {
            if (isRecordUnderLegalHold(recordId)) {
                return { job with status = #Failed("Record under legal hold: " # recordId) };
            };
        };
        
        // Job can be completed (actual deletion handled by caller)
        { job with status = #Completed }
    };
    
    // Categorization and retention logic
    public func categorizeRequest(request: AIRequest) : RetentionCategory {
        switch (request.requestType) {
            case (#FraudDetection or #ComplianceCheck) {
                #AuditData // High compliance value - 7 years
            };
            case (#PaymentRisk or #EscrowAdvisory) {
                #OperationalInsights // Business insights - 2 years
            };
            case (#PatternAnalysis or #GovernanceReview) {
                #RawRequests // Debugging data - 90 days
            };
        }
    };
    
    public func getRetentionPeriod(category: RetentionCategory) : Time.Time {
        switch (category) {
            case (#RawRequests) getRetentionRawRequestsNs();
            case (#SensitiveData) getRetentionSensitiveDataNs();
            case (#OperationalInsights) getRetentionOperationalInsightsNs();
            case (#AuditData) getRetentionAuditDataNs();
        }
    };
    
    public func isEncryptionRequired(category: RetentionCategory) : Bool {
        switch (category) {
            case (#RawRequests or #SensitiveData) true; // Always encrypted
            case (#OperationalInsights) true; // Encrypted but anonymized
            case (#AuditData) true; // Encrypted with integrity verification
        }
    };
    
    public func estimateDataSize(request: AIRequest) : Nat {
        // Rough estimation of data size in bytes
        var size = 0;
        size += Text.size(request.correlationId) * 4; // Rough UTF-8 estimation
        size += Text.size(request.idempotencyKey) * 4;
        size += Text.size(request.sessionId) * 4;
        size += Text.size(request.submitterId) * 4;
        size += Text.size(request.payload.userId) * 4;
        size += Text.size(request.payload.patternHash) * 4;
        size += request.payload.riskFactors.size() * 20; // Average risk factor size
        size += request.payload.metadata.size() * 30; // Average metadata entry size
        size += 200; // Fixed overhead
        size
    };
    
    // Right to be forgotten (GDPR Article 17)
    public func recordContainsUser(recordId: Text, userId: Text) : Bool {
        // This is a simplified check - in production, would need proper
        // correlation between record IDs and user identifiers
        Text.contains(recordId, #text userId)
    };
    
    // Compliance report generation
    public func analyzeRetentionCompliance(
        records: [(Text, RetentionRecord)], 
        now: Time.Time
    ) : {
        compliantRecords: Nat;
        expiredRecords: Nat;
        recordsUnderLegalHold: Nat;
        retentionViolations: [Text];
    } {
        var compliant = 0;
        var expired = 0;
        var underHold = 0;
        var violations: [Text] = [];
        
        for ((recordId, record) in records.vals()) {
            if (record.legalHold) {
                underHold += 1;
            } else if (now > record.expiresAt) {
                expired += 1;
                violations := Array.append(violations, ["Record " # recordId # " expired but not cleaned up"]);
            } else {
                compliant += 1;
            };
        };
        
        {
            compliantRecords = compliant;
            expiredRecords = expired;
            recordsUnderLegalHold = underHold;
            retentionViolations = violations;
        }
    };
    
    public func countScheduledCleanups(jobs: [CleanupJob], timeWindow: Time.Time) : Nat {
        var count = 0;
        for (job in jobs.vals()) {
            if (job.status == #Scheduled and job.scheduledFor <= timeWindow) {
                count += 1;
            };
        };
        count
    };
    
    public func countActiveLegalHolds(holds: [(Text, LegalHold)]) : Nat {
        var count = 0;
        for ((_, hold) in holds.vals()) {
            if (hold.active) {
                count += 1;
            };
        };
        count
    };
}
