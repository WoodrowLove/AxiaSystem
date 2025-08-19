import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import _Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import _Option "mo:base/Option";

import SecureTransport "./secure_transport";
import KeyRotation "./key_rotation";
import BatchProcessor "./batch_processor";
import ReportGenerator "../compliance/report_generator";

persistent actor PushPullCommunication {
    private transient let secureTransport = SecureTransport.SecureTransport();
    private transient let keyManager = KeyRotation.KeyRotationManager();
    private transient let batchProcessor = BatchProcessor.BatchProcessor();
    private transient let reportGenerator = ReportGenerator.ComplianceReportGenerator();
    
    private transient var isInitialized: Bool = false;
    private transient var pushMode: Bool = true; // true = push, false = pull
    private transient let systemMetrics = HashMap.HashMap<Text, Float>(50, Text.equal, Text.hash);

    // ===============================
    // INITIALIZATION & CONFIGURATION
    // ===============================

    public func initialize() : async Result.Result<Text, Text> {
        if (isInitialized) {
            return #err("System already initialized");
        };

        // Initialize default metrics
        systemMetrics.put("message_success_rate", 0.0);
        systemMetrics.put("average_latency_ms", 0.0);
        systemMetrics.put("throughput_per_second", 0.0);
        systemMetrics.put("error_rate", 0.0);

        isInitialized := true;
        #ok("Push/Pull Communication System initialized successfully")
    };

    public func switchCommunicationMode(usePush: Bool) : async Result.Result<Text, Text> {
        if (not isInitialized) {
            return #err("System not initialized");
        };

        pushMode := usePush;
        let mode = if (usePush) "push" else "pull";
        #ok("Communication mode switched to " # mode)
    };

    // ===============================
    // SECURE MESSAGING
    // ===============================

    public shared(msg) func sendSecureMessage(
        payload: Blob,
        recipient: Principal,
        messageType: SecureTransport.MessageType
    ) : async Result.Result<Text, Text> {
        if (not isInitialized) {
            return #err("System not initialized");
        };

        // Get current key version
        switch (keyManager.getCurrentKey()) {
            case (?currentKey) {
                let secureMessage = secureTransport.createSecureMessage(
                    payload,
                    recipient,
                    messageType,
                    currentKey.version,
                    msg.caller
                );

                // Validate message before sending
                switch (secureTransport.validateMessage(secureMessage, currentKey.version)) {
                    case (#Valid(_)) {
                        // Deliver message
                        switch (await secureTransport.deliverMessage(secureMessage)) {
                            case (#ok(receipt)) {
                                updateMetrics("message_sent", 1.0);
                                #ok("Message delivered: " # receipt.messageId)
                            };
                            case (#err(error)) {
                                updateMetrics("message_failed", 1.0);
                                #err("Delivery failed: " # error)
                            };
                        }
                    };
                    case (#Invalid({ reason; errorCode = _ })) {
                        #err("Message validation failed: " # reason)
                    };
                    case (#Expired({ expiredAt = _ })) {
                        #err("Message expired")
                    };
                    case (#UnknownKey({ keyVersion })) {
                        #err("Unknown key version: " # debug_show(keyVersion))
                    };
                }
            };
            case null {
                #err("No active key available")
            };
        }
    };

    public func deliverMessages() : async [SecureTransport.DeliveryReceipt] {
        if (not pushMode) {
            // In pull mode, process pending deliveries
            await secureTransport.processPendingDeliveries()
        } else {
            []
        }
    };

    // ===============================
    // BATCH PROCESSING
    // ===============================

    public shared(msg) func submitBatchRequest(
        requests: [BatchProcessor.RequestItem],
        priority: ?BatchProcessor.BatchPriority
    ) : async Result.Result<Text, Text> {
        if (not isInitialized) {
            return #err("System not initialized");
        };

        batchProcessor.submitBatch(requests, msg.caller, priority, null)
    };

    public func processBatchRequests() : async ?BatchProcessor.BatchResponse {
        await batchProcessor.processNextBatch()
    };

    public func getBatchStatus(batchId: Text) : async ?BatchProcessor.BatchStatus {
        batchProcessor.getBatchStatus(batchId)
    };

    public func getBatchResponse(batchId: Text) : async ?BatchProcessor.BatchResponse {
        batchProcessor.getBatchResponse(batchId)
    };

    // ===============================
    // KEY ROTATION MANAGEMENT
    // ===============================

    public shared(msg) func rotateKeys(reason: KeyRotation.RotationReason) : async Result.Result<Text, Text> {
        switch (keyManager.rotateKey(reason, msg.caller)) {
            case (#ok(newKey)) {
                #ok("Key rotated successfully to version " # debug_show(newKey.version))
            };
            case (#err(error)) {
                #err("Key rotation failed: " # error)
            };
        }
    };

    public func checkKeyRotationAlerts() : async [KeyRotation.RotationAlert] {
        keyManager.checkRotationAlerts()
    };

    public func executeScheduledKeyRotation() : async Result.Result<Text, Text> {
        switch (await keyManager.executeAutomaticRotation(Principal.fromText("2vxsx-fae"))) {
            case (#ok(newKey)) {
                #ok("Automatic key rotation completed: v" # debug_show(newKey.version))
            };
            case (#err(error)) {
                #err("Automatic rotation failed: " # error)
            };
        }
    };

    // ===============================
    // COMPLIANCE REPORTING
    // ===============================

    public shared(msg) func generateComplianceReport(
        reportType: ReportGenerator.ReportType,
        retentionClass: ReportGenerator.RetentionClass
    ) : async Result.Result<Text, Text> {
        let now = Time.now();
        let period: ReportGenerator.ReportPeriod = {
            startTime = now - (7 * 24 * 60 * 60 * 1_000_000_000); // Last 7 days
            endTime = now;
            periodType = #Weekly;
        };

        switch (await reportGenerator.generateReport(period, reportType, retentionClass, msg.caller)) {
            case (#ok(report)) {
                #ok("Report generated: " # report.reportId)
            };
            case (#err(error)) {
                #err("Report generation failed: " # error)
            };
        }
    };

    public func processScheduledReports() : async [ReportGenerator.ComplianceReport] {
        await reportGenerator.processScheduledReports()
    };

    public shared(msg) func approveReport(reportId: Text) : async Result.Result<Text, Text> {
        switch (reportGenerator.approveReport(reportId, msg.caller)) {
            case (#ok(_)) {
                #ok("Report approved: " # reportId)
            };
            case (#err(error)) {
                #err("Approval failed: " # error)
            };
        }
    };

    public func getReport(reportId: Text) : async ?ReportGenerator.ComplianceReport {
        reportGenerator.getReport(reportId)
    };

    // ===============================
    // HEALTH CHECKS & MONITORING
    // ===============================

    public func healthCheck() : async {
        status: Text;
        timestamp: Time.Time;
        metrics: [(Text, Float)];
        alerts: [Text];
    } {
        let alerts = Buffer.Buffer<Text>(10);
        
        // Check key rotation alerts
        let keyAlerts = await checkKeyRotationAlerts();
        for (alert in keyAlerts.vals()) {
            if (alert.actionRequired) {
                alerts.add("Key rotation: " # alert.message);
            }
        };

        // Check communication health
        let securityMetrics = secureTransport.getSecurityMetrics();
        if (securityMetrics.deliverySuccessRate < 0.95) {
            alerts.add("Low delivery success rate: " # debug_show(securityMetrics.deliverySuccessRate));
        };

        let status = if (alerts.size() > 0) "WARNING" else "HEALTHY";

        {
            status = status;
            timestamp = Time.now();
            metrics = Iter.toArray(systemMetrics.entries());
            alerts = Buffer.toArray(alerts);
        }
    };

    public func getSystemMetrics() : async {
        communication: {
            mode: Text;
            securityMetrics: {
                totalMessages: Nat;
                pendingDeliveries: Nat;
                deliverySuccessRate: Float;
            };
            batchMetrics: BatchProcessor.QueueMetrics;
        };
        keyManagement: {
            currentKeyVersion: Nat;
            totalRotations: Nat;
            nextRotationIn: Int;
            activeAlerts: Nat;
        };
        compliance: {
            totalReports: Nat;
            pendingApproval: Nat;
            publishedReports: Nat;
            activeSchedules: Nat;
        };
    } {
        let mode = if (pushMode) "push" else "pull";
        let securityMetrics = secureTransport.getSecurityMetrics();
        let batchMetrics = batchProcessor.getQueueMetrics();
        let keyMetrics = keyManager.getRotationMetrics();
        let complianceMetrics = reportGenerator.getComplianceMetrics();

        {
            communication = {
                mode = mode;
                securityMetrics = {
                    totalMessages = securityMetrics.totalMessages;
                    pendingDeliveries = securityMetrics.pendingDeliveries;
                    deliverySuccessRate = securityMetrics.deliverySuccessRate;
                };
                batchMetrics = batchMetrics;
            };
            keyManagement = {
                currentKeyVersion = keyMetrics.currentKeyVersion;
                totalRotations = keyMetrics.totalRotations;
                nextRotationIn = keyMetrics.nextRotationIn;
                activeAlerts = keyMetrics.activeAlerts;
            };
            compliance = {
                totalReports = complianceMetrics.totalReports;
                pendingApproval = complianceMetrics.pendingApproval;
                publishedReports = complianceMetrics.publishedReports;
                activeSchedules = complianceMetrics.activeSchedules;
            };
        }
    };

    // ===============================
    // FAILOVER & REDUNDANCY
    // ===============================

    public func testFailover() : async Result.Result<Text, Text> {
        let originalMode = pushMode;
        
        // Test switching modes
        switch (await switchCommunicationMode(not originalMode)) {
            case (#ok(_)) {
                // Test message delivery in new mode
                let testPayload = Text.encodeUtf8("failover_test");
                let testPrincipal = Principal.fromText("2vxsx-fae");
                
                switch (await sendSecureMessage(testPayload, testPrincipal, #HealthCheck)) {
                    case (#ok(_)) {
                        // Switch back to original mode
                        ignore await switchCommunicationMode(originalMode);
                        #ok("Failover test successful")
                    };
                    case (#err(error)) {
                        ignore await switchCommunicationMode(originalMode);
                        #err("Failover test failed: " # error)
                    };
                }
            };
            case (#err(error)) {
                #err("Mode switch failed: " # error)
            };
        }
    };

    // ===============================
    // PRIVATE HELPERS
    // ===============================

    private func updateMetrics(metricName: Text, value: Float) {
        switch (systemMetrics.get(metricName)) {
            case (?currentValue) {
                systemMetrics.put(metricName, currentValue + value);
            };
            case null {
                systemMetrics.put(metricName, value);
            };
        }
    };
}
