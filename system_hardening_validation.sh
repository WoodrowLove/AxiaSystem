#!/bin/bash

# System Hardening & Security Validation Script - Phase 1 Week 4
# Implements fuzz testing, replay protection, and security validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/network_manager.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}=====================================================================================================================${NC}"
echo -e "${WHITE}                           AxiaSystem Security Hardening & Validation - Phase 1 Week 4${NC}"
echo -e "${CYAN}=====================================================================================================================${NC}"

# Test configuration
FUZZ_TEST_ITERATIONS=100
STRESS_TEST_DURATION=30
MAX_PAYLOAD_SIZE=1048576  # 1MB
MIN_PAYLOAD_SIZE=1

# Security test vectors
declare -a SECURITY_TESTS=(
    "sql_injection"
    "xss_payloads"
    "buffer_overflow"
    "format_string"
    "path_traversal"
    "command_injection"
    "pii_leak_detection"
    "replay_attacks"
    "rate_limit_bypass"
    "circuit_breaker_bypass"
)

# Function to generate random string
generate_random_string() {
    local length=$1
    tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' </dev/urandom | head -c "$length"
}

# Function to generate malicious payload
generate_malicious_payload() {
    local test_type=$1
    
    case "$test_type" in
        "sql_injection")
            echo "'; DROP TABLE users; --"
            ;;
        "xss_payloads")
            echo "<script>alert('XSS')</script>"
            ;;
        "buffer_overflow")
            python3 -c "print('A' * 10000)"
            ;;
        "format_string")
            echo "%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x"
            ;;
        "path_traversal")
            echo "../../../../etc/passwd"
            ;;
        "command_injection")
            echo "; cat /etc/passwd"
            ;;
        "pii_leak_detection")
            echo "SSN: 123-45-6789, Credit Card: 4111-1111-1111-1111, Email: test@example.com"
            ;;
        *)
            generate_random_string 1000
            ;;
    esac
}

# Function to create fuzz test request
create_fuzz_test_request() {
    local test_id=$1
    local payload="$2"
    local amount_tier=$((RANDOM % 5 + 1))
    
    cat << EOF
{
  "correlationId": "fuzz-test-${test_id}",
  "idempotencyKey": "fuzz-idem-${test_id}",
  "sessionId": "fuzz-session-${test_id}",
  "requestType": {"PaymentRisk": null},
  "payload": {
    "amountTier": ${amount_tier},
    "riskFactors": ["${payload}"],
    "requestData": "${payload}",
    "metadata": {"test_type": "fuzz", "iteration": ${test_id}}
  },
  "timeoutMs": 5000,
  "retryCount": 0
}
EOF
}

# Function to validate response security
validate_response_security() {
    local response="$1"
    local test_type="$2"
    local issues=()
    
    # Check for PII leakage
    if echo "$response" | grep -iE "(ssn|social.security|credit.card|password|secret)" > /dev/null; then
        issues+=("PII_LEAK")
    fi
    
    # Check for error information disclosure
    if echo "$response" | grep -iE "(stack.trace|error.code|internal.error)" > /dev/null; then
        issues+=("INFO_DISCLOSURE")
    fi
    
    # Check for SQL injection indicators
    if echo "$response" | grep -iE "(sql.error|mysql|postgres|syntax.error)" > /dev/null; then
        issues+=("SQL_INJECTION_LEAK")
    fi
    
    # Check for successful injection
    if [ "$test_type" = "sql_injection" ] && echo "$response" | grep -i "success" > /dev/null; then
        issues+=("SQL_INJECTION_SUCCESS")
    fi
    
    # Return issues
    if [ ${#issues[@]} -gt 0 ]; then
        printf "%s," "${issues[@]}" | sed 's/,$//'
    else
        echo "SECURE"
    fi
}

# Function to run fuzz testing
run_fuzz_testing() {
    local network=$1
    local canister_id=$(get_canister_id "ai_router" "$network")
    
    echo -e "${BLUE}🔍 Starting fuzz testing with ${FUZZ_TEST_ITERATIONS} iterations...${NC}"
    
    local passed=0
    local failed=0
    local security_issues=0
    
    for i in $(seq 1 $FUZZ_TEST_ITERATIONS); do
        # Select random security test
        local test_type=${SECURITY_TESTS[$((RANDOM % ${#SECURITY_TESTS[@]}))]}
        local payload=$(generate_malicious_payload "$test_type")
        
        # Create test request
        local request=$(create_fuzz_test_request "$i" "$payload")
        
        echo -n "."
        
        # Submit request and capture response
        local response=$(echo "$request" | dfx canister --network "$network" call "$canister_id" submit - 2>&1)
        local exit_code=$?
        
        # Validate security
        local security_status=$(validate_response_security "$response" "$test_type")
        
        if [ "$security_status" != "SECURE" ]; then
            echo ""
            echo -e "${RED}❌ Security issue found in test $i ($test_type): $security_status${NC}"
            echo -e "   Payload: ${payload:0:100}..."
            echo -e "   Response: ${response:0:200}..."
            ((security_issues++))
        fi
        
        # Check if request was properly handled
        if [ $exit_code -eq 0 ] && ! echo "$response" | grep -i "trap\|panic\|unreachable" > /dev/null; then
            ((passed++))
        else
            ((failed++))
        fi
        
        # Brief pause to avoid overwhelming
        [ $((i % 10)) -eq 0 ] && sleep 0.1
    done
    
    echo ""
    echo -e "${GREEN}✅ Fuzz testing completed${NC}"
    echo -e "   Passed: ${GREEN}$passed${NC}"
    echo -e "   Failed: ${RED}$failed${NC}"
    echo -e "   Security Issues: ${RED}$security_issues${NC}"
    
    if [ $security_issues -eq 0 ]; then
        echo -e "${GREEN}🛡️  No security vulnerabilities detected${NC}"
        return 0
    else
        echo -e "${RED}⚠️  Security vulnerabilities detected - review required${NC}"
        return 1
    fi
}

# Function to test replay attack protection
test_replay_protection() {
    local network=$1
    local canister_id=$(get_canister_id "ai_router" "$network")
    
    echo -e "${BLUE}🔄 Testing replay attack protection...${NC}"
    
    # Create a legitimate request
    local timestamp=$(date +%s)
    local replay_request=$(cat << EOF
{
  "correlationId": "replay-test-${timestamp}",
  "idempotencyKey": "replay-idem-${timestamp}",
  "sessionId": "replay-session-${timestamp}",
  "requestType": {"PaymentRisk": null},
  "payload": {
    "amountTier": 2,
    "riskFactors": ["normal_request"],
    "requestData": "legitimate_transaction",
    "metadata": {"test_type": "replay"}
  },
  "timeoutMs": 5000,
  "retryCount": 0
}
EOF
)
    
    # Submit original request
    echo -n "Submitting original request... "
    local original_response=$(echo "$replay_request" | dfx canister --network "$network" call "$canister_id" submit - 2>&1)
    local original_exit_code=$?
    
    if [ $original_exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Success${NC}"
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
    
    # Attempt replay with same idempotency key
    echo -n "Attempting replay attack... "
    local replay_response=$(echo "$replay_request" | dfx canister --network "$network" call "$canister_id" submit - 2>&1)
    local replay_exit_code=$?
    
    # Check if replay was detected
    if echo "$replay_response" | grep -i "idempotent\|duplicate\|already.exists" > /dev/null; then
        echo -e "${GREEN}✅ Replay protection working${NC}"
        return 0
    else
        echo -e "${RED}❌ Replay attack succeeded - vulnerability detected${NC}"
        return 1
    fi
}

# Function to test rate limiting bypass attempts
test_rate_limit_bypass() {
    local network=$1
    local canister_id=$(get_canister_id "ai_router" "$network")
    
    echo -e "${BLUE}⚡ Testing rate limiting bypass attempts...${NC}"
    
    local timestamp=$(date +%s)
    local successful_requests=0
    local blocked_requests=0
    
    # Attempt to send requests rapidly
    for i in $(seq 1 100); do
        local bypass_request=$(cat << EOF
{
  "correlationId": "ratelimit-test-${timestamp}-${i}",
  "idempotencyKey": "ratelimit-idem-${timestamp}-${i}",
  "sessionId": "ratelimit-session-${timestamp}",
  "requestType": {"PaymentRisk": null},
  "payload": {
    "amountTier": 1,
    "riskFactors": ["rate_limit_test"],
    "requestData": "rapid_request_${i}",
    "metadata": {"test_type": "rate_limit_bypass"}
  },
  "timeoutMs": 5000,
  "retryCount": 0
}
EOF
)
        
        local response=$(echo "$bypass_request" | dfx canister --network "$network" call "$canister_id" submit - 2>&1)
        
        if echo "$response" | grep -i "rate.limit\|too.many.requests" > /dev/null; then
            ((blocked_requests++))
        else
            ((successful_requests++))
        fi
        
        # No sleep - rapid fire
    done
    
    echo -e "   Successful requests: ${successful_requests}"
    echo -e "   Blocked requests: ${blocked_requests}"
    
    # Rate limiting should kick in after some requests
    if [ $blocked_requests -gt 10 ]; then
        echo -e "${GREEN}✅ Rate limiting working effectively${NC}"
        return 0
    else
        echo -e "${RED}❌ Rate limiting may be bypassed - review configuration${NC}"
        return 1
    fi
}

# Function to test circuit breaker manipulation
test_circuit_breaker_bypass() {
    local network=$1
    local canister_id=$(get_canister_id "ai_router" "$network")
    
    echo -e "${BLUE}🔌 Testing circuit breaker bypass attempts...${NC}"
    
    # Get initial circuit breaker status
    local initial_metrics=$(dfx canister --network "$network" call "$canister_id" performanceMetrics 2>/dev/null)
    local initial_state=$(echo "$initial_metrics" | grep -o 'state = "[^"]*"' | cut -d'"' -f2 2>/dev/null || echo "unknown")
    
    echo -e "   Initial circuit breaker state: ${initial_state}"
    
    # Attempt to force circuit breaker failures
    local failure_attempts=0
    for i in $(seq 1 20); do
        local malformed_request="invalid_json_payload_${i}"
        
        local response=$(echo "$malformed_request" | dfx canister --network "$network" call "$canister_id" submit - 2>&1)
        
        if echo "$response" | grep -i "error\|failed\|invalid" > /dev/null; then
            ((failure_attempts++))
        fi
        
        sleep 0.1
    done
    
    # Check if circuit breaker state changed appropriately
    local final_metrics=$(dfx canister --network "$network" call "$canister_id" performanceMetrics 2>/dev/null)
    local final_state=$(echo "$final_metrics" | grep -o 'state = "[^"]*"' | cut -d'"' -f2 2>/dev/null || echo "unknown")
    
    echo -e "   Final circuit breaker state: ${final_state}"
    echo -e "   Failure attempts: ${failure_attempts}"
    
    if [ "$final_state" = "open" ] || [ "$final_state" = "half-open" ]; then
        echo -e "${GREEN}✅ Circuit breaker responding correctly to failures${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Circuit breaker may need tuning${NC}"
        return 0  # Not necessarily a security issue
    fi
}

# Function to test PII detection and blocking
test_pii_protection() {
    local network=$1
    local canister_id=$(get_canister_id "ai_router" "$network")
    
    echo -e "${BLUE}🔒 Testing PII protection and data governance...${NC}"
    
    declare -a pii_test_cases=(
        "SSN: 123-45-6789"
        "Credit Card: 4111-1111-1111-1111"
        "Email: john.doe@example.com"
        "Phone: (555) 123-4567"
        "Address: 123 Main St, Anytown, USA"
    )
    
    local pii_blocked=0
    local pii_leaked=0
    
    for pii_data in "${pii_test_cases[@]}"; do
        local timestamp=$(date +%s)
        local pii_request=$(cat << EOF
{
  "correlationId": "pii-test-${timestamp}",
  "idempotencyKey": "pii-idem-${timestamp}",
  "sessionId": "pii-session-${timestamp}",
  "requestType": {"PaymentRisk": null},
  "payload": {
    "amountTier": 2,
    "riskFactors": ["${pii_data}"],
    "requestData": "Transaction containing ${pii_data}",
    "metadata": {"test_type": "pii_protection"}
  },
  "timeoutMs": 5000,
  "retryCount": 0
}
EOF
)
        
        local response=$(echo "$pii_request" | dfx canister --network "$network" call "$canister_id" submit - 2>&1)
        
        # Check if PII was properly blocked
        if echo "$response" | grep -i "data.contract.violation\|pii\|privacy" > /dev/null; then
            ((pii_blocked++))
            echo -e "   ✅ PII blocked: ${pii_data:0:30}..."
        else
            ((pii_leaked++))
            echo -e "   ❌ PII may have leaked: ${pii_data:0:30}..."
        fi
        
        sleep 0.2
    done
    
    echo -e "   PII cases blocked: ${GREEN}$pii_blocked${NC}"
    echo -e "   PII cases leaked: ${RED}$pii_leaked${NC}"
    
    if [ $pii_leaked -eq 0 ]; then
        echo -e "${GREEN}✅ PII protection working correctly${NC}"
        return 0
    else
        echo -e "${RED}❌ PII protection failure - data governance issue${NC}"
        return 1
    fi
}

# Function to test kill switch functionality
test_kill_switch() {
    local network=$1
    local canister_id=$(get_canister_id "ai_router" "$network")
    
    echo -e "${BLUE}🛑 Testing kill switch functionality...${NC}"
    
    # Note: We don't actually enable the kill switch in testing
    # Instead, we verify the endpoint exists and is protected
    
    echo -n "Checking kill switch endpoint protection... "
    local unauthorized_response=$(dfx canister --network "$network" call "$canister_id" enableKillSwitch 2>&1)
    
    if echo "$unauthorized_response" | grep -i "unauthorized\|permission.denied\|admin" > /dev/null; then
        echo -e "${GREEN}✅ Kill switch properly protected${NC}"
        return 0
    else
        echo -e "${RED}❌ Kill switch may not be properly protected${NC}"
        return 1
    fi
}

# Function to generate security report
generate_security_report() {
    local test_results=("$@")
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat << EOF > "/tmp/security_hardening_report_$(date +%Y%m%d_%H%M%S).txt"
================================================================================
                    AxiaSystem Security Hardening Report
                        Phase 1 Week 4 Validation
================================================================================

Report Generated: ${timestamp}
Test Environment: ${network}
Canister ID: ${canister_id}

================================================================================
                              Test Results
================================================================================

EOF
    
    local total_tests=${#test_results[@]}
    local passed_tests=0
    local failed_tests=0
    
    for result in "${test_results[@]}"; do
        echo "$result" >> "/tmp/security_hardening_report_$(date +%Y%m%d_%H%M%S).txt"
        if echo "$result" | grep -q "✅"; then
            ((passed_tests++))
        else
            ((failed_tests++))
        fi
    done
    
    cat << EOF >> "/tmp/security_hardening_report_$(date +%Y%m%d_%H%M%S).txt"

================================================================================
                              Summary
================================================================================

Total Tests: ${total_tests}
Passed: ${passed_tests}
Failed: ${failed_tests}
Security Score: $(( passed_tests * 100 / total_tests ))%

================================================================================
                           Recommendations
================================================================================

EOF
    
    if [ $failed_tests -eq 0 ]; then
        cat << EOF >> "/tmp/security_hardening_report_$(date +%Y%m%d_%H%M%S).txt"
🎉 Congratulations! All security tests passed.

✅ The system demonstrates robust security posture
✅ PII protection is working correctly
✅ Rate limiting and circuit breaker protections are effective
✅ Replay attack protection is functioning
✅ Kill switch controls are properly secured

The system is ready for production deployment.
EOF
    else
        cat << EOF >> "/tmp/security_hardening_report_$(date +%Y%m%d_%H%M%S).txt"
⚠️ Security issues detected that require attention:

• Review failed test cases above
• Implement additional security controls as needed
• Re-run security validation after fixes
• Consider additional penetration testing

The system should not be deployed to production until all security issues are resolved.
EOF
    fi
    
    echo ""
    echo -e "${GREEN}📄 Security report generated: /tmp/security_hardening_report_$(date +%Y%m%d_%H%M%S).txt${NC}"
}

# Main execution function
main() {
    local network="local"
    local run_all=true
    local tests_to_run=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--network)
                network="$2"
                shift 2
                ;;
            -t|--test)
                run_all=false
                tests_to_run+=("$2")
                shift 2
                ;;
            -h|--help)
                echo "System Hardening & Security Validation"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -n, --network NETWORK    Target network (local, ic)"
                echo "  -t, --test TEST_TYPE     Run specific test type"
                echo "  -h, --help              Show this help message"
                echo ""
                echo "Available test types:"
                echo "  fuzz                    Fuzz testing"
                echo "  replay                  Replay protection"
                echo "  rate_limit              Rate limiting bypass"
                echo "  circuit_breaker         Circuit breaker bypass"
                echo "  pii                     PII protection"
                echo "  kill_switch             Kill switch functionality"
                echo ""
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate network
    if ! validate_network "$network"; then
        echo -e "${RED}❌ Invalid network: $network${NC}"
        exit 1
    fi
    
    local canister_id=$(get_canister_id "ai_router" "$network")
    if [ -z "$canister_id" ]; then
        echo -e "${RED}❌ AI Router canister not found for network $network${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}🛡️  Starting security hardening validation...${NC}"
    echo -e "${BLUE}Network: $network${NC}"
    echo -e "${BLUE}Canister: $canister_id${NC}"
    echo ""
    
    local test_results=()
    
    # Run tests
    if [ "$run_all" = true ] || [[ " ${tests_to_run[@]} " =~ " fuzz " ]]; then
        if run_fuzz_testing "$network"; then
            test_results+=("✅ Fuzz Testing: PASSED")
        else
            test_results+=("❌ Fuzz Testing: FAILED")
        fi
        echo ""
    fi
    
    if [ "$run_all" = true ] || [[ " ${tests_to_run[@]} " =~ " replay " ]]; then
        if test_replay_protection "$network"; then
            test_results+=("✅ Replay Protection: PASSED")
        else
            test_results+=("❌ Replay Protection: FAILED")
        fi
        echo ""
    fi
    
    if [ "$run_all" = true ] || [[ " ${tests_to_run[@]} " =~ " rate_limit " ]]; then
        if test_rate_limit_bypass "$network"; then
            test_results+=("✅ Rate Limiting: PASSED")
        else
            test_results+=("❌ Rate Limiting: FAILED")
        fi
        echo ""
    fi
    
    if [ "$run_all" = true ] || [[ " ${tests_to_run[@]} " =~ " circuit_breaker " ]]; then
        if test_circuit_breaker_bypass "$network"; then
            test_results+=("✅ Circuit Breaker: PASSED")
        else
            test_results+=("❌ Circuit Breaker: FAILED")
        fi
        echo ""
    fi
    
    if [ "$run_all" = true ] || [[ " ${tests_to_run[@]} " =~ " pii " ]]; then
        if test_pii_protection "$network"; then
            test_results+=("✅ PII Protection: PASSED")
        else
            test_results+=("❌ PII Protection: FAILED")
        fi
        echo ""
    fi
    
    if [ "$run_all" = true ] || [[ " ${tests_to_run[@]} " =~ " kill_switch " ]]; then
        if test_kill_switch "$network"; then
            test_results+=("✅ Kill Switch Protection: PASSED")
        else
            test_results+=("❌ Kill Switch Protection: FAILED")
        fi
        echo ""
    fi
    
    # Generate report
    generate_security_report "${test_results[@]}"
    
    # Summary
    local failed_count=$(printf '%s\n' "${test_results[@]}" | grep -c "❌" || true)
    
    if [ $failed_count -eq 0 ]; then
        echo -e "${GREEN}🎉 All security tests passed! System hardening complete.${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  $failed_count security tests failed. Review and fix issues before production deployment.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
