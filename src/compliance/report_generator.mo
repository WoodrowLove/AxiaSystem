import Time "mo:base/Time";
import Result "mo:base/Result";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import _Array "mo:base/Array";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Principal "mo:base/Principal";
import _Option "mo:base/Option";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Float "mo:base/Float";

module {
    public type ComplianceReport = {
        reportId: Text;
        generatedAt: Time.Time;
        period: ReportPeriod;
        metrics: ComplianceMetrics;
        retentionClass: RetentionClass;
        sections: [ReportSection];
        auditTrail: AuditTrail;
        status: ReportStatus;
    };

    public type ReportPeriod = {
        startTime: Time.Time;
        endTime: Time.Time;
        periodType: PeriodType;
    };

    public type PeriodType = {
        #Daily;
        #Weekly;
        #Monthly;
        #Quarterly;
        #Annual;
        #Custom;
    };

    public type RetentionClass = {
        #ShortTerm: { daysToRetain: Nat }; // 30-90 days
        #MediumTerm: { daysToRetain: Nat }; // 1-3 years
        #LongTerm: { daysToRetain: Nat }; // 7+ years
        #Permanent;
    };

    public type ComplianceMetrics = {
        totalTransactions: Nat;
        complianceViolations: Nat;
        violationRate: Float;
        averageResponseTime: Nat;
        slaCompliance: Float;
        auditCoverage: Float;
        riskScore: Float;
        escalations: Nat;
    };

    public type ReportSection = {
        sectionId: Text;
        title: Text;
        content: SectionContent;
        severity: Severity;
        findings: [Finding];
    };

    public type SectionContent = {
        #ExecutiveSummary: { summary: Text; keyMetrics: [Text] };
        #TransactionAnalysis: { analysis: Text; patterns: [Text] };
        #ViolationDetails: { violations: [ViolationDetail]; remediation: [Text] };
        #PerformanceMetrics: { metrics: [MetricDetail]; trends: [Text] };
        #RiskAssessment: { risks: [RiskItem]; mitigations: [Text] };
        #Recommendations: { recommendations: [Text]; priority: Priority };
    };

    public type Severity = {
        #Low;
        #Medium;
        #High;
        #Critical;
    };

    public type Priority = {
        #Low;
        #Medium;
        #High;
        #Urgent;
    };

    public type Finding = {
        findingId: Text;
        description: Text;
        severity: Severity;
        impact: Text;
        recommendation: Text;
        deadline: ?Time.Time;
    };

    public type ViolationDetail = {
        violationId: Text;
        violationType: Text;
        occurredAt: Time.Time;
        description: Text;
        affectedSystems: [Text];
        resolutionStatus: ResolutionStatus;
    };

    public type ResolutionStatus = {
        #Open;
        #InProgress;
        #Resolved;
        #Acknowledged;
    };

    public type MetricDetail = {
        metricName: Text;
        value: Float;
        unit: Text;
        threshold: Float;
        status: MetricStatus;
    };

    public type MetricStatus = {
        #Normal;
        #Warning;
        #Critical;
    };

    public type RiskItem = {
        riskId: Text;
        category: RiskCategory;
        probability: Float;
        impact: Float;
        riskScore: Float;
        description: Text;
    };

    public type RiskCategory = {
        #Operational;
        #Financial;
        #Regulatory;
        #Technical;
        #Strategic;
    };

    public type AuditTrail = {
        generatedBy: Principal;
        approvedBy: ?Principal;
        reviewers: [Principal];
        generationTime: Nat; // Processing time in milliseconds
        dataSource: [Text];
        methodology: Text;
    };

    public type ReportStatus = {
        #Draft;
        #UnderReview;
        #Approved;
        #Published;
        #Archived;
    };

    public type ReportSchedule = {
        scheduleId: Text;
        reportType: ReportType;
        frequency: Frequency;
        nextGeneration: Time.Time;
        isActive: Bool;
        recipients: [Principal];
    };

    public type ReportType = {
        #Daily;
        #Weekly;
        #Monthly;
        #Quarterly;
        #Annual;
        #Incident;
        #Audit;
    };

    public type Frequency = {
        intervalNanos: Int;
        dayOfWeek: ?Nat; // 0-6, Sunday=0
        dayOfMonth: ?Nat; // 1-31
        hour: Nat; // 0-23
    };

    public class ComplianceReportGenerator() {
        private var reportCounter: Nat = 0;
        private let reports = HashMap.HashMap<Text, ComplianceReport>(200, Text.equal, Text.hash);
        private let schedules = HashMap.HashMap<Text, ReportSchedule>(50, Text.equal, Text.hash);
        private let _metricsHistory = Buffer.Buffer<(Time.Time, ComplianceMetrics)>(1000);

        public func generateReport(
            period: ReportPeriod,
            reportType: ReportType,
            retentionClass: RetentionClass,
            generatedBy: Principal
        ) : async Result.Result<ComplianceReport, Text> {
            reportCounter += 1;
            let reportId = "rpt_" # Nat.toText(reportCounter) # "_" # Int.toText(Time.now());
            let startTime = Time.now();

            // Collect metrics for the period
            let metrics = await collectMetricsForPeriod(period);
            
            // Generate report sections based on type
            let sections = await generateReportSections(reportType, period, metrics);

            // Create audit trail
            let auditTrail: AuditTrail = {
                generatedBy = generatedBy;
                approvedBy = null;
                reviewers = [];
                generationTime = Int.abs(Time.now() - startTime) / 1_000_000;
                dataSource = ["transaction_logs", "compliance_checks", "audit_events"];
                methodology = "Automated compliance analysis with statistical sampling";
            };

            let report: ComplianceReport = {
                reportId = reportId;
                generatedAt = Time.now();
                period = period;
                metrics = metrics;
                retentionClass = retentionClass;
                sections = sections;
                auditTrail = auditTrail;
                status = #Draft;
            };

            reports.put(reportId, report);
            #ok(report)
        };

        public func scheduleReport(
            reportType: ReportType,
            frequency: Frequency,
            recipients: [Principal],
            _retentionClass: RetentionClass
        ) : Text {
            let scheduleId = "sched_" # Nat.toText(reportCounter) # "_" # Int.toText(Time.now());
            let nextGeneration = calculateNextGeneration(frequency);

            let schedule: ReportSchedule = {
                scheduleId = scheduleId;
                reportType = reportType;
                frequency = frequency;
                nextGeneration = nextGeneration;
                isActive = true;
                recipients = recipients;
            };

            schedules.put(scheduleId, schedule);
            scheduleId
        };

        public func processScheduledReports() : async [ComplianceReport] {
            let now = Time.now();
            let generatedReports = Buffer.Buffer<ComplianceReport>(10);

            for ((scheduleId, schedule) in schedules.entries()) {
                if (schedule.isActive and now >= schedule.nextGeneration) {
                    // Determine report period based on type
                    let period = createReportPeriod(schedule.reportType, now);
                    let retentionClass = getDefaultRetentionClass(schedule.reportType);

                    let defaultPrincipal = Principal.fromText("2vxsx-fae");
                    let generatedBy = if (schedule.recipients.size() > 0) {
                        schedule.recipients[0]
                    } else {
                        defaultPrincipal
                    };

                    switch (await generateReport(period, schedule.reportType, retentionClass, generatedBy)) {
                        case (#ok(report)) {
                            generatedReports.add(report);

                            // Update next generation time
                            let updatedSchedule = {
                                schedule with 
                                nextGeneration = now + schedule.frequency.intervalNanos;
                            };
                            schedules.put(scheduleId, updatedSchedule);
                        };
                        case (#err(_)) {
                            // Log error but continue processing
                        };
                    };
                }
            };

            Buffer.toArray(generatedReports)
        };

        public func approveReport(reportId: Text, approvedBy: Principal) : Result.Result<ComplianceReport, Text> {
            switch (reports.get(reportId)) {
                case (?report) {
                    let updatedReport = {
                        report with 
                        status = #Approved;
                        auditTrail = {
                            report.auditTrail with 
                            approvedBy = ?approvedBy;
                        };
                    };
                    reports.put(reportId, updatedReport);
                    #ok(updatedReport)
                };
                case null {
                    #err("Report not found")
                };
            }
        };

        public func publishReport(reportId: Text) : Result.Result<ComplianceReport, Text> {
            switch (reports.get(reportId)) {
                case (?report) {
                    if (report.status != #Approved) {
                        return #err("Report must be approved before publishing");
                    };

                    let publishedReport = {
                        report with 
                        status = #Published;
                    };
                    reports.put(reportId, publishedReport);
                    #ok(publishedReport)
                };
                case null {
                    #err("Report not found")
                };
            }
        };

        public func getReport(reportId: Text) : ?ComplianceReport {
            reports.get(reportId)
        };

        public func getReportsByPeriod(startTime: Time.Time, endTime: Time.Time) : [ComplianceReport] {
            let results = Buffer.Buffer<ComplianceReport>(50);

            for ((_, report) in reports.entries()) {
                if (report.generatedAt >= startTime and report.generatedAt <= endTime) {
                    results.add(report);
                }
            };

            Buffer.toArray(results)
        };

        public func archiveOldReports(cutoffTime: Time.Time) : Nat {
            let toArchive = Buffer.Buffer<Text>(50);

            for ((reportId, report) in reports.entries()) {
                let shouldArchive = switch (report.retentionClass) {
                    case (#ShortTerm({ daysToRetain })) {
                        let retentionNanos = daysToRetain * 24 * 60 * 60 * 1_000_000_000;
                        report.generatedAt + retentionNanos < cutoffTime
                    };
                    case (#MediumTerm({ daysToRetain })) {
                        let retentionNanos = daysToRetain * 24 * 60 * 60 * 1_000_000_000;
                        report.generatedAt + retentionNanos < cutoffTime
                    };
                    case (#LongTerm({ daysToRetain })) {
                        let retentionNanos = daysToRetain * 24 * 60 * 60 * 1_000_000_000;
                        report.generatedAt + retentionNanos < cutoffTime
                    };
                    case (#Permanent) false;
                };

                if (shouldArchive) {
                    toArchive.add(reportId);
                }
            };

            for (reportId in toArchive.vals()) {
                switch (reports.get(reportId)) {
                    case (?report) {
                        let archivedReport = {
                            report with status = #Archived
                        };
                        reports.put(reportId, archivedReport);
                    };
                    case null {};
                }
            };

            toArchive.size()
        };

        public func getComplianceMetrics() : {
            totalReports: Nat;
            pendingApproval: Nat;
            publishedReports: Nat;
            activeSchedules: Nat;
            averageGenerationTime: Nat;
        } {
            var pendingCount = 0;
            var publishedCount = 0;
            var totalGenerationTime = 0;
            var reportCount = 0;

            for ((_, report) in reports.entries()) {
                switch (report.status) {
                    case (#UnderReview or #Draft) pendingCount += 1;
                    case (#Published) publishedCount += 1;
                    case (_) {};
                };
                totalGenerationTime += report.auditTrail.generationTime;
                reportCount += 1;
            };

            let activeScheduleCount = Iter.size(
                Iter.filter(schedules.vals(), func(schedule: ReportSchedule) : Bool {
                    schedule.isActive
                })
            );

            {
                totalReports = reports.size();
                pendingApproval = pendingCount;
                publishedReports = publishedCount;
                activeSchedules = activeScheduleCount;
                averageGenerationTime = if (reportCount > 0) { 
                    totalGenerationTime / reportCount 
                } else { 0 };
            }
        };

        // Private helper functions
        private func collectMetricsForPeriod(period: ReportPeriod) : async ComplianceMetrics {
            // Simulate metrics collection - in production would query actual data
            let transactions = 10000 + (Int.abs(period.startTime) % 5000);
            let violations = transactions / 100; // 1% violation rate
            
            {
                totalTransactions = Int.abs(transactions);
                complianceViolations = Int.abs(violations);
                violationRate = Float.fromInt(violations) / Float.fromInt(transactions);
                averageResponseTime = 150; // 150ms average
                slaCompliance = 0.98; // 98% SLA compliance
                auditCoverage = 0.95; // 95% audit coverage
                riskScore = 2.3; // Scale of 1-5
                escalations = Int.abs(violations / 10);
            }
        };

        private func generateReportSections(
            _reportType: ReportType, 
            _period: ReportPeriod, 
            metrics: ComplianceMetrics
        ) : async [ReportSection] {
            let sections = Buffer.Buffer<ReportSection>(5);

            // Executive Summary
            sections.add({
                sectionId = "exec_summary";
                title = "Executive Summary";
                content = #ExecutiveSummary({
                    summary = "Compliance performance for the reporting period shows " # 
                             Float.toText(metrics.slaCompliance * 100.0) # "% SLA compliance";
                    keyMetrics = [
                        "Total Transactions: " # Nat.toText(metrics.totalTransactions),
                        "Violation Rate: " # Float.toText(metrics.violationRate * 100.0) # "%",
                        "Risk Score: " # Float.toText(metrics.riskScore) # "/5.0"
                    ];
                });
                severity = #Medium;
                findings = [];
            });

            // Performance Metrics
            sections.add({
                sectionId = "performance";
                title = "Performance Metrics";
                content = #PerformanceMetrics({
                    metrics = [
                        {
                            metricName = "SLA Compliance";
                            value = metrics.slaCompliance * 100.0;
                            unit = "%";
                            threshold = 95.0;
                            status = if (metrics.slaCompliance >= 0.95) #Normal else #Warning;
                        },
                        {
                            metricName = "Average Response Time";
                            value = Float.fromInt(metrics.averageResponseTime);
                            unit = "ms";
                            threshold = 200.0;
                            status = if (metrics.averageResponseTime <= 200) #Normal else #Warning;
                        }
                    ];
                    trends = ["SLA compliance trending upward", "Response times stable"];
                });
                severity = #Low;
                findings = [];
            });

            Buffer.toArray(sections)
        };

        private func createReportPeriod(reportType: ReportType, currentTime: Time.Time) : ReportPeriod {
            let (startTime, endTime, periodType) = switch (reportType) {
                case (#Daily) {
                    let dayStart = currentTime - (24 * 60 * 60 * 1_000_000_000);
                    (dayStart, currentTime, #Daily)
                };
                case (#Weekly) {
                    let weekStart = currentTime - (7 * 24 * 60 * 60 * 1_000_000_000);
                    (weekStart, currentTime, #Weekly)
                };
                case (#Monthly) {
                    let monthStart = currentTime - (30 * 24 * 60 * 60 * 1_000_000_000);
                    (monthStart, currentTime, #Monthly)
                };
                case (#Quarterly) {
                    let quarterStart = currentTime - (90 * 24 * 60 * 60 * 1_000_000_000);
                    (quarterStart, currentTime, #Quarterly)
                };
                case (#Annual) {
                    let yearStart = currentTime - (365 * 24 * 60 * 60 * 1_000_000_000);
                    (yearStart, currentTime, #Annual)
                };
                case (_) {
                    let dayStart = currentTime - (24 * 60 * 60 * 1_000_000_000);
                    (dayStart, currentTime, #Daily)
                };
            };

            {
                startTime = startTime;
                endTime = endTime;
                periodType = periodType;
            }
        };

        private func getDefaultRetentionClass(reportType: ReportType) : RetentionClass {
            switch (reportType) {
                case (#Daily) #ShortTerm({ daysToRetain = 90 });
                case (#Weekly) #MediumTerm({ daysToRetain = 365 });
                case (#Monthly or #Quarterly) #LongTerm({ daysToRetain = 2555 }); // 7 years
                case (#Annual or #Audit) #Permanent;
                case (_) #MediumTerm({ daysToRetain = 365 });
            }
        };

        private func calculateNextGeneration(frequency: Frequency) : Time.Time {
            Time.now() + frequency.intervalNanos
        };
    };
}
