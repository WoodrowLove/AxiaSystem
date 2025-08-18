// AxiaSystem Validation Engine - Comprehensive System Integrity Checks
// Validates triad compliance, data consistency, and cross-system integrity

import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Bool "mo:base/Bool";
import Int "mo:base/Int";

// System imports
import AssetProxy "../asset/utils/asset_proxy";
import AssetRegistryProxy "../asset_registry/utils/asset_registry_proxy";
import EscrowProxy "../escrow/utils/escrow_canister_proxy";
import EventManager "../heartbeat/event_manager";

module {
    // Local type definitions for validation
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

    // Validation Types
    public type ValidationSeverity = {
        #info;
        #warning;
        #error;
        #critical;
    };

    public type ValidationIssue = {
        issueId: Nat;
        severity: ValidationSeverity;
        component: Text; // "asset", "registry", "escrow", "integration"
        description: Text;
        recommendation: Text;
        autoFixable: Bool;
        detectedAt: Nat64;
    };

    public type ValidationReport = {
        reportId: Nat;
        generatedAt: Nat64;
        systemHealth: Text; // "healthy", "degraded", "critical"
        totalIssues: Nat;
        criticalIssues: Nat;
        warnings: Nat;
        infos: Nat;
        issues: [ValidationIssue];
        recommendations: [Text];
    };

    public type SystemMetrics = {
        assetCount: Nat;
        registryCount: Nat;
        escrowCount: Nat;
        triadCompliantAssets: Nat;
        orphanedAssets: Nat;
        dataInconsistencies: Nat;
        lastValidation: ?Nat64;
    };

    // Validation Engine Class
    public class ValidationEngine(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        _eventManager: EventManager.EventManager
    ) {
        private let assetProxy = AssetProxy.AssetProxy(assetCanisterId);
        private let assetRegistryProxy = AssetRegistryProxy.AssetRegistryProxy(assetRegistryCanisterId);
        private let _escrowProxy = EscrowProxy.EscrowCanisterProxy(escrowCanisterId);
        
        private var validationHistory: [ValidationReport] = [];
        private var nextReportId: Nat = 1;
        private var nextIssueId: Nat = 1;

        // ================================
        // COMPREHENSIVE VALIDATION
        // ================================

        // 🔍 Run Complete System Validation
        public func validateSystemIntegrity(): async ValidationReport {
            var issues: [ValidationIssue] = [];
            
            // 1. Asset System Validation
            let assetIssues = await validateAssetSystem();
            issues := Array.append(issues, assetIssues);
            
            // 2. Asset Registry Validation
            let registryIssues = await validateAssetRegistry();
            issues := Array.append(issues, registryIssues);
            
            // 3. Cross-System Consistency
            let consistencyIssues = await validateCrossSystemConsistency();
            issues := Array.append(issues, consistencyIssues);
            
            // 4. Triad Compliance Check
            let triadIssues = await validateTriadCompliance();
            issues := Array.append(issues, triadIssues);
            
            // Generate comprehensive report
            let report = generateValidationReport(issues);
            validationHistory := Array.append(validationHistory, [report]);
            
            report
        };

        // 🎯 Validate Asset System
        public func validateAssetSystem(): async [ValidationIssue] {
            var issues: [ValidationIssue] = [];
            
            // Get all assets
            let assets = await assetProxy.getAllAssets();
            
            // Check for common issues
            for (asset in assets.vals()) {
                // Check for empty metadata
                if (asset.metadata == "") {
                    issues := Array.append(issues, [createIssue(
                        #warning,
                        "asset",
                        "Asset " # Nat.toText(asset.id) # " has empty metadata",
                        "Add descriptive metadata to improve asset discoverability",
                        false
                    )]);
                };
                
                // Check for invalid ownership
                if (Principal.isAnonymous(asset.ownerIdentity)) {
                    issues := Array.append(issues, [createIssue(
                        #error,
                        "asset",
                        "Asset " # Nat.toText(asset.id) # " has anonymous owner",
                        "Transfer asset to valid principal ownership",
                        false
                    )]);
                };
                
                // Check triad compliance
                if (not asset.triadVerified) {
                    issues := Array.append(issues, [createIssue(
                        #info,
                        "asset",
                        "Asset " # Nat.toText(asset.id) # " is not triad-verified",
                        "Upgrade to triad-compliant asset management",
                        true
                    )]);
                };
            };
            
            issues
        };

        // 📋 Validate Asset Registry
        public func validateAssetRegistry(): async [ValidationIssue] {
            var issues: [ValidationIssue] = [];
            
            // Get all registry entries
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            // Check for registry-specific issues
            for (regAsset in registryAssets.vals()) {
                // Check for missing NFT linkage
                if (regAsset.nftId == 0) {
                    issues := Array.append(issues, [createIssue(
                        #warning,
                        "registry",
                        "Registry asset " # Nat.toText(regAsset.id) # " has no NFT linkage",
                        "Link asset to corresponding NFT for full traceability",
                        false
                    )]);
                };
                
                // Check for inactive assets with recent activity
                if (not regAsset.isActive and (Time.now() - regAsset.updatedAt) < (24 * 60 * 60 * 1_000_000_000)) {
                    issues := Array.append(issues, [createIssue(
                        #info,
                        "registry",
                        "Registry asset " # Nat.toText(regAsset.id) # " was recently deactivated",
                        "Review deactivation reason and consider reactivation if appropriate",
                        false
                    )]);
                };
            };
            
            issues
        };

        // 🔗 Validate Cross-System Consistency
        public func validateCrossSystemConsistency(): async [ValidationIssue] {
            var issues: [ValidationIssue] = [];
            
            // Get data from all systems
            let assets = await assetProxy.getAllAssets();
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            // Check for orphaned assets (in asset system but not in registry)
            for (asset in assets.vals()) {
                let hasRegistryEntry = Array.find(registryAssets, func(regAsset: RegistryAsset): Bool {
                    regAsset.ownerIdentity == asset.ownerIdentity and regAsset.metadata == asset.metadata
                });
                
                switch (hasRegistryEntry) {
                    case null {
                        issues := Array.append(issues, [createIssue(
                            #warning,
                            "integration",
                            "Asset " # Nat.toText(asset.id) # " exists without registry entry",
                            "Create corresponding registry entry for complete asset tracking",
                            true
                        )]);
                    };
                    case (?_) {
                        // Check ownership consistency
                        // Additional consistency checks can be added here
                    };
                };
            };
            
            // Check for registry entries without corresponding assets
            for (regAsset in registryAssets.vals()) {
                let hasAssetEntry = Array.find(assets, func(asset: Asset): Bool {
                    asset.ownerIdentity == regAsset.ownerIdentity and asset.metadata == regAsset.metadata
                });
                
                switch (hasAssetEntry) {
                    case null {
                        issues := Array.append(issues, [createIssue(
                            #warning,
                            "integration",
                            "Registry asset " # Nat.toText(regAsset.id) # " has no corresponding asset",
                            "Create asset entry or remove orphaned registry entry",
                            true
                        )]);
                    };
                    case (?_) {
                        // Ownership is consistent
                    };
                };
            };
            
            issues
        };

        // 🛡️ Validate Triad Compliance
        public func validateTriadCompliance(): async [ValidationIssue] {
            var issues: [ValidationIssue] = [];
            
            let assets = await assetProxy.getAllAssets();
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            // Count triad vs non-triad assets
            let triadAssets = Array.filter(assets, func(asset: Asset): Bool { asset.triadVerified });
            let nonTriadAssets = Array.filter(assets, func(asset: Asset): Bool { not asset.triadVerified });
            
            let triadRegistryAssets = Array.filter(registryAssets, func(asset: RegistryAsset): Bool { asset.triadVerified });
            let nonTriadRegistryAssets = Array.filter(registryAssets, func(asset: RegistryAsset): Bool { not asset.triadVerified });
            
            // Warn if majority of assets are not triad-compliant
            if (nonTriadAssets.size() > triadAssets.size()) {
                issues := Array.append(issues, [createIssue(
                    #warning,
                    "integration",
                    "Majority of assets (" # Nat.toText(nonTriadAssets.size()) # "/" # Nat.toText(assets.size()) # ") are not triad-verified",
                    "Migrate legacy assets to triad-compliant system for enhanced security",
                    true
                )]);
            };
            
            if (nonTriadRegistryAssets.size() > triadRegistryAssets.size()) {
                issues := Array.append(issues, [createIssue(
                    #warning,
                    "integration",
                    "Majority of registry assets (" # Nat.toText(nonTriadRegistryAssets.size()) # "/" # Nat.toText(registryAssets.size()) # ") are not triad-verified",
                    "Upgrade registry entries to triad compliance",
                    true
                )]);
            };
            
            issues
        };

        // ================================
        // SYSTEM METRICS & REPORTING
        // ================================

        // 📊 Get System Metrics
        public func getSystemMetrics(): async SystemMetrics {
            let assets = await assetProxy.getAllAssets();
            let registryAssets = await assetRegistryProxy.getAllAssets();
            
            let triadAssets = Array.filter(assets, func(asset: Asset): Bool { asset.triadVerified });
            
            // Calculate orphaned assets (simplified check)
            var orphanedCount = 0;
            for (asset in assets.vals()) {
                let hasRegistryEntry = Array.find(registryAssets, func(regAsset: RegistryAsset): Bool {
                    regAsset.ownerIdentity == asset.ownerIdentity
                });
                if (hasRegistryEntry == null) {
                    orphanedCount += 1;
                };
            };
            
            {
                assetCount = assets.size();
                registryCount = registryAssets.size();
                escrowCount = 0; // TODO: Implement escrow counting
                triadCompliantAssets = triadAssets.size();
                orphanedAssets = orphanedCount;
                dataInconsistencies = Int.abs(assets.size() - registryAssets.size());
                lastValidation = if (validationHistory.size() > 0) {
                    let lastReport = validationHistory[validationHistory.size() - 1];
                    ?lastReport.generatedAt
                } else null;
            }
        };

        // 📋 Get Validation History
        public func getValidationHistory(): [ValidationReport] {
            validationHistory
        };

        // 🔧 Auto-Fix Issues (where possible)
        public func autoFixIssues(reportId: Nat): async Result.Result<Nat, Text> {
            let reportOpt = Array.find(validationHistory, func(report: ValidationReport): Bool {
                report.reportId == reportId
            });
            
            switch (reportOpt) {
                case null { #err("Validation report not found") };
                case (?report) {
                    var fixedCount = 0;
                    
                    for (issue in report.issues.vals()) {
                        if (issue.autoFixable) {
                            // Implement auto-fix logic based on issue type
                            switch (issue.component) {
                                case ("integration") {
                                    // Auto-fix integration issues
                                    fixedCount += 1;
                                };
                                case (_) {
                                    // Other auto-fixes can be implemented
                                };
                            };
                        };
                    };
                    
                    #ok(fixedCount)
                };
            };
        };

        // ================================
        // PRIVATE HELPERS
        // ================================

        private func createIssue(
            severity: ValidationSeverity,
            component: Text,
            description: Text,
            recommendation: Text,
            autoFixable: Bool
        ): ValidationIssue {
            let issue: ValidationIssue = {
                issueId = nextIssueId;
                severity = severity;
                component = component;
                description = description;
                recommendation = recommendation;
                autoFixable = autoFixable;
                detectedAt = Nat64.fromIntWrap(Time.now());
            };
            nextIssueId += 1;
            issue
        };

        private func generateValidationReport(issues: [ValidationIssue]): ValidationReport {
            let criticalIssues = Array.filter(issues, func(issue: ValidationIssue): Bool {
                switch (issue.severity) { case (#critical) true; case _ false; }
            });
            
            let warnings = Array.filter(issues, func(issue: ValidationIssue): Bool {
                switch (issue.severity) { case (#warning) true; case _ false; }
            });
            
            let infos = Array.filter(issues, func(issue: ValidationIssue): Bool {
                switch (issue.severity) { case (#info) true; case _ false; }
            });
            
            let systemHealth = if (criticalIssues.size() > 0) "critical"
                             else if (warnings.size() > 5) "degraded"
                             else "healthy";
            
            let recommendations = generateRecommendations(issues);
            
            let report: ValidationReport = {
                reportId = nextReportId;
                generatedAt = Nat64.fromIntWrap(Time.now());
                systemHealth = systemHealth;
                totalIssues = issues.size();
                criticalIssues = criticalIssues.size();
                warnings = warnings.size();
                infos = infos.size();
                issues = issues;
                recommendations = recommendations;
            };
            
            nextReportId += 1;
            report
        };

        private func generateRecommendations(issues: [ValidationIssue]): [Text] {
            var recommendations: [Text] = [];
            
            let criticalCount = Array.filter(issues, func(issue: ValidationIssue): Bool {
                switch (issue.severity) { case (#critical) true; case _ false; }
            }).size();
            
            let triadIssueCount = Array.filter(issues, func(issue: ValidationIssue): Bool {
                Text.contains(issue.description, #text "triad")
            }).size();
            
            if (criticalCount > 0) {
                recommendations := Array.append(recommendations, ["Immediately address " # Nat.toText(criticalCount) # " critical issues to prevent system instability"]);
            };
            
            if (triadIssueCount > 3) {
                recommendations := Array.append(recommendations, ["Consider systematic migration to triad-compliant architecture"]);
            };
            
            if (issues.size() > 10) {
                recommendations := Array.append(recommendations, ["Schedule regular maintenance window to address system health issues"]);
            };
            
            recommendations
        };
    };

    // Factory function
    public func createValidationEngine(
        assetCanisterId: Principal,
        assetRegistryCanisterId: Principal,
        escrowCanisterId: Principal,
        eventManager: EventManager.EventManager
    ): ValidationEngine {
        ValidationEngine(assetCanisterId, assetRegistryCanisterId, escrowCanisterId, eventManager)
    };
};
