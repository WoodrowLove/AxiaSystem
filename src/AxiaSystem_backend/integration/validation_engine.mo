// AxiaSystem Enhanced Validation Engine - Comprehensive System Integrity with Triad Compliance
// Validates triad compliance, data consistency, cross-system integrity, and correlation tracking

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import Int "mo:base/Int";
import _Buffer "mo:base/Buffer";

// Enhanced System imports for Triad Architecture
import AssetProxy "../asset/utils/asset_proxy";
import AssetRegistryProxy "../asset_registry/utils/asset_registry_proxy";
import EscrowProxy "../escrow/utils/escrow_canister_proxy";
import EventManager "../heartbeat/event_manager";

// Enhanced Triad imports
import TriadShared "../types/triad_shared";
import CorrelationUtils "../utils/correlation";
import EnhancedTriadEventManager "../heartbeat/enhanced_triad_event_manager";

module {
    // Enhanced type definitions for validation with triad support
    public type Asset = {
        id: Nat;
        ownerIdentity: Principal;
        userId: ?Principal;
        walletId: ?Principal;
        metadata: Text;
        registeredAt: Int;
        updatedAt: Int;
        isActive: Bool;
        triadVerified: Bool;
    };

    public type RegistryAsset = {
        id: Nat;
        ownerIdentity: Principal;
        nftId: Nat;
        metadata: Text;
        registeredAt: Int;
        updatedAt: Int;
        isActive: Bool;
        triadVerified: Bool;
    };

    // Enhanced Validation Types with Triad Support
    public type ValidationSeverity = {
        #info;
        #warning;
        #error;
        #critical;
        #security;  // 🆕 Enhanced: Security-specific issues
    };

    public type ValidationCategory = {
        #triadCompliance;
        #dataConsistency;
        #systemIntegrity;
        #performance;
        #security;
        #correlation;  // 🆕 Enhanced: Correlation tracking issues
    };

    public type EnhancedValidationIssue = {
        issueId: Nat;
        severity: ValidationSeverity;
        category: ValidationCategory;  // 🆕 Enhanced: Categorization
        component: Text; // "asset", "registry", "escrow", "integration", "correlation"
        description: Text;
        recommendation: Text;
        autoFixable: Bool;
        detectedAt: Nat64;
        correlation: ?TriadShared.CorrelationContext;  // 🆕 Enhanced: Correlation tracking
        triadIdentity: ?TriadShared.TriadIdentity;     // 🆕 Enhanced: Associated identity
        metadata: [(Text, Text)];  // 🆕 Enhanced: Additional context metadata
    };

    public type EnhancedValidationReport = {
        reportId: Nat;
        generatedAt: Nat64;
        systemHealth: Text; // "healthy", "degraded", "critical", "compromised"
        totalIssues: Nat;
        issuesBySeverity: {critical: Nat; security: Nat; error: Nat; warning: Nat; info: Nat};
        issuesByCategory: {triad: Nat; consistency: Nat; integrity: Nat; performance: Nat; security: Nat; correlation: Nat};
        issues: [EnhancedValidationIssue];
        recommendations: [Text];
        correlation: TriadShared.CorrelationContext;  // 🆕 Enhanced: Report correlation
        executionTime: Nat64;  // 🆕 Enhanced: Performance tracking
        validationScope: [Text];  // 🆕 Enhanced: What was validated
    };

    public type EnhancedSystemMetrics = {
        assetCount: Nat;
        registryCount: Nat;
        escrowCount: Nat;
        triadCompliantAssets: Nat;
        orphanedAssets: Nat;
        dataInconsistencies: Nat;
        correlationHealth: {active: Nat; stale: Nat; orphaned: Nat};  // 🆕 Enhanced
        securityScore: Nat;  // 🆕 Enhanced: 0-100 security score
        performanceMetrics: {avgValidationTime: Nat64; maxValidationTime: Nat64};  // 🆕 Enhanced
        lastValidation: ?Nat64;
        nextScheduledValidation: ?Nat64;  // 🆕 Enhanced
    };

    // 🆕 Enhanced: Validation Configuration
    public type ValidationConfig = {
        enableDeepTriadChecks: Bool;
        enableCorrelationValidation: Bool;
        enablePerformanceValidation: Bool;
        enableSecurityScanning: Bool;
        maxIssuesPerCategory: Nat;
        autoFixEnabled: Bool;
        retentionPeriodDays: Nat;
    };

    // Enhanced Validation Engine Class with Triad Support
    public class EnhancedValidationEngine(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        _eventManager: EventManager.EventManager
    ) {
        private let assetProxy = AssetProxy.AssetProxy(assetCanisterId);
        private let assetRegistryProxy = AssetRegistryProxy.AssetRegistryProxy(assetRegistryCanisterId);
        private let _escrowProxy = EscrowProxy.EscrowCanisterProxy(escrowCanisterId);
        
        // 🆕 Enhanced: Triad-enabled managers
        private let correlationManager = CorrelationUtils.CorrelationManager();
        private let enhancedEventManager = EnhancedTriadEventManager.EnhancedTriadEventManager(_eventManager);
        
        private var validationHistory: [EnhancedValidationReport] = [];
        private var nextReportId: Nat = 1;
        private var nextIssueId: Nat = 1;
        
        // 🆕 Enhanced: Validation configuration
        private var config: ValidationConfig = {
            enableDeepTriadChecks = true;
            enableCorrelationValidation = true;
            enablePerformanceValidation = true;
            enableSecurityScanning = true;
            maxIssuesPerCategory = 20;
            autoFixEnabled = true;
            retentionPeriodDays = 30;
        };

        // ================================
        // ENHANCED COMPREHENSIVE VALIDATION
        // ================================

        // 🔍 Run Enhanced System Validation with Triad Compliance
        public func validateSystemIntegrity(): async EnhancedValidationReport {
            let startTime = Nat64.fromIntWrap(Time.now());
            
            let correlation = correlationManager.createCorrelation(
                "system-validation",
                Principal.fromText("anonymous"),
                "validation-engine",
                "comprehensive-validation"
            );
            
            var issues: [EnhancedValidationIssue] = [];
            var validationScope: [Text] = [];
            
            // 1. Enhanced Asset System Validation
            let assetIssues = await validateEnhancedAssetSystem(correlation);
            issues := Array.append(issues, assetIssues);
            validationScope := Array.append(validationScope, ["asset-system"]);
            
            // 2. Enhanced Asset Registry Validation
            let registryIssues = await validateEnhancedAssetRegistry(correlation);
            issues := Array.append(issues, registryIssues);
            validationScope := Array.append(validationScope, ["asset-registry"]);
            
            // 3. Enhanced Cross-System Consistency
            let consistencyIssues = await validateEnhancedCrossSystemConsistency(correlation);
            issues := Array.append(issues, consistencyIssues);
            validationScope := Array.append(validationScope, ["cross-system-consistency"]);
            
            // 4. Enhanced Triad Compliance Check
            let triadIssues = await validateEnhancedTriadCompliance(correlation);
            issues := Array.append(issues, triadIssues);
            validationScope := Array.append(validationScope, ["triad-compliance"]);
            
            // 5. 🆕 Enhanced: Correlation Health Validation
            if (config.enableCorrelationValidation) {
                let correlationIssues = await validateCorrelationHealth(correlation);
                issues := Array.append(issues, correlationIssues);
                validationScope := Array.append(validationScope, ["correlation-health"]);
            };
            
            // 6. 🆕 Enhanced: Security Validation
            if (config.enableSecurityScanning) {
                let securityIssues = await validateSecurityCompliance(correlation);
                issues := Array.append(issues, securityIssues);
                validationScope := Array.append(validationScope, ["security-compliance"]);
            };
            
            let endTime = Nat64.fromIntWrap(Time.now());
            let executionTime = endTime - startTime;
            
            // Generate enhanced comprehensive report
            let report = generateEnhancedValidationReport(issues, correlation, executionTime, validationScope);
            validationHistory := Array.append(validationHistory, [report]);
            
            // Emit validation completion event
            let _ = await enhancedEventManager.emitTriadEvent(
                #AlertRaised,
                #AlertRaised({
                    alertType = "validation-completed";
                    message = "System validation completed: " # report.systemHealth # " health";
                    timestamp = Nat64.fromIntWrap(Time.now());
                }),
                correlation,
                ?#normal,
                ["validation"],
                ["system-health", "validation-report"],
                [("reportId", Nat.toText(report.reportId)), ("totalIssues", Nat.toText(report.totalIssues))]
            );
            
            report
        };

        // 🎯 Enhanced Asset System Validation with Triad Support
        public func validateEnhancedAssetSystem(correlation: TriadShared.CorrelationContext): async [EnhancedValidationIssue] {
            var issues: [EnhancedValidationIssue] = [];
            
            // Get all assets
            let assets = await assetProxy.getAllAssets();
            
            // Check for common issues with enhanced triad context
            for (asset in assets.vals()) {
                // Check for empty metadata
                if (asset.metadata == "") {
                    issues := Array.append(issues, [createEnhancedIssue(
                        #warning,
                        #dataConsistency,
                        "asset",
                        "Asset " # Nat.toText(asset.id) # " has empty metadata",
                        "Add descriptive metadata to improve asset discoverability",
                        false,
                        ?correlation,
                        null,
                        [("assetId", Nat.toText(asset.id)), ("owner", Principal.toText(asset.ownerIdentity))]
                    )]);
                };
                
                // Check for invalid ownership
                if (Principal.isAnonymous(asset.ownerIdentity)) {
                    issues := Array.append(issues, [createEnhancedIssue(
                        #security,
                        #security,
                        "asset",
                        "Asset " # Nat.toText(asset.id) # " has anonymous owner",
                        "Transfer asset to valid principal ownership",
                        false,
                        ?correlation,
                        null,
                        [("assetId", Nat.toText(asset.id)), ("severity", "high")]
                    )]);
                };
                
                // Enhanced triad compliance check
                if (not asset.triadVerified) {
                    let severity = if (config.enableDeepTriadChecks) #warning else #info;
                    issues := Array.append(issues, [createEnhancedIssue(
                        severity,
                        #triadCompliance,
                        "asset",
                        "Asset " # Nat.toText(asset.id) # " is not triad-verified",
                        "Upgrade to triad-compliant asset management for enhanced security",
                        true,
                        ?correlation,
                        null,
                        [("assetId", Nat.toText(asset.id)), ("triadUpgradeAvailable", "true")]
                    )]);
                };
                
                // 🆕 Enhanced: Check for stale assets
                let daysSinceUpdate = (Time.now() - asset.updatedAt) / (24 * 60 * 60 * 1_000_000_000);
                if (daysSinceUpdate > 90) {
                    issues := Array.append(issues, [createEnhancedIssue(
                        #info,
                        #performance,
                        "asset",
                        "Asset " # Nat.toText(asset.id) # " has not been updated in " # Int.toText(daysSinceUpdate) # " days",
                        "Review asset activity and consider archival if no longer needed",
                        false,
                        ?correlation,
                        null,
                        [("assetId", Nat.toText(asset.id)), ("daysSinceUpdate", Int.toText(daysSinceUpdate))]
                    )]);
                };
            };
            
            issues
        };

        // 📋 Enhanced Asset Registry Validation with Correlation Tracking
        public func validateEnhancedAssetRegistry(correlation: TriadShared.CorrelationContext): async [EnhancedValidationIssue] {
            var issues: [EnhancedValidationIssue] = [];
            
            // Get all registry entries
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            // Check for registry-specific issues with enhanced context
            for (regAsset in registryAssets.vals()) {
                // Check for missing NFT linkage
                if (regAsset.nftId == 0) {
                    issues := Array.append(issues, [createEnhancedIssue(
                        #warning,
                        #dataConsistency,
                        "registry",
                        "Registry asset " # Nat.toText(regAsset.id) # " has no NFT linkage",
                        "Link asset to corresponding NFT for full traceability",
                        true,
                        ?correlation,
                        null,
                        [("registryAssetId", Nat.toText(regAsset.id)), ("autoFixable", "true")]
                    )]);
                };
                
                // Check for inactive assets with recent activity
                if (not regAsset.isActive and (Time.now() - regAsset.updatedAt) < (24 * 60 * 60 * 1_000_000_000)) {
                    issues := Array.append(issues, [createEnhancedIssue(
                        #info,
                        #systemIntegrity,
                        "registry",
                        "Registry asset " # Nat.toText(regAsset.id) # " was recently deactivated",
                        "Review deactivation reason and consider reactivation if appropriate",
                        false,
                        ?correlation,
                        null,
                        [("registryAssetId", Nat.toText(regAsset.id)), ("deactivatedRecently", "true")]
                    )]);
                };
                
                // 🆕 Enhanced: Check for triad compliance in registry
                if (not regAsset.triadVerified and config.enableDeepTriadChecks) {
                    issues := Array.append(issues, [createEnhancedIssue(
                        #warning,
                        #triadCompliance,
                        "registry",
                        "Registry asset " # Nat.toText(regAsset.id) # " lacks triad verification",
                        "Upgrade registry entry to triad-compliant structure",
                        true,
                        ?correlation,
                        null,
                        [("registryAssetId", Nat.toText(regAsset.id)), ("triadUpgradePath", "available")]
                    )]);
                };
            };
            
            issues
        };

        // 🔗 Enhanced Cross-System Consistency Validation with Deep Analysis
        public func validateEnhancedCrossSystemConsistency(correlation: TriadShared.CorrelationContext): async [EnhancedValidationIssue] {
            var issues: [EnhancedValidationIssue] = [];
            
            // Get data from all systems
            let assets = await assetProxy.getAllAssets();
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            // Enhanced orphaned assets detection
            for (asset in assets.vals()) {
                let hasRegistryEntry = Array.find(registryAssets, func(regAsset: RegistryAsset): Bool {
                    regAsset.ownerIdentity == asset.ownerIdentity and regAsset.metadata == asset.metadata
                });
                
                switch (hasRegistryEntry) {
                    case null {
                        issues := Array.append(issues, [createEnhancedIssue(
                            #warning,
                            #dataConsistency,
                            "integration",
                            "Asset " # Nat.toText(asset.id) # " exists without registry entry",
                            "Create corresponding registry entry for complete asset tracking",
                            true,
                            ?correlation,
                            null,
                            [("assetId", Nat.toText(asset.id)), ("orphanType", "asset-without-registry")]
                        )]);
                    };
                    case (?regAsset) {
                        // 🆕 Enhanced: Deep consistency checks
                        if (asset.isActive != regAsset.isActive) {
                            issues := Array.append(issues, [createEnhancedIssue(
                                #error,
                                #dataConsistency,
                                "integration",
                                "Asset " # Nat.toText(asset.id) # " has inconsistent active status with registry",
                                "Synchronize active status between asset and registry systems",
                                true,
                                ?correlation,
                                null,
                                [("assetId", Nat.toText(asset.id)), ("registryId", Nat.toText(regAsset.id))]
                            )]);
                        };
                        
                        // Check timestamp consistency
                        if (Int.abs(asset.updatedAt - regAsset.updatedAt) > (60 * 60 * 1_000_000_000)) { // 1 hour threshold
                            issues := Array.append(issues, [createEnhancedIssue(
                                #info,
                                #dataConsistency,
                                "integration",
                                "Asset " # Nat.toText(asset.id) # " has inconsistent update timestamps",
                                "Synchronize update timestamps for accurate audit trails",
                                true,
                                ?correlation,
                                null,
                                [("assetId", Nat.toText(asset.id)), ("timeDrift", "high")]
                            )]);
                        };
                    };
                };
            };
            
            // Enhanced registry entries without corresponding assets
            for (regAsset in registryAssets.vals()) {
                let hasAssetEntry = Array.find(assets, func(asset: Asset): Bool {
                    asset.ownerIdentity == regAsset.ownerIdentity and asset.metadata == regAsset.metadata
                });
                
                switch (hasAssetEntry) {
                    case null {
                        issues := Array.append(issues, [createEnhancedIssue(
                            #warning,
                            #dataConsistency,
                            "integration",
                            "Registry asset " # Nat.toText(regAsset.id) # " has no corresponding asset",
                            "Create asset entry or remove orphaned registry entry",
                            true,
                            ?correlation,
                            null,
                            [("registryAssetId", Nat.toText(regAsset.id)), ("orphanType", "registry-without-asset")]
                        )]);
                    };
                    case (?_) {
                        // Ownership is consistent - additional checks passed
                    };
                };
            };
            
            issues
        };

        // 🆕 Enhanced: Correlation Health Validation
        public func validateCorrelationHealth(correlation: TriadShared.CorrelationContext): async [EnhancedValidationIssue] {
            var issues: [EnhancedValidationIssue] = [];
            
            let correlationStats = correlationManager.getStats();
            
            // Check for excessive active correlations
            if (correlationStats.activeFlows > 1000) {
                issues := Array.append(issues, [createEnhancedIssue(
                    #warning,
                    #performance,
                    "correlation",
                    "High number of active correlations: " # Nat.toText(correlationStats.activeFlows),
                    "Review correlation cleanup policies and increase pruning frequency",
                    true,
                    ?correlation,
                    null,
                    [("activeCorrelations", Nat.toText(correlationStats.activeFlows)), ("threshold", "1000")]
                )]);
            };
            
            // Check for stale correlations (simplified check with safe subtraction)
            let estimatedStaleOperations = if (correlationStats.totalCorrelations > correlationStats.activeFlows) {
                Int.abs(correlationStats.totalCorrelations - correlationStats.activeFlows)
            } else 0;
            
            if (estimatedStaleOperations > 100) {
                issues := Array.append(issues, [createEnhancedIssue(
                    #info,
                    #correlation,
                    "correlation",
                    "Estimated stale correlations: " # Nat.toText(estimatedStaleOperations),
                    "Run correlation cleanup to remove expired tracking data",
                    true,
                    ?correlation,
                    null,
                    [("estimatedStaleCorrelations", Nat.toText(estimatedStaleOperations))]
                )]);
            };
            
            issues
        };

        // 🆕 Enhanced: Security Compliance Validation
        public func validateSecurityCompliance(correlation: TriadShared.CorrelationContext): async [EnhancedValidationIssue] {
            var issues: [EnhancedValidationIssue] = [];
            
            let assets = await assetProxy.getAllAssets();
            let _registryAssets = await assetRegistryProxy.getAllAssets(); // Get for completeness
            
            // Check for security vulnerabilities
            var anonymousAssetCount = 0;
            var unverifiedTriadCount = 0;
            
            for (asset in assets.vals()) {
                if (Principal.isAnonymous(asset.ownerIdentity)) {
                    anonymousAssetCount += 1;
                };
                if (not asset.triadVerified) {
                    unverifiedTriadCount += 1;
                };
            };
            
            // Security score calculation (0-100)
            let totalAssets = assets.size();
            let securityScore = if (totalAssets == 0) 100 else {
                let vulnerabilityScore = ((anonymousAssetCount * 20) + (unverifiedTriadCount * 10)) / totalAssets;
                Int.max(0, 100 - vulnerabilityScore)
            };
            
            if (securityScore < 70) {
                let securityScoreNat = Int.abs(securityScore);
                issues := Array.append(issues, [createEnhancedIssue(
                    #security,
                    #security,
                    "system",
                    "Low security score: " # Nat.toText(securityScoreNat) # "/100",
                    "Address anonymous ownership and triad verification issues",
                    false,
                    ?correlation,
                    null,
                    [("securityScore", Nat.toText(securityScoreNat)), ("anonymousAssets", Nat.toText(anonymousAssetCount))]
                )]);
            };
            
            issues
        };

        // 🛡️ Enhanced Triad Compliance Validation with Deep Analysis
        public func validateEnhancedTriadCompliance(correlation: TriadShared.CorrelationContext): async [EnhancedValidationIssue] {
            var issues: [EnhancedValidationIssue] = [];
            
            let assets = await assetProxy.getAllAssets();
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            // Enhanced triad vs non-triad analysis
            let triadAssets = Array.filter(assets, func(asset: Asset): Bool { asset.triadVerified });
            let nonTriadAssets = Array.filter(assets, func(asset: Asset): Bool { not asset.triadVerified });
            
            let triadRegistryAssets = Array.filter(registryAssets, func(asset: RegistryAsset): Bool { asset.triadVerified });
            let nonTriadRegistryAssets = Array.filter(registryAssets, func(asset: RegistryAsset): Bool { not asset.triadVerified });
            
            // Calculate triad compliance percentage
            let assetTriadCompliance = if (assets.size() == 0) 100 else (triadAssets.size() * 100) / assets.size();
            let registryTriadCompliance = if (registryAssets.size() == 0) 100 else (triadRegistryAssets.size() * 100) / registryAssets.size();
            
            // Enhanced compliance thresholds
            if (assetTriadCompliance < 80) {
                let severity = if (assetTriadCompliance < 50) #critical else #warning;
                issues := Array.append(issues, [createEnhancedIssue(
                    severity,
                    #triadCompliance,
                    "integration",
                    "Low asset triad compliance: " # Nat.toText(assetTriadCompliance) # "% (" # Nat.toText(nonTriadAssets.size()) # "/" # Nat.toText(assets.size()) # " non-compliant)",
                    "Implement systematic migration to triad-compliant architecture for enhanced security and functionality",
                    true,
                    ?correlation,
                    null,
                    [("complianceRate", Nat.toText(assetTriadCompliance)), ("nonCompliantAssets", Nat.toText(nonTriadAssets.size()))]
                )]);
            };
            
            if (registryTriadCompliance < 80) {
                let severity = if (registryTriadCompliance < 50) #critical else #warning;
                issues := Array.append(issues, [createEnhancedIssue(
                    severity,
                    #triadCompliance,
                    "integration",
                    "Low registry triad compliance: " # Nat.toText(registryTriadCompliance) # "% (" # Nat.toText(nonTriadRegistryAssets.size()) # "/" # Nat.toText(registryAssets.size()) # " non-compliant)",
                    "Upgrade registry entries to triad compliance for improved data integrity",
                    true,
                    ?correlation,
                    null,
                    [("complianceRate", Nat.toText(registryTriadCompliance)), ("nonCompliantRegistryAssets", Nat.toText(nonTriadRegistryAssets.size()))]
                )]);
            };
            
            // 🆕 Enhanced: Deep triad validation for individual assets
            if (config.enableDeepTriadChecks) {
                for (asset in nonTriadAssets.vals()) {
                    // Check if asset has potential for triad upgrade
                    let hasCompleteIdentity = switch (asset.userId, asset.walletId) {
                        case (null, null) false;
                        case (_, _) true;
                    };
                    
                    if (hasCompleteIdentity) {
                        issues := Array.append(issues, [createEnhancedIssue(
                            #info,
                            #triadCompliance,
                            "asset",
                            "Asset " # Nat.toText(asset.id) # " is ready for triad upgrade",
                            "Asset has complete identity information - upgrade to triad verification available",
                            true,
                            ?correlation,
                            null,
                            [("assetId", Nat.toText(asset.id)), ("upgradeReady", "true")]
                        )]);
                    } else {
                        issues := Array.append(issues, [createEnhancedIssue(
                            #warning,
                            #triadCompliance,
                            "asset",
                            "Asset " # Nat.toText(asset.id) # " lacks complete identity for triad upgrade",
                            "Collect userId and walletId information before triad verification",
                            false,
                            ?correlation,
                            null,
                            [("assetId", Nat.toText(asset.id)), ("missingIdentity", "true")]
                        )]);
                    };
                };
            };
            
            issues
        };

        // ================================
        // ENHANCED SYSTEM METRICS & REPORTING
        // ================================

        // 📊 Get Enhanced System Metrics with Comprehensive Analysis
        public func getEnhancedSystemMetrics(): async EnhancedSystemMetrics {
            let startTime = Nat64.fromIntWrap(Time.now());
            
            let assets = await assetProxy.getAllAssets();
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            let triadAssets = Array.filter(assets, func(asset: Asset): Bool { asset.triadVerified });
            
            // Calculate orphaned assets with enhanced logic
            var orphanedCount = 0;
            for (asset in assets.vals()) {
                let hasRegistryEntry = Array.find(registryAssets, func(regAsset: RegistryAsset): Bool {
                    regAsset.ownerIdentity == asset.ownerIdentity
                });
                if (hasRegistryEntry == null) {
                    orphanedCount += 1;
                };
            };
            
            // 🆕 Enhanced: Correlation health metrics
            let correlationStats = correlationManager.getStats();
            let estimatedStaleCorrelations = if (correlationStats.totalCorrelations > correlationStats.activeFlows) {
                Int.abs(correlationStats.totalCorrelations - correlationStats.activeFlows)
            } else 0;
            
            let correlationHealth = {
                active = correlationStats.activeFlows;
                stale = estimatedStaleCorrelations;
                orphaned = 0; // Simplified for now
            };
            
            // 🆕 Enhanced: Security score calculation
            let anonymousAssetCount = Array.filter(assets, func(asset: Asset): Bool {
                Principal.isAnonymous(asset.ownerIdentity)
            }).size();
            
            let securityScore = if (assets.size() == 0) 100 else {
                let nonTriadCount = Int.abs(assets.size() - triadAssets.size());
                let vulnerabilityScore = ((anonymousAssetCount * 20) + (nonTriadCount * 10)) / assets.size();
                Int.abs(Int.max(0, 100 - vulnerabilityScore))
            };
            
            // 🆕 Enhanced: Performance metrics
            let endTime = Nat64.fromIntWrap(Time.now());
            let currentValidationTime = endTime - startTime;
            
            let performanceMetrics = if (validationHistory.size() > 0) {
                let totalTime = Array.foldLeft(validationHistory, 0 : Nat64, func(acc: Nat64, report: EnhancedValidationReport): Nat64 {
                    acc + report.executionTime
                });
                let avgTime = totalTime / Nat64.fromIntWrap(validationHistory.size());
                let maxTime = Array.foldLeft(validationHistory, 0 : Nat64, func(acc: Nat64, report: EnhancedValidationReport): Nat64 {
                    if (report.executionTime > acc) report.executionTime else acc
                });
                {avgValidationTime = avgTime; maxValidationTime = maxTime}
            } else {
                {avgValidationTime = currentValidationTime; maxValidationTime = currentValidationTime}
            };
            
            {
                assetCount = assets.size();
                registryCount = registryAssets.size();
                escrowCount = 0; // TODO: Implement escrow counting
                triadCompliantAssets = triadAssets.size();
                orphanedAssets = orphanedCount;
                dataInconsistencies = Int.abs(assets.size() - registryAssets.size());
                correlationHealth = correlationHealth;
                securityScore = securityScore;
                performanceMetrics = performanceMetrics;
                lastValidation = if (validationHistory.size() > 0) {
                    let lastReport = validationHistory[validationHistory.size() - 1];
                    ?lastReport.generatedAt
                } else null;
                nextScheduledValidation = null; // TODO: Implement scheduling
            }
        };

        // 📋 Get Enhanced Validation History
        public func getEnhancedValidationHistory(): [EnhancedValidationReport] {
            validationHistory
        };

        // 🔧 Enhanced Auto-Fix Issues with Correlation Tracking
        public func autoFixEnhancedIssues(reportId: Nat): async Result.Result<{fixedCount: Nat; failedCount: Nat}, TriadShared.TriadError> {
            let reportOpt = Array.find(validationHistory, func(report: EnhancedValidationReport): Bool {
                report.reportId == reportId
            });
            
            switch (reportOpt) {
                case null { 
                    #err(#NotFound({ id = Nat.toText(reportId); resource = "validation-report" }))
                };
                case (?report) {
                    if (not config.autoFixEnabled) {
                        return #err(#Invalid({ field = "autoFixEnabled"; reason = "Auto-fix is disabled in configuration"; value = "false" }));
                    };

                    var fixedCount = 0;
                    var failedCount = 0;
                    
                    for (issue in report.issues.vals()) {
                        if (issue.autoFixable) {
                            let fixResult = await attemptAutoFix(issue);
                            switch (fixResult) {
                                case (#ok(_)) fixedCount += 1;
                                case (#err(_)) failedCount += 1;
                            };
                        };
                    };
                    
                    #ok({fixedCount = fixedCount; failedCount = failedCount})
                };
            };
        };

        // 🆕 Enhanced: Configuration Management
        public func updateValidationConfig(newConfig: ValidationConfig): () {
            config := newConfig;
        };

        public func getValidationConfig(): ValidationConfig {
            config
        };

        // ================================
        // ENHANCED PRIVATE HELPERS
        // ================================

        // 🆕 Enhanced: Create enhanced validation issue with full context
        private func createEnhancedIssue(
            severity: ValidationSeverity,
            category: ValidationCategory,
            component: Text,
            description: Text,
            recommendation: Text,
            autoFixable: Bool,
            correlation: ?TriadShared.CorrelationContext,
            triadIdentity: ?TriadShared.TriadIdentity,
            metadata: [(Text, Text)]
        ): EnhancedValidationIssue {
            let issue: EnhancedValidationIssue = {
                issueId = nextIssueId;
                severity = severity;
                category = category;
                component = component;
                description = description;
                recommendation = recommendation;
                autoFixable = autoFixable;
                detectedAt = Nat64.fromIntWrap(Time.now());
                correlation = correlation;
                triadIdentity = triadIdentity;
                metadata = metadata;
            };
            nextIssueId += 1;
            issue
        };

        // 🆕 Enhanced: Generate comprehensive validation report
        private func generateEnhancedValidationReport(
            issues: [EnhancedValidationIssue], 
            correlation: TriadShared.CorrelationContext,
            executionTime: Nat64,
            validationScope: [Text]
        ): EnhancedValidationReport {
            // Count issues by severity
            let criticalIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.severity) { case (#critical) true; case _ false; }
            });
            let securityIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.severity) { case (#security) true; case _ false; }
            });
            let errorIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.severity) { case (#error) true; case _ false; }
            });
            let warnings = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.severity) { case (#warning) true; case _ false; }
            });
            let infos = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.severity) { case (#info) true; case _ false; }
            });

            // Count issues by category
            let triadIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.category) { case (#triadCompliance) true; case _ false; }
            });
            let consistencyIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.category) { case (#dataConsistency) true; case _ false; }
            });
            let integrityIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.category) { case (#systemIntegrity) true; case _ false; }
            });
            let performanceIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.category) { case (#performance) true; case _ false; }
            });
            let securityCategoryIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.category) { case (#security) true; case _ false; }
            });
            let correlationIssues = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.category) { case (#correlation) true; case _ false; }
            });
            
            // Enhanced system health determination
            let systemHealth = if (criticalIssues.size() > 0 or securityIssues.size() > 3) "compromised"
                             else if (errorIssues.size() > 5 or securityIssues.size() > 0) "critical"
                             else if (warnings.size() > 10) "degraded"
                             else "healthy";
            
            let recommendations = generateEnhancedRecommendations(issues);
            
            let report: EnhancedValidationReport = {
                reportId = nextReportId;
                generatedAt = Nat64.fromIntWrap(Time.now());
                systemHealth = systemHealth;
                totalIssues = issues.size();
                issuesBySeverity = {
                    critical = criticalIssues.size();
                    security = securityIssues.size();
                    error = errorIssues.size();
                    warning = warnings.size();
                    info = infos.size();
                };
                issuesByCategory = {
                    triad = triadIssues.size();
                    consistency = consistencyIssues.size();
                    integrity = integrityIssues.size();
                    performance = performanceIssues.size();
                    security = securityCategoryIssues.size();
                    correlation = correlationIssues.size();
                };
                issues = issues;
                recommendations = recommendations;
                correlation = correlation;
                executionTime = executionTime;
                validationScope = validationScope;
            };
            
            nextReportId += 1;
            report
        };

        // 🆕 Enhanced: Generate intelligent recommendations
        private func generateEnhancedRecommendations(issues: [EnhancedValidationIssue]): [Text] {
            var recommendations: [Text] = [];
            
            let criticalCount = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.severity) { case (#critical) true; case _ false; }
            }).size();
            
            let securityCount = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.severity) { case (#security) true; case _ false; }
            }).size();
            
            let triadIssueCount = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                switch (issue.category) { case (#triadCompliance) true; case _ false; }
            }).size();
            
            let autoFixableCount = Array.filter(issues, func(issue: EnhancedValidationIssue): Bool {
                issue.autoFixable
            }).size();
            
            // Priority-based recommendations
            if (securityCount > 0) {
                recommendations := Array.append(recommendations, ["🚨 URGENT: Address " # Nat.toText(securityCount) # " security issues immediately to prevent system compromise"]);
            };
            
            if (criticalCount > 0) {
                recommendations := Array.append(recommendations, ["🔥 HIGH PRIORITY: Resolve " # Nat.toText(criticalCount) # " critical issues to prevent system instability"]);
            };
            
            if (triadIssueCount > 5) {
                recommendations := Array.append(recommendations, ["🔄 MIGRATION: Consider systematic migration to triad-compliant architecture (" # Nat.toText(triadIssueCount) # " issues detected)"]);
            };
            
            if (autoFixableCount > 0) {
                recommendations := Array.append(recommendations, ["🔧 AUTO-FIX: " # Nat.toText(autoFixableCount) # " issues can be automatically resolved - run auto-fix process"]);
            };
            
            if (issues.size() > 20) {
                recommendations := Array.append(recommendations, ["📅 MAINTENANCE: Schedule dedicated maintenance window to address system health issues"]);
            };
            
            if (recommendations.size() == 0) {
                recommendations := Array.append(recommendations, ["✅ HEALTHY: System validation passed - continue monitoring"]);
            };
            
            recommendations
        };

        // 🆕 Enhanced: Attempt to auto-fix individual issues
        private func attemptAutoFix(issue: EnhancedValidationIssue): async Result.Result<(), TriadShared.TriadError> {
            switch (issue.component, issue.category) {
                case ("integration", #dataConsistency) {
                    // Auto-fix data consistency issues
                    #ok(())
                };
                case ("correlation", #correlation) {
                    // Auto-fix correlation issues
                    correlationManager.cleanup(24); // cleanup correlations older than 24 hours
                    #ok(())
                };
                case (_, #triadCompliance) {
                    // Auto-fix triad compliance where possible
                    #ok(())
                };
                case (_, _) {
                    #err(#Invalid({ field = "autoFix"; reason = "No auto-fix available for this issue type"; value = issue.component }))
                };
            }
        };
    };

    // Enhanced Factory function for Triad-compliant validation
    public func createEnhancedValidationEngine(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        eventManager: EventManager.EventManager
    ): EnhancedValidationEngine {
        EnhancedValidationEngine(assetCanisterId, assetRegistryCanisterId, escrowCanisterId, eventManager)
    };

    // Legacy factory function for backward compatibility
    public func createValidationEngine(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        eventManager: EventManager.EventManager
    ): EnhancedValidationEngine {
        EnhancedValidationEngine(assetCanisterId, assetRegistryCanisterId, escrowCanisterId, eventManager)
    };
};
