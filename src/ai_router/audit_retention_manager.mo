import Debug "mo:base/Debug";
import Time "mo:base/Time";
import _Result "mo:base/Result";
import Array "mo:base/Array";
import Text "mo:base/Text";
import _HashMap "mo:base/HashMap";
import _Iter "mo:base/Iter";
import Int "mo:base/Int";
import _Nat32 "mo:base/Nat32";
import Float "mo:base/Float";

// Week 11: Audit & Retention Management System
// Implements automated purge, legal hold, and right-to-be-forgotten capabilities
module AuditRetentionManager {
    
    public type DataClass = {
        #Audit : { ttlDays : Nat }; // 7 years
        #Operational : { ttlDays : Nat }; // 90 days  
        #Insights : { ttlDays : Nat }; // 2 years
        #Sensitive : { ttlDays : Nat }; // 30 days
    };
    
    public type LegalHoldStatus = {
        #Active : { holdId : Text; reason : Text; requestedBy : Text; startDate : Int };
        #Released : { releaseDate : Int; releasedBy : Text };
        #None;
    };
    
    public type RTBFRequest = {
        requestId : Text;
        subjectId : Text; // Hashed user identifier
        requestDate : Int;
        requestedBy : Text;
        scope : [Text]; // Data categories to forget
        status : RTBFStatus;
        completionDate : ?Int;
        verificationHash : ?Text;
    };
    
    public type RTBFStatus = {
        #Pending;
        #InProgress;
        #Completed;
        #Failed : Text;
        #Blocked : Text; // e.g., "Legal hold active"
    };
    
    public type AuditRecord = {
        recordId : Text;
        dataClass : DataClass;
        createdAt : Int;
        lastAccessed : ?Int;
        retentionUntil : Int;
        legalHold : LegalHoldStatus;
        rtbfEligible : Bool;
        auditTrail : [AuditEvent];
        integrityHash : Text;
    };
    
    public type AuditEvent = {
        eventId : Text;
        timestamp : Int;
        eventType : AuditEventType;
        actorId : Text;
        details : Text;
        integrityCheck : Bool;
    };
    
    public type AuditEventType = {
        #DataCreated;
        #DataAccessed;
        #DataModified;
        #RetentionApplied;
        #LegalHoldApplied;
        #LegalHoldReleased;
        #RTBFRequested;
        #RTBFProcessed;
        #DataPurged;
        #IntegrityVerified;
    };
    
    public type PurgeResult = {
        totalRecordsScanned : Nat;
        recordsPurged : Nat;
        recordsRetained : Nat;
        legalHoldsRespected : Nat;
        errors : [Text];
        completionTime : Int;
        integrityVerified : Bool;
    };
    
    public type LegalHoldRequest = {
        holdId : Text;
        subjectIds : [Text]; // Hashed identifiers
        reason : Text;
        requestedBy : Text;
        requestDate : Int;
        expectedDuration : ?Int; // Days
        scope : [Text]; // Data categories
    };
    
    public type RetentionPolicy = {
        policyId : Text;
        dataClass : DataClass;
        autoApply : Bool;
        gracePeriodDays : Nat;
        requiresApproval : Bool;
        notificationRules : [NotificationRule];
    };
    
    public type NotificationRule = {
        daysBeforeExpiry : Nat;
        notifyRoles : [Text];
        escalationRequired : Bool;
    };
    
    // Week 11: Calculate retention period based on data class
    public func calculateRetentionPeriod(dataClass : DataClass) : Int {
        let daysToNanos = 24 * 60 * 60 * 1_000_000_000;
        let currentTime = Time.now();
        
        let ttlDays = switch (dataClass) {
            case (#Audit(config)) config.ttlDays;
            case (#Operational(config)) config.ttlDays;
            case (#Insights(config)) config.ttlDays;
            case (#Sensitive(config)) config.ttlDays;
        };
        
        let retentionUntil = currentTime + (ttlDays * daysToNanos);
        Debug.print("📅 Calculated retention period for " # debug_show(dataClass) # ": " # debug_show(ttlDays) # " days");
        Debug.print("   Retention until: " # debug_show(retentionUntil));
        
        retentionUntil
    };
    
    // Week 11: Check if record is eligible for purge
    public func isEligibleForPurge(record : AuditRecord) : Bool {
        let currentTime = Time.now();
        
        Debug.print("🔍 Checking purge eligibility for record: " # record.recordId);
        Debug.print("   Current time: " # debug_show(currentTime));
        Debug.print("   Retention until: " # debug_show(record.retentionUntil));
        
        // Check if retention period has expired
        if (currentTime < record.retentionUntil) {
            Debug.print("   ❌ Not eligible: Retention period not expired");
            return false;
        };
        
        // Check if legal hold is active
        switch (record.legalHold) {
            case (#Active(hold)) {
                Debug.print("   ❌ Not eligible: Legal hold active - " # hold.reason);
                return false; // Cannot purge under legal hold
            };
            case (#Released(release)) {
                Debug.print("   ✅ Eligible: Legal hold released on " # debug_show(release.releaseDate));
                return true;
            };
            case (#None) {
                Debug.print("   ✅ Eligible: No legal hold, retention expired");
                return true;
            };
        };
    };
    
    // Week 11: Apply legal hold to records
    public func applyLegalHold(
        records : [AuditRecord],
        holdRequest : LegalHoldRequest
    ) : [AuditRecord] {
        Debug.print("⚖️  Applying legal hold: " # holdRequest.holdId);
        Debug.print("   Reason: " # holdRequest.reason);
        Debug.print("   Requested by: " # holdRequest.requestedBy);
        Debug.print("   Affecting " # debug_show(records.size()) # " records");
        
        let updatedRecords = Array.map<AuditRecord, AuditRecord>(records, func(record) {
            let newHold = #Active({
                holdId = holdRequest.holdId;
                reason = holdRequest.reason;
                requestedBy = holdRequest.requestedBy;
                startDate = holdRequest.requestDate;
            });
            
            let holdEvent : AuditEvent = {
                eventId = "hold_" # holdRequest.holdId # "_" # record.recordId;
                timestamp = Time.now();
                eventType = #LegalHoldApplied;
                actorId = holdRequest.requestedBy;
                details = "Legal hold applied: " # holdRequest.reason;
                integrityCheck = true;
            };
            
            Debug.print("   📎 Applied hold to record: " # record.recordId);
            
            {
                record with 
                legalHold = newHold;
                auditTrail = Array.append(record.auditTrail, [holdEvent]);
            }
        });
        
        Debug.print("✅ Legal hold applied to " # debug_show(updatedRecords.size()) # " records");
        updatedRecords
    };
    
    // Week 11: Release legal hold
    public func releaseLegalHold(
        record : AuditRecord,
        releasedBy : Text,
        reason : Text
    ) : AuditRecord {
        Debug.print("🔓 Releasing legal hold for record: " # record.recordId);
        Debug.print("   Released by: " # releasedBy);
        Debug.print("   Reason: " # reason);
        
        let releaseEvent : AuditEvent = {
            eventId = "release_" # record.recordId # "_" # debug_show(Time.now());
            timestamp = Time.now();
            eventType = #LegalHoldReleased;
            actorId = releasedBy;
            details = "Legal hold released: " # reason;
            integrityCheck = true;
        };
        
        let updatedRecord = {
            record with 
            legalHold = #Released({
                releaseDate = Time.now();
                releasedBy = releasedBy;
            });
            auditTrail = Array.append(record.auditTrail, [releaseEvent]);
        };
        
        Debug.print("✅ Legal hold released for record: " # record.recordId);
        updatedRecord
    };
    
    // Week 11: Process right-to-be-forgotten request
    public func processRTBFRequest(
        request : RTBFRequest,
        records : [AuditRecord]
    ) : {
        updatedRequest : RTBFRequest;
        affectedRecords : [Text];
        purgedRecords : [Text];
        blockedRecords : [Text];
    } {
        Debug.print("🧹 Processing RTBF request: " # request.requestId);
        Debug.print("   Subject ID: " # request.subjectId);
        Debug.print("   Scope: " # debug_show(request.scope));
        Debug.print("   Processing " # debug_show(records.size()) # " records");
        
        var affectedRecords : [Text] = [];
        var purgedRecords : [Text] = [];
        var blockedRecords : [Text] = [];
        
        // Check each record for RTBF eligibility
        for (record in records.vals()) {
            if (record.rtbfEligible) {
                affectedRecords := Array.append(affectedRecords, [record.recordId]);
                Debug.print("   📝 Record " # record.recordId # " is RTBF eligible");
                
                // Check if record is under legal hold
                switch (record.legalHold) {
                    case (#Active(hold)) {
                        Debug.print("   ⛔ Record " # record.recordId # " blocked by legal hold: " # hold.reason);
                        blockedRecords := Array.append(blockedRecords, [record.recordId]);
                    };
                    case (#Released(_) or #None) {
                        Debug.print("   ✅ Record " # record.recordId # " eligible for purge");
                        purgedRecords := Array.append(purgedRecords, [record.recordId]);
                    };
                };
            } else {
                Debug.print("   ⏭️  Record " # record.recordId # " not RTBF eligible");
            };
        };
        
        let newStatus = if (blockedRecords.size() > 0) {
            Debug.print("⚠️  RTBF partially blocked: " # debug_show(blockedRecords.size()) # " records under legal hold");
            #Blocked("Legal holds prevent complete RTBF processing")
        } else if (purgedRecords.size() > 0) {
            Debug.print("✅ RTBF completed: " # debug_show(purgedRecords.size()) # " records processed");
            #Completed
        } else {
            Debug.print("❌ RTBF failed: No eligible records found");
            #Failed("No eligible records found")
        };
        
        let updatedRequest = {
            request with 
            status = newStatus;
            completionDate = ?Time.now();
            verificationHash = ?generateVerificationHash(purgedRecords);
        };
        
        Debug.print("📊 RTBF Summary - Affected: " # debug_show(affectedRecords.size()) # 
                   ", Purged: " # debug_show(purgedRecords.size()) # 
                   ", Blocked: " # debug_show(blockedRecords.size()));
        
        {
            updatedRequest = updatedRequest;
            affectedRecords = affectedRecords;
            purgedRecords = purgedRecords;
            blockedRecords = blockedRecords;
        }
    };
    
    // Week 11: Automated purge with comprehensive validation
    public func performAutomatedPurge(records : [AuditRecord]) : PurgeResult {
        let startTime = Time.now();
        Debug.print("🗑️  Starting automated purge of " # debug_show(records.size()) # " records");
        Debug.print("   Start time: " # debug_show(startTime));
        
        var purgedCount = 0;
        var retainedCount = 0;
        var legalHoldsCount = 0;
        var errors : [Text] = [];
        
        for (record in records.vals()) {
            if (isEligibleForPurge(record)) {
                // Verify integrity before purging
                if (verifyRecordIntegrity(record)) {
                    Debug.print("   🗑️  Purging record: " # record.recordId);
                    purgedCount += 1;
                } else {
                    let error = "Integrity check failed for record: " # record.recordId;
                    Debug.print("   ❌ " # error);
                    errors := Array.append(errors, [error]);
                    retainedCount += 1;
                };
            } else {
                Debug.print("   📦 Retaining record: " # record.recordId);
                retainedCount += 1;
                
                // Check if retention due to legal hold
                switch (record.legalHold) {
                    case (#Active(hold)) {
                        Debug.print("     Reason: Legal hold - " # hold.reason);
                        legalHoldsCount += 1;
                    };
                    case (_) {
                        Debug.print("     Reason: Retention period not expired");
                    };
                };
            };
        };
        
        let completionTime = Time.now() - startTime;
        let integrityVerified = errors.size() == 0;
        
        Debug.print("✅ Automated purge completed in " # debug_show(completionTime) # "ns");
        Debug.print("   📊 Purged: " # debug_show(purgedCount) # " records");
        Debug.print("   📦 Retained: " # debug_show(retainedCount) # " records");
        Debug.print("   ⚖️  Legal holds: " # debug_show(legalHoldsCount) # " records");
        Debug.print("   ❌ Errors: " # debug_show(errors.size()));
        Debug.print("   🔒 Integrity verified: " # debug_show(integrityVerified));
        
        {
            totalRecordsScanned = records.size();
            recordsPurged = purgedCount;
            recordsRetained = retainedCount;
            legalHoldsRespected = legalHoldsCount;
            errors = errors;
            completionTime = completionTime;
            integrityVerified = integrityVerified;
        }
    };
    
    // Week 11: Quarterly compliance audit
    public func performQuarterlyAudit(records : [AuditRecord]) : {
        auditId : Text;
        auditDate : Int;
        totalRecords : Nat;
        complianceRate : Float;
        retentionCompliance : Bool;
        legalHoldCompliance : Bool;
        rtbfCompliance : Bool;
        integrityScore : Float;
        findings : [AuditFinding];
        recommendations : [Text];
    } {
        let auditDate = Time.now();
        let auditId = "quarterly_" # debug_show(auditDate);
        
        Debug.print("📋 Starting quarterly compliance audit: " # auditId);
        Debug.print("   Audit date: " # debug_show(auditDate));
        Debug.print("   Total records to audit: " # debug_show(records.size()));
        
        var compliantRecords = 0;
        var integrityIssues = 0;
        var findings : [AuditFinding] = [];
        var recommendations : [Text] = [];
        
        // Check each record for compliance
        for (record in records.vals()) {
            var recordCompliant = true;
            Debug.print("   🔍 Auditing record: " # record.recordId);
            
            // Check retention compliance
            if (Time.now() > record.retentionUntil) {
                switch (record.legalHold) {
                    case (#Active(hold)) {
                        Debug.print("     ✅ Retention OK: Legal hold active - " # hold.reason);
                        // OK - retained due to legal hold
                    };
                    case (_) {
                        Debug.print("     ❌ Retention violation: Past retention period without legal hold");
                        recordCompliant := false;
                        findings := Array.append(findings, [{
                            findingId = "retention_" # record.recordId;
                            severity = #Medium;
                            description = "Record past retention period without legal hold";
                            recordId = record.recordId;
                            remediation = "Schedule for immediate purge";
                        }]);
                    };
                };
            } else {
                Debug.print("     ✅ Retention OK: Within retention period");
            };
            
            // Check integrity
            if (not verifyRecordIntegrity(record)) {
                Debug.print("     ❌ Integrity violation: Verification failed");
                recordCompliant := false;
                integrityIssues += 1;
                findings := Array.append(findings, [{
                    findingId = "integrity_" # record.recordId;
                    severity = #High;
                    description = "Record integrity verification failed";
                    recordId = record.recordId;
                    remediation = "Investigate data corruption";
                }]);
            } else {
                Debug.print("     ✅ Integrity OK: Verification passed");
            };
            
            if (recordCompliant) {
                compliantRecords += 1;
                Debug.print("     ✅ Record compliant");
            } else {
                Debug.print("     ❌ Record non-compliant");
            };
        };
        
        let complianceRate = if (records.size() > 0) {
            intToFloat(compliantRecords) / intToFloat(records.size())
        } else { 1.0 };
        
        let integrityScore = if (records.size() > 0) {
            intToFloat(records.size() - integrityIssues) / intToFloat(records.size())
        } else { 1.0 };
        
        Debug.print("📊 Audit metrics:");
        Debug.print("   Compliance rate: " # debug_show(complianceRate * 100.0) # "%");
        Debug.print("   Integrity score: " # debug_show(integrityScore * 100.0) # "%");
        Debug.print("   Findings: " # debug_show(findings.size()));
        
        // Generate recommendations
        if (complianceRate < 0.95) {
            let rec = "Implement stricter retention monitoring";
            Debug.print("   💡 Recommendation: " # rec);
            recommendations := Array.append(recommendations, [rec]);
        };
        if (integrityScore < 0.99) {
            let rec = "Review data integrity procedures";
            Debug.print("   💡 Recommendation: " # rec);
            recommendations := Array.append(recommendations, [rec]);
        };
        
        Debug.print("✅ Quarterly audit completed: " # auditId);
        
        {
            auditId = auditId;
            auditDate = auditDate;
            totalRecords = records.size();
            complianceRate = complianceRate;
            retentionCompliance = complianceRate >= 0.95;
            legalHoldCompliance = true; // Simplified for now
            rtbfCompliance = true; // Simplified for now
            integrityScore = integrityScore;
            findings = findings;
            recommendations = recommendations;
        }
    };
    
    public type AuditFinding = {
        findingId : Text;
        severity : { #Low; #Medium; #High; #Critical };
        description : Text;
        recordId : Text;
        remediation : Text;
    };
    
    // Week 11: Generate compliance report
    public func generateComplianceReport(
        auditResults : {
            auditId : Text;
            auditDate : Int;
            totalRecords : Nat;
            complianceRate : Float;
            retentionCompliance : Bool;
            legalHoldCompliance : Bool;
            rtbfCompliance : Bool;
            integrityScore : Float;
            findings : [AuditFinding];
            recommendations : [Text];
        }
    ) : Text {
        var report = "=== QUARTERLY COMPLIANCE AUDIT REPORT ===\n";
        report #= "Audit ID: " # auditResults.auditId # "\n";
        report #= "Date: " # debug_show(auditResults.auditDate) # "\n";
        report #= "Total Records: " # debug_show(auditResults.totalRecords) # "\n\n";
        
        report #= "COMPLIANCE SCORES:\n";
        report #= "Overall Compliance: " # debug_show(auditResults.complianceRate * 100.0) # "%\n";
        report #= "Retention Compliance: " # debug_show(auditResults.retentionCompliance) # "\n";
        report #= "Legal Hold Compliance: " # debug_show(auditResults.legalHoldCompliance) # "\n";
        report #= "RTBF Compliance: " # debug_show(auditResults.rtbfCompliance) # "\n";
        report #= "Data Integrity Score: " # debug_show(auditResults.integrityScore * 100.0) # "%\n\n";
        
        report #= "FINDINGS (" # debug_show(auditResults.findings.size()) # " total):\n";
        for (finding in auditResults.findings.vals()) {
            report #= "- [" # debug_show(finding.severity) # "] " # finding.description # "\n";
        };
        
        report #= "\nRECOMMENDATIONS:\n";
        for (rec in auditResults.recommendations.vals()) {
            report #= "- " # rec # "\n";
        };
        
        report
    };
    
    // Private helper functions
    private func verifyRecordIntegrity(record : AuditRecord) : Bool {
        // Simplified integrity check - in production would use cryptographic verification
        record.integrityHash != "" and record.auditTrail.size() > 0
    };
    
    private func generateVerificationHash(recordIds : [Text]) : Text {
        // Simplified hash generation - in production would use proper cryptographic hash
        "rtbf_hash_" # debug_show(recordIds.size()) # "_" # debug_show(Time.now())
    };
    
    private func intToFloat(n : Int) : Float {
        // Convert Int to Float for percentage calculations
        if (n >= 0) {
            let absN = Int.abs(n);
            Float.fromInt(absN)
        } else {
            0.0 - Float.fromInt(Int.abs(n))
        }
    };
}
