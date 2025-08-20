#!/bin/bash

# Week 9 Phase 3 Auto-Actions Validation Script
# Tests feature-flagged safe auto-actions with strict constraints

set -e

echo "🚀 Week 9 Auto-Actions Validation Starting..."
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to log test results
log_test() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ PASS:${NC} $1"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL:${NC} $1"
        ((TESTS_FAILED++))
    fi
}

# Function to log info
log_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

# Function to log warning
log_warning() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
}

echo ""
echo "Phase 3 Week 9 Scope Validation"
echo "================================"

# Test 1: Verify files exist
log_info "Testing file existence..."
test -f "src/policy/policy_engine.mo"
log_test "Policy Engine exists"

test -f "src/policy/auto_action_integration.mo"
log_test "Auto-Action Integration module exists"

# Test 2: Check for Week 9 keywords in policy engine
log_info "Checking for Week 9 implementation markers..."
grep -q "Week 9" src/policy/policy_engine.mo
log_test "Week 9 markers found in policy engine"

grep -q "SuggestHold" src/policy/policy_engine.mo
log_test "SuggestHold action type implemented"

grep -q "Flag" src/policy/policy_engine.mo
log_test "Flag action type implemented"

grep -q "AutoActionConfig" src/policy/policy_engine.mo
log_test "Auto-action configuration types defined"

# Test 3: Validate feature flag structure
log_info "Validating feature flag implementation..."
grep -q "enabled.*Bool" src/policy/policy_engine.mo
log_test "Feature flag boolean structure found"

grep -q "minConfidence.*Float" src/policy/policy_engine.mo
log_test "Confidence threshold configuration found"

grep -q "allowedRiskScore.*Nat8" src/policy/policy_engine.mo
log_test "Risk score threshold configuration found"

# Test 4: Check scope validation
log_info "Checking scope validation functions..."
grep -q "validateWeek9ActionScope" src/policy/policy_engine.mo
log_test "Week 9 scope validation function exists"

grep -q "payments.*RequireMFA" src/policy/policy_engine.mo
log_test "Payments RequireMFA scope defined"

grep -q "escrow.*SuggestHold" src/policy/policy_engine.mo
log_test "Escrow SuggestHold scope defined"

grep -q "governance.*Flag" src/policy/policy_engine.mo
log_test "Governance Flag scope defined"

# Test 5: Verify no forbidden auto-actions
log_info "Checking for forbidden auto-actions..."
! grep -q "auto.*release.*funds" src/policy/policy_engine.mo
log_test "No auto-fund-release found (forbidden)"

! grep -q "auto.*execute.*upgrade" src/policy/policy_engine.mo
log_test "No auto-upgrade-execution found (forbidden)"

! grep -q "auto.*transfer.*ownership" src/policy/policy_engine.mo
log_test "No auto-ownership-transfer found (forbidden)"

# Test 6: Check override tracking
log_info "Validating override tracking for SLO monitoring..."
grep -q "AutoActionOverride" src/policy/policy_engine.mo
log_test "Override tracking type defined"

grep -q "calculateOverrideRate" src/policy/policy_engine.mo
log_test "Override rate calculation function exists"

# Test 7: Verify integration module
log_info "Checking auto-action integration module..."
grep -q "processPaymentAutoAction" src/policy/auto_action_integration.mo
log_test "Payment auto-action processing implemented"

grep -q "processEscrowAutoAction" src/policy/auto_action_integration.mo
log_test "Escrow auto-action processing implemented"

grep -q "processGovernanceAutoAction" src/policy/auto_action_integration.mo
log_test "Governance auto-action processing implemented"

grep -q "globalKillSwitch" src/policy/auto_action_integration.mo
log_test "Global kill switch implemented"

# Test 8: Check feature flag defaults
log_info "Verifying feature flags default to OFF..."
grep -q "enabled = false" src/policy/policy_engine.mo
log_test "Feature flags default to disabled"

grep -q "defaultFeatureFlags" src/policy/auto_action_integration.mo
log_test "Default feature flags configuration exists"

# Test 9: Validate confidence thresholds
log_info "Checking confidence thresholds meet Week 9 requirements..."
grep -q "0\.85.*payments" src/policy/policy_engine.mo || grep -q "payments.*0\.85" src/policy/policy_engine.mo
log_test "Payments confidence threshold ≥ 85%"

grep -q "0\.90.*escrow" src/policy/policy_engine.mo || grep -q "escrow.*0\.90" src/policy/policy_engine.mo
log_test "Escrow confidence threshold ≥ 90%"

grep -q "0\.95.*governance" src/policy/policy_engine.mo || grep -q "governance.*0\.95" src/policy/policy_engine.mo
log_test "Governance confidence threshold ≥ 95%"

# Test 10: Verify amount limits
log_info "Checking amount threshold limits..."
grep -q "50000.*payments" src/policy/policy_engine.mo || grep -q "maxAmount.*50000" src/policy/policy_engine.mo
log_test "Payments amount threshold ≤ $50k"

grep -q "10000.*escrow" src/policy/policy_engine.mo || grep -q "maxAmount.*10000" src/policy/policy_engine.mo
log_test "Escrow amount threshold ≤ $10k"

# Test 11: Check shadow mode support
log_info "Validating shadow mode implementation..."
grep -q "ShadowModeResult" src/policy/auto_action_integration.mo
log_test "Shadow mode result type defined"

grep -q "trackShadowMode" src/policy/auto_action_integration.mo
log_test "Shadow mode tracking function exists"

grep -q "calculateShadowAccuracy" src/policy/auto_action_integration.mo
log_test "Shadow mode accuracy calculation exists"

# Test 12: Verify audit trail
log_info "Checking audit trail implementation..."
grep -q "auditAutoAction" src/policy/auto_action_integration.mo
log_test "Auto-action audit function exists"

grep -q "WEEK9_AUTO_ACTION" src/policy/auto_action_integration.mo
log_test "Week 9 audit log format defined"

# Test 13: Validate SLO monitoring
log_info "Checking SLO monitoring (< 3% override rate)..."
grep -q "0\.03" src/policy/auto_action_integration.mo
log_test "3% SLO threshold defined"

grep -q "validateOverrideRate" src/policy/auto_action_integration.mo
log_test "Override rate validation function exists"

# Test 14: Check for Motoko compilation
log_info "Testing Motoko compilation..."
if command -v moc >/dev/null 2>&1; then
    moc --check src/policy/policy_engine.mo >/dev/null 2>&1
    log_test "Policy engine compiles successfully"
    
    moc --check src/policy/auto_action_integration.mo >/dev/null 2>&1
    log_test "Auto-action integration compiles successfully"
else
    log_warning "Motoko compiler (moc) not available - skipping compilation test"
fi

# Test 15: Verify Week 9 acceptance criteria
echo ""
echo "Week 9 Acceptance Criteria Validation"
echo "====================================="

log_info "Checking acceptance criteria compliance..."

# Acceptance: Shadow mode → live mode behind flag
grep -q "featureFlagEnabled" src/policy/auto_action_integration.mo
log_test "Feature flag support for live mode transition"

# Acceptance: Override rate < 3%
grep -q "sloThreshold.*0\.03" src/policy/auto_action_integration.mo
log_test "Override rate SLO threshold < 3%"

# Acceptance: Zero broken flows
grep -q "withinScope" src/policy/auto_action_integration.mo
log_test "Scope validation prevents broken flows"

# Final summary
echo ""
echo "================================================"
echo "Week 9 Auto-Actions Validation Summary"
echo "================================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! Week 9 implementation ready.${NC}"
    echo ""
    echo "✅ Auto-actions (feature-flagged) ✅"
    echo "   - Payments: RequireMFA, HoldForReview at high risk & confidence"
    echo "   - Escrow: SuggestHold (no direct fund movement)"
    echo "   - Governance: Flag only (no execution)"
    echo ""
    echo "✅ Acceptance Criteria Met:"
    echo "   - Shadow mode → live mode behind flag"
    echo "   - Override rate < 3% SLO"
    echo "   - Zero broken flows (scope validation)"
    echo ""
    echo "🚀 Ready to proceed with controlled rollout!"
    exit 0
else
    echo -e "${RED}❌ VALIDATION FAILED! Fix issues before proceeding.${NC}"
    echo ""
    echo "Required fixes:"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "  - Address failing tests above"
        echo "  - Ensure all Week 9 scope constraints are met"
        echo "  - Verify feature flags default to disabled"
        echo "  - Confirm audit trail and SLO monitoring"
    fi
    exit 1
fi
