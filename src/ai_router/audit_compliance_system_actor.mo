import Debug "mo:base/Debug";
import Time "mo:base/Time";
import _Timer "mo:base/Timer";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Bool "mo:base/Bool";
import Float "mo:base/Float";

import AuditRetentionManager "audit_retention_manager";

// Week 11: Audit & Retention Compliance System Actor
// Implements automated purge, legal hold, and right-to-be-forgotten capabilities
persistent actor AuditComplianceSystem {
    
    type AuditRecord = AuditRetentionManager.AuditRecord;
    type LegalHoldRequest = AuditRetentionManager.LegalHoldRequest;
    type RTBFRequest = AuditRetentionManager.RTBFRequest;
    type PurgeResult = AuditRetentionManager.PurgeResult;
    type DataClass = AuditRetentionManager.DataClass;
    type LegalHoldStatus = AuditRetentionManager.LegalHoldStatus;
    type RetentionPolicy = AuditRetentionManager.RetentionPolicy;
    
    public type ComplianceConfig = {
        autoRetentionEnabled : Bool;
        legalHoldNotifications : Bool;
        rtbfProcessingEnabled : Bool;
        quarterlyAuditEnabled : Bool;
        purgeGracePeriodDays : Nat;
        maxRtbfProcessingDays : Nat;
    };
    
    private let defaultComplianceConfig : ComplianceConfig = {
        autoRetentionEnabled = true;
        legalHoldNotifications = true;
        rtbfProcessingEnabled = true;
        quarterlyAuditEnabled = true;
        purgeGracePeriodDays = 30;
        maxRtbfProcessingDays = 30;
    };
    
    // Week 11: Stable storage for audit and compliance data
    private var auditRecords : [(Text, AuditRecord)] = [];
    private var legalHolds : [(Text, LegalHoldRequest)] = [];
    private var rtbfRequests : [(Text, RTBFRequest)] = [];
    private var retentionPolicies : [(Text, RetentionPolicy)] = [];
    private var lastAuditDate : Int = 0;
    private var complianceConfig : ComplianceConfig = defaultComplianceConfig;
    
    // Week 11: Runtime state (transient)
    private transient var auditMap = HashMap.fromIter<Text, AuditRecord>(auditRecords.vals(), 100, Text.equal, Text.hash);
    private transient var legalHoldMap = HashMap.fromIter<Text, LegalHoldRequest>(legalHolds.vals(), 10, Text.equal, Text.hash);
    private transient var rtbfMap = HashMap.fromIter<Text, RTBFRequest>(rtbfRequests.vals(), 10, Text.equal, Text.hash);
    private transient var policyMap = HashMap.fromIter<Text, RetentionPolicy>(retentionPolicies.vals(), 10, Text.equal, Text.hash);
    
    public type ComplianceStatus = {
        systemStatus : { #Compliant; #NonCompliant : [Text] };
        lastAuditDate : Int;
        nextAuditDue : Int;
        retentionCompliance : Float;
        legalHoldCompliance : Bool;
        rtbfCompliance : Bool;
        pendingActions : Nat;
    };
    
    // Week 11: System lifecycle management
    system func preupgrade() {
        auditRecords := Iter.toArray(auditMap.entries());
        legalHolds := Iter.toArray(legalHoldMap.entries());
        rtbfRequests := Iter.toArray(rtbfMap.entries());
        retentionPolicies := Iter.toArray(policyMap.entries());
    };
    
    system func postupgrade() {
        auditRecords := [];
        legalHolds := [];
        rtbfRequests := [];
        retentionPolicies := [];
    };
    
    // Week 11: Initialize compliance system
    public func initializeComplianceSystem() : async Result.Result<Text, Text> {
        // Set up default retention policies
        let auditPolicy : RetentionPolicy = {
            policyId = "audit_7y";
            dataClass = #Audit({ ttlDays = 2555 }); // 7 years
            autoApply = true;
            gracePeriodDays = 30;
            requiresApproval = false;
            notificationRules = [{
                daysBeforeExpiry = 30;
                notifyRoles = ["compliance", "legal"];
                escalationRequired = true;
            }];
        };
        
        let operationalPolicy : RetentionPolicy = {
            policyId = "operational_90d";
            dataClass = #Operational({ ttlDays = 90 });
            autoApply = true;
            gracePeriodDays = 7;
            requiresApproval = false;
            notificationRules = [{
                daysBeforeExpiry = 7;
                notifyRoles = ["operations"];
                escalationRequired = false;
            }];
        };
        
        let insightsPolicy : RetentionPolicy = {
            policyId = "insights_2y";
            dataClass = #Insights({ ttlDays = 730 }); // 2 years
            autoApply = true;
            gracePeriodDays = 14;
            requiresApproval = false;
            notificationRules = [{
                daysBeforeExpiry = 14;
                notifyRoles = ["analytics"];
                escalationRequired = false;
            }];
        };
        
        let sensitivePolicy : RetentionPolicy = {
            policyId = "sensitive_30d";
            dataClass = #Sensitive({ ttlDays = 30 });
            autoApply = true;
            gracePeriodDays = 3;
            requiresApproval = true;
            notificationRules = [{
                daysBeforeExpiry = 3;
                notifyRoles = ["security", "compliance"];
                escalationRequired = true;
            }];
        };
        
        policyMap.put("audit_7y", auditPolicy);
        policyMap.put("operational_90d", operationalPolicy);
        policyMap.put("insights_2y", insightsPolicy);
        policyMap.put("sensitive_30d", sensitivePolicy);
        
        lastAuditDate := Time.now();
        
        Debug.print("Week 11: Compliance system initialized with " # debug_show(policyMap.size()) # " retention policies");
        
        #ok("Compliance system initialized successfully")
    };
    
    // Week 11: Apply legal hold to records
    public func applyLegalHold(holdRequest : LegalHoldRequest) : async Result.Result<Text, Text> {
        // Validate hold request
        if (holdRequest.subjectIds.size() == 0) {
            return #err("Legal hold must specify at least one subject ID");
        };
        
        if (holdRequest.reason == "") {
            return #err("Legal hold must include a reason");
        };
        
        // Check if hold already exists
        switch (legalHoldMap.get(holdRequest.holdId)) {
            case (?_existingHold) {
                return #err("Legal hold with ID " # holdRequest.holdId # " already exists");
            };
            case null {};
        };
        
        // Find affected records
        var affectedRecords : [AuditRecord] = [];
        for ((recordId, record) in auditMap.entries()) {
            // Check if record matches any subject ID (simplified matching)
            for (subjectId in holdRequest.subjectIds.vals()) {
                if (Text.contains(recordId, #text subjectId)) {
                    affectedRecords := Array.append(affectedRecords, [record]);
                };
            };
        };
        
        // Apply legal hold to affected records
        let updatedRecords = AuditRetentionManager.applyLegalHold(affectedRecords, holdRequest);
        
        // Update storage
        for (record in updatedRecords.vals()) {
            auditMap.put(record.recordId, record);
        };
        
        legalHoldMap.put(holdRequest.holdId, holdRequest);
        
        Debug.print("Week 11: Legal hold " # holdRequest.holdId # " applied to " # debug_show(updatedRecords.size()) # " records");
        
        #ok("Legal hold applied to " # debug_show(updatedRecords.size()) # " records")
    };
    
    // Week 11: Release legal hold
    public func releaseLegalHold(holdId : Text, releasedBy : Text, reason : Text) : async Result.Result<Text, Text> {
        switch (legalHoldMap.get(holdId)) {
            case null {
                return #err("Legal hold not found: " # holdId);
            };
            case (?_holdRequest) {
                var releasedCount = 0;
                
                // Find and release records under this hold
                for ((recordId, record) in auditMap.entries()) {
                    switch (record.legalHold) {
                        case (#Active(hold)) {
                            if (hold.holdId == holdId) {
                                let updatedRecord = AuditRetentionManager.releaseLegalHold(record, releasedBy, reason);
                                auditMap.put(recordId, updatedRecord);
                                releasedCount += 1;
                            };
                        };
                        case (_) {};
                    };
                };
                
                // Remove hold from tracking
                legalHoldMap.delete(holdId);
                
                Debug.print("Week 11: Legal hold " # holdId # " released from " # debug_show(releasedCount) # " records");
                
                #ok("Legal hold released from " # debug_show(releasedCount) # " records")
            };
        }
    };
    
    // Week 11: Process Right-to-be-Forgotten request
    public func processRTBFRequest(request : RTBFRequest) : async Result.Result<Text, Text> {
        if (not complianceConfig.rtbfProcessingEnabled) {
            return #err("RTBF processing is currently disabled");
        };
        
        // Check for existing request
        switch (rtbfMap.get(request.requestId)) {
            case (?_existingRequest) {
                return #err("RTBF request with ID " # request.requestId # " already exists");
            };
            case null {};
        };
        
        // Get all audit records for processing
        let allRecords = Iter.toArray(auditMap.vals());
        
        // Process RTBF request
        let result = AuditRetentionManager.processRTBFRequest(request, allRecords);
        
        // Update records that were purged
        for (recordId in result.purgedRecords.vals()) {
            auditMap.delete(recordId);
        };
        
        // Store updated request
        rtbfMap.put(request.requestId, result.updatedRequest);
        
        Debug.print("Week 11: RTBF request " # request.requestId # " processed: " # 
                   debug_show(result.purgedRecords.size()) # " purged, " # 
                   debug_show(result.blockedRecords.size()) # " blocked");
        
        #ok("RTBF processed: " # debug_show(result.purgedRecords.size()) # " records purged")
    };
    
    // Week 11: Perform automated retention purge
    public func performAutomatedPurge() : async PurgeResult {
        let allRecords = Iter.toArray(auditMap.vals());
        let purgeResult = AuditRetentionManager.performAutomatedPurge(allRecords);
        
        // Remove purged records from storage
        for ((recordId, record) in auditMap.entries()) {
            if (AuditRetentionManager.isEligibleForPurge(record)) {
                auditMap.delete(recordId);
            };
        };
        
        Debug.print("Week 11: Automated purge completed: " # 
                   debug_show(purgeResult.recordsPurged) # " purged, " # 
                   debug_show(purgeResult.recordsRetained) # " retained");
        
        purgeResult
    };
    
    // Week 11: Generate quarterly compliance audit
    public func performQuarterlyAudit() : async {
        auditId : Text;
        auditDate : Int;
        totalRecords : Nat;
        complianceRate : Float;
        retentionCompliance : Bool;
        legalHoldCompliance : Bool;
        rtbfCompliance : Bool;
        integrityScore : Float;
        findings : [AuditRetentionManager.AuditFinding];
        recommendations : [Text];
        reportText : Text;
    } {
        let allRecords = Iter.toArray(auditMap.vals());
        let auditResults = AuditRetentionManager.performQuarterlyAudit(allRecords);
        let reportText = AuditRetentionManager.generateComplianceReport(auditResults);
        
        lastAuditDate := auditResults.auditDate;
        
        Debug.print("Week 11: Quarterly audit completed with " # 
                   debug_show(auditResults.complianceRate * 100.0) # "% compliance rate");
        
        {
            auditId = auditResults.auditId;
            auditDate = auditResults.auditDate;
            totalRecords = auditResults.totalRecords;
            complianceRate = auditResults.complianceRate;
            retentionCompliance = auditResults.retentionCompliance;
            legalHoldCompliance = auditResults.legalHoldCompliance;
            rtbfCompliance = auditResults.rtbfCompliance;
            integrityScore = auditResults.integrityScore;
            findings = auditResults.findings;
            recommendations = auditResults.recommendations;
            reportText = reportText;
        }
    };
    
    // Week 11: Get current compliance status
    public query func getComplianceStatus() : async ComplianceStatus {
        let currentTime = Time.now();
        let quarterlyInterval = 90 * 24 * 60 * 60 * 1_000_000_000; // 90 days in nanoseconds
        let nextAuditDue = lastAuditDate + quarterlyInterval;
        
        // Calculate retention compliance
        let allRecords = Iter.toArray(auditMap.vals());
        var compliantRecords = 0;
        var pendingActions = 0;
        
        for (record in allRecords.vals()) {
            if (currentTime <= record.retentionUntil or 
                (switch (record.legalHold) { case (#Active(_)) true; case (_) false; })) {
                compliantRecords += 1;
            } else {
                pendingActions += 1;
            };
        };
        
        let retentionCompliance = if (allRecords.size() > 0) {
            Float.fromInt(compliantRecords) / Float.fromInt(allRecords.size())
        } else { 1.0 };
        
        // Check for non-compliance issues
        var issues : [Text] = [];
        if (retentionCompliance < 0.95) {
            issues := Array.append(issues, ["Retention compliance below 95%"]);
        };
        if (currentTime > nextAuditDue) {
            issues := Array.append(issues, ["Quarterly audit overdue"]);
        };
        if (pendingActions > 10) {
            issues := Array.append(issues, ["Too many pending retention actions"]);
        };
        
        let systemStatus = if (issues.size() == 0) #Compliant else #NonCompliant(issues);
        
        {
            systemStatus = systemStatus;
            lastAuditDate = lastAuditDate;
            nextAuditDue = nextAuditDue;
            retentionCompliance = retentionCompliance;
            legalHoldCompliance = true; // Simplified for now
            rtbfCompliance = true; // Simplified for now
            pendingActions = pendingActions;
        }
    };
    
    // Week 11: Configuration management
    public func updateComplianceConfig(newConfig : ComplianceConfig) : async Result.Result<(), Text> {
        complianceConfig := newConfig;
        
        Debug.print("Week 11: Compliance configuration updated");
        #ok(())
    };
    
    public query func getComplianceConfig() : async ComplianceConfig {
        complianceConfig
    };
    
    // Week 11: Query functions for monitoring
    public query func getLegalHolds() : async [(Text, LegalHoldRequest)] {
        Iter.toArray(legalHoldMap.entries())
    };
    
    public query func getRTBFRequests() : async [(Text, RTBFRequest)] {
        Iter.toArray(rtbfMap.entries())
    };
    
    public query func getRetentionPolicies() : async [(Text, RetentionPolicy)] {
        Iter.toArray(policyMap.entries())
    };
    
    public query func getAuditRecordCount() : async Nat {
        auditMap.size()
    };
    
    // Week 11: Test data creation for validation
    public func createTestAuditRecord(recordId : Text, dataClass : DataClass) : async Result.Result<(), Text> {
        let testRecord : AuditRecord = {
            recordId = recordId;
            dataClass = dataClass;
            createdAt = Time.now();
            lastAccessed = ?Time.now();
            retentionUntil = AuditRetentionManager.calculateRetentionPeriod(dataClass);
            legalHold = #None;
            rtbfEligible = true;
            auditTrail = [{
                eventId = "create_" # recordId;
                timestamp = Time.now();
                eventType = #DataCreated;
                actorId = "system";
                details = "Test record created";
                integrityCheck = true;
            }];
            integrityHash = "test_hash_" # recordId;
        };
        
        auditMap.put(recordId, testRecord);
        
        Debug.print("Week 11: Created test audit record: " # recordId);
        #ok(())
    };
}
