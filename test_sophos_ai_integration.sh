#!/bin/bash

# AI Router Integration Test Suite
# Validates the complete sophos_ai integration setup
# Run after deploying AI Router and Communication Bridge

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_TIMEOUT=30
CANISTER_ID=""
SESSION_ID=""
CORRELATION_ID=""

echo -e "${BLUE}🧠 AI Router Integration Test Suite${NC}"
echo "=================================="
echo "Testing complete sophos_ai integration"
echo ""

# Function to print test results
print_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        return 1
    fi
}

# Function to print test section
print_section() {
    echo ""
    echo -e "${YELLOW}📋 $1${NC}"
    echo "----------------------------------------"
}

# Function to check if canister is running
check_canister_running() {
    echo "Checking if AI Router canister is deployed..."
    
    # Try to get canister status
    if dfx canister status ai_router_actor &>/dev/null; then
        CANISTER_ID=$(dfx canister id ai_router_actor)
        echo "✅ AI Router canister found: $CANISTER_ID"
        return 0
    else
        echo "❌ AI Router canister not found"
        return 1
    fi
}

# Function to deploy canisters if needed
deploy_canisters() {
    echo "AI Router canister already deployed, getting ID..."
    
    CANISTER_ID=$(dfx canister id ai_router_actor)
    echo "✅ AI Router canister ID: $CANISTER_ID"
}

# Test 1: Canister Health Check
test_health_check() {
    echo "Testing health check endpoint..."
    
    local result=$(dfx canister call ai_router_actor healthCheck '()' --type=idl 2>/dev/null)
    
    if [[ $result == *"status"* ]] && [[ $result == *"timestamp"* ]]; then
        echo "Health check response: $result"
        return 0
    else
        echo "Invalid health check response: $result"
        return 1
    fi
}

# Test 2: Initialize Router
test_initialize_router() {
    echo "Testing router initialization..."
    
    local result=$(dfx canister call ai_router_actor initializeRouter '()' --type=idl 2>/dev/null)
    
    if [[ $result == *"ok"* ]]; then
        echo "Router initialized successfully"
        return 0
    else
        echo "Router initialization failed: $result"
        return 1
    fi
}

# Test 3: Create Session
test_create_session() {
    echo "Testing session creation..."
    
    local principal_id=$(dfx identity get-principal)
    local permissions='vec { "ai:submit"; "ai:deliver"; "ai:poll" }'
    
    local result=$(dfx canister call ai_router_actor createSession "(\"$principal_id\", $permissions)" --type=idl 2>/dev/null)
    
    if [[ $result == *"ok"* ]]; then
        # Extract session ID from result
        SESSION_ID=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
        echo "Session created successfully: $SESSION_ID"
        return 0
    else
        echo "Session creation failed: $result"
        return 1
    fi
}

# Test 4: Submit AI Message
test_submit_message() {
    echo "Testing message submission..."
    
    if [[ -z "$SESSION_ID" ]]; then
        echo "❌ No session ID available"
        return 1
    fi
    
    # Create test message with proper Candid syntax
    local message='(record {
        id = "test_msg_001";
        correlationId = "test_corr_001";
        messageType = variant { IntelligenceRequest };
        payload = record {
            contentType = "application/json";
            data = blob "test data";
            encoding = "utf-8";
            compression = null;
        };
        priority = variant { Normal };
        timestamp = 1640995200000000000 : int;
        securityContext = record {
            principalId = "test_principal";
            permissions = vec { "ai:request" };
            encryptionKey = null;
            signature = null;
            timestamp = 1640995200000000000 : int;
        };
        metadata = vec {};
    })'
    
    local result=$(dfx canister call ai_router_actor submit "$message, \"$SESSION_ID\"" --type=idl 2>&1)
    
    echo "Debug: Submit result: $result"
    
    if [[ $result == *"ok"* ]]; then
        # Extract correlation ID from result
        CORRELATION_ID=$(echo "$result" | grep -o '"[^"]*"' | head -1 | tr -d '"')
        echo "Message submitted successfully: $CORRELATION_ID"
        return 0
    else
        echo "Message submission failed: $result"
        return 1
    fi
}

# Test 5: Poll for Response
test_poll_response() {
    echo "Testing response polling..."
    
    if [[ -z "$CORRELATION_ID" ]]; then
        echo "❌ No correlation ID available"
        return 1
    fi
    
    local result=$(dfx canister call ai_router_actor poll "(\"$CORRELATION_ID\")" --type=idl 2>/dev/null)
    
    # Response might be null since we haven't delivered one yet
    if [[ $result == *"null"* ]] || [[ $result == *"opt"* ]]; then
        echo "Poll response: $result (expected null/empty)"
        return 0
    else
        echo "Unexpected poll response: $result"
        return 1
    fi
}

# Test 6: Deliver Response
test_deliver_response() {
    echo "Testing response delivery..."
    
    if [[ -z "$SESSION_ID" ]] || [[ -z "$CORRELATION_ID" ]]; then
        echo "❌ Missing session ID or correlation ID"
        return 1
    fi
    
    # Create test response
    local response='{
        correlationId = "'$CORRELATION_ID'";
        responseType = variant { IntelligenceResponse };
        payload = {
            contentType = "application/json";
            data = blob "{\\"analysis\\": \\"test analysis complete\\", \\"confidence\\": 0.95}";
            encoding = "utf-8";
            compression = null;
        };
        status = variant { Success };
        timestamp = 1640995200000000000 : int;
        processingTime = 0.15;
        metadata = vec {};
    }'
    
    local result=$(dfx canister call ai_router_actor deliver "($response, \"$SESSION_ID\")" --type=idl 2>/dev/null)
    
    if [[ $result == *"ok"* ]]; then
        echo "Response delivered successfully"
        return 0
    else
        echo "Response delivery failed: $result"
        return 1
    fi
}

# Test 7: Poll for Delivered Response
test_poll_delivered_response() {
    echo "Testing poll for delivered response..."
    
    if [[ -z "$CORRELATION_ID" ]]; then
        echo "❌ No correlation ID available"
        return 1
    fi
    
    local result=$(dfx canister call ai_router_actor poll "(\"$CORRELATION_ID\")" --type=idl 2>/dev/null)
    
    if [[ $result == *"opt"* ]] && [[ $result == *"correlationId"* ]]; then
        echo "Successfully retrieved delivered response"
        return 0
    else
        echo "Failed to retrieve delivered response: $result"
        return 1
    fi
}

# Test 8: Pull Messages (sophos_ai simulation)
test_pull_messages() {
    echo "Testing message pulling (sophos_ai mode)..."
    
    if [[ -z "$SESSION_ID" ]]; then
        echo "❌ No session ID available"
        return 1
    fi
    
    local result=$(dfx canister call ai_router_actor pullMessages "(\"$SESSION_ID\", opt (5 : nat))" --type=idl 2>/dev/null)
    
    if [[ $result == *"ok"* ]]; then
        echo "Message pull successful: $result"
        return 0
    else
        echo "Message pull failed: $result"
        return 1
    fi
}

# Test 9: Router Status
test_router_status() {
    echo "Testing router status..."
    
    local result=$(dfx canister call ai_router_actor getRouterStatus '()' --type=idl 2>/dev/null)
    
    if [[ $result == *"activeMessages"* ]] && [[ $result == *"queuedMessages"* ]]; then
        echo "Router status: $result"
        return 0
    else
        echo "Invalid router status: $result"
        return 1
    fi
}

# Test 10: Configuration Management
test_configuration() {
    echo "Testing configuration management..."
    
    # Get current config
    local current_config=$(dfx canister call ai_router_actor getConfig '()' --type=idl 2>/dev/null)
    
    if [[ $current_config == *"maxConcurrentMessages"* ]]; then
        echo "Configuration retrieved successfully"
        
        # Test config update
        local new_config='{
            maxConcurrentMessages = 500 : nat;
            sessionTimeout = 7200 : int;
            rateLimitPerSession = 50 : nat;
            enablePushNotifications = true;
            enablePullPolling = true;
            batchSize = 5 : nat;
            retryAttempts = 2 : nat;
        }'
        
        local update_result=$(dfx canister call ai_router_actor updateConfig "($new_config)" --type=idl 2>/dev/null)
        
        if [[ $update_result == *"ok"* ]]; then
            echo "Configuration updated successfully"
            return 0
        else
            echo "Configuration update failed: $update_result"
            return 1
        fi
    else
        echo "Failed to retrieve configuration: $current_config"
        return 1
    fi
}

# Test 11: Session Management
test_session_management() {
    echo "Testing session management..."
    
    # Get active sessions
    local sessions=$(dfx canister call ai_router_actor getActiveSessions '()' --type=idl 2>/dev/null)
    
    if [[ $sessions == *"vec"* ]]; then
        echo "Active sessions retrieved: $sessions"
        
        # Test session cleanup
        local cleanup_result=$(dfx canister call ai_router_actor cleanupExpiredSessions '()' --type=idl 2>/dev/null)
        
        if [[ $cleanup_result =~ ^[0-9]+$ ]] || [[ $cleanup_result == *"("*")"* ]]; then
            echo "Session cleanup completed: $cleanup_result sessions cleaned"
            return 0
        else
            echo "Session cleanup failed: $cleanup_result"
            return 1
        fi
    else
        echo "Failed to retrieve active sessions: $sessions"
        return 1
    fi
}

# Test 12: Error Handling
test_error_handling() {
    echo "Testing error handling..."
    
    # Test with invalid session
    local invalid_session_result=$(dfx canister call ai_router_actor submit '({
        id = "test_error";
        correlationId = "test_error_corr";
        messageType = variant { IntelligenceRequest };
        payload = {
            contentType = "application/json";
            data = blob "test";
            encoding = "utf-8";
            compression = null;
        };
        priority = variant { Normal };
        timestamp = 1640995200000000000 : int;
        securityContext = {
            principalId = "test";
            permissions = vec {};
            encryptionKey = null;
            signature = null;
            timestamp = 1640995200000000000 : int;
        };
        metadata = vec {};
    }, "invalid_session_id")' --type=idl 2>/dev/null)
    
    if [[ $invalid_session_result == *"err"* ]] && [[ $invalid_session_result == *"Invalid session"* ]]; then
        echo "Error handling working correctly: invalid session rejected"
        return 0
    else
        echo "Error handling failed: $invalid_session_result"
        return 1
    fi
}

# Test 13: Performance and Load
test_performance() {
    echo "Testing basic performance..."
    
    if [[ -z "$SESSION_ID" ]]; then
        echo "❌ No session ID available"
        return 1
    fi
    
    local start_time=$(date +%s%N)
    
    # Submit multiple messages quickly
    for i in {1..5}; do
        local message='{
            id = "perf_test_'$i'";
            correlationId = "perf_corr_'$i'";
            messageType = variant { IntelligenceRequest };
            payload = {
                contentType = "application/json";
                data = blob "test_'$i'";
                encoding = "utf-8";
                compression = null;
            };
            priority = variant { Normal };
            timestamp = 1640995200000000000 : int;
            securityContext = {
                principalId = "perf_test";
                permissions = vec { "ai:request" };
                encryptionKey = null;
                signature = null;
                timestamp = 1640995200000000000 : int;
            };
            metadata = vec {};
        }'
        
        dfx canister call ai_router_actor submit "($message, \"$SESSION_ID\")" --type=idl &>/dev/null
    done
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    echo "Performance test completed: 5 messages in ${duration}ms"
    
    if [[ $duration -lt 5000 ]]; then # Less than 5 seconds
        return 0
    else
        echo "Performance test failed: took too long"
        return 1
    fi
}

# Test 14: AI Communication Bridge Integration
test_communication_bridge() {
    echo "Testing AI Communication Bridge integration..."
    
    # Test message validation
    local validation_test=$(dfx canister call ai_router_actor submit '({
        id = "";
        correlationId = "";
        messageType = variant { IntelligenceRequest };
        payload = {
            contentType = "";
            data = blob "";
            encoding = "";
            compression = null;
        };
        priority = variant { Normal };
        timestamp = 0 : int;
        securityContext = {
            principalId = "";
            permissions = vec {};
            encryptionKey = null;
            signature = null;
            timestamp = 0 : int;
        };
        metadata = vec {};
    }, "'$SESSION_ID'")' --type=idl 2>/dev/null)
    
    if [[ $validation_test == *"err"* ]] && [[ $validation_test == *"Invalid message"* ]]; then
        echo "Message validation working correctly"
        return 0
    else
        echo "Message validation failed: $validation_test"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting AI Router Integration Tests..."
    echo "Project root: $PROJECT_ROOT"
    echo ""
    
    # Change to project directory
    cd "$PROJECT_ROOT"
    
    # Verify we're in the right place
    if [[ ! -f "dfx.json" ]]; then
        echo "❌ dfx.json not found in $PROJECT_ROOT"
        echo "Please run this script from the AxiaSystem project root"
        exit 1
    fi
    
    local failed_tests=0
    local total_tests=14
    
    print_section "Infrastructure Tests"
    
    # Check if canister is running, deploy if needed
    if ! check_canister_running; then
        deploy_canisters
    fi
    
    # Run tests
    test_health_check && print_result "Health Check" || ((failed_tests++))
    test_initialize_router && print_result "Router Initialization" || ((failed_tests++))
    
    print_section "Session Management Tests"
    test_create_session && print_result "Session Creation" || ((failed_tests++))
    test_session_management && print_result "Session Management" || ((failed_tests++))
    
    print_section "Message Processing Tests"
    test_submit_message && print_result "Message Submission" || ((failed_tests++))
    test_poll_response && print_result "Response Polling" || ((failed_tests++))
    test_deliver_response && print_result "Response Delivery" || ((failed_tests++))
    test_poll_delivered_response && print_result "Poll Delivered Response" || ((failed_tests++))
    test_pull_messages && print_result "Message Pulling" || ((failed_tests++))
    
    print_section "System Management Tests"
    test_router_status && print_result "Router Status" || ((failed_tests++))
    test_configuration && print_result "Configuration Management" || ((failed_tests++))
    
    print_section "Robustness Tests"
    test_error_handling && print_result "Error Handling" || ((failed_tests++))
    test_performance && print_result "Performance Test" || ((failed_tests++))
    test_communication_bridge && print_result "Communication Bridge" || ((failed_tests++))
    
    # Final results
    echo ""
    echo "=================================="
    local passed_tests=$((total_tests - failed_tests))
    
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed! ($passed_tests/$total_tests)${NC}"
        echo -e "${GREEN}✅ AI Router is ready for sophos_ai integration${NC}"
        
        echo ""
        echo -e "${BLUE}🔗 Integration Information:${NC}"
        echo "Canister ID: $CANISTER_ID"
        echo "Session ID: $SESSION_ID"
        echo "Test Correlation ID: $CORRELATION_ID"
        echo ""
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "1. Deploy sophos_ai with the provided Rust integration code"
        echo "2. Configure sophos_ai with canister ID: $CANISTER_ID"
        echo "3. Test end-to-end communication"
        echo "4. Monitor performance and adjust configuration as needed"
        
    else
        echo -e "${RED}❌ Tests failed: $failed_tests/$total_tests${NC}"
        echo -e "${RED}🔧 Please review the failed tests and fix issues before proceeding${NC}"
        exit 1
    fi
}

# Run the tests
main "$@"
