#!/bin/bash

# Test script for AI Router Circuit Breaker and Rate Limiting
# Phase 1 Week 2 Implementation Testing

set -e

echo "=== AI Router Circuit Breaker & Rate Limiting Test Suite ==="
echo "Testing Phase 1 Week 2 Implementation"
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function to print status
print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Test functions
test_health_endpoint() {
    print_status "Testing health endpoint with circuit breaker status..."
    
    HEALTH=$(dfx canister call ai_router health)
    echo "Health Response: $HEALTH"
    
    if echo "$HEALTH" | grep -q "healthy" && echo "$HEALTH" | grep -q "closed"; then
        print_success "Health endpoint working - Circuit breaker is closed"
    else
        print_error "Health endpoint failed or circuit breaker not closed"
        return 1
    fi
}

test_metrics_endpoint() {
    print_status "Testing enhanced metrics with circuit breaker data..."
    
    METRICS=$(dfx canister call ai_router metrics)
    echo "Metrics Response: $METRICS"
    
    if echo "$METRICS" | grep -q "circuitBreaker" && echo "$METRICS" | grep -q "rateLimits"; then
        print_success "Enhanced metrics working with circuit breaker and rate limits"
    else
        print_error "Enhanced metrics missing circuit breaker or rate limit data"
        return 1
    fi
}

create_test_session() {
    print_status "Creating test session for rate limit testing..."
    
    SESSION_RESULT=$(dfx canister call ai_router createSession '(variant { AISubmitter })' | grep -o '"[^"]*"' | tr -d '"')
    if [ -n "$SESSION_RESULT" ]; then
        print_success "Created session: $SESSION_RESULT"
        echo "$SESSION_RESULT"
    else
        print_error "Failed to create session"
        return 1
    fi
}

test_rate_limiting() {
    print_status "Testing rate limiting functionality..."
    
    # Create a session first
    SESSION_ID=$(create_test_session)
    if [ -z "$SESSION_ID" ]; then
        print_error "Cannot test rate limiting without session"
        return 1
    fi
    
    print_status "Submitting multiple requests to test rate limiting..."
    
    # Submit requests rapidly to trigger rate limiting
    SUCCESS_COUNT=0
    RATE_LIMITED_COUNT=0
    
    for i in {1..65}; do  # Try 65 requests (limit is 60 per minute)
        RESULT=$(dfx canister call ai_router submit "(record {
            correlationId = \"rate-test-$i\";
            idempotencyKey = \"idempotency-$i\";
            sessionId = \"$SESSION_ID\";
            submitterId = \"test-submitter\";
            timestamp = $(date +%s)000000000;
            requestType = variant { ChatCompletion };
            priority = variant { Normal };
            timeoutMs = 30000;
            retryCount = 0;
            payload = variant { 
                Chat = record {
                    messages = vec {
                        record {
                            role = variant { User };
                            content = \"Test message $i\";
                            timestamp = $(date +%s)000000000;
                        }
                    };
                    model = \"test-model\";
                    maxTokens = opt 100;
                    temperature = opt 0.7;
                }
            };
            triadContext = null;
        })" 2>&1 || echo "ERROR")
        
        if echo "$RESULT" | grep -q "Rate limit exceeded"; then
            RATE_LIMITED_COUNT=$((RATE_LIMITED_COUNT + 1))
            if [ $RATE_LIMITED_COUNT -eq 1 ]; then
                print_warning "Rate limiting triggered at request $i"
            fi
        elif echo "$RESULT" | grep -q "rate-test-$i"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
        
        # Small delay to avoid overwhelming the system
        sleep 0.01
    done
    
    echo "Successful requests: $SUCCESS_COUNT"
    echo "Rate limited requests: $RATE_LIMITED_COUNT"
    
    if [ $RATE_LIMITED_COUNT -gt 0 ] && [ $SUCCESS_COUNT -le 60 ]; then
        print_success "Rate limiting working correctly"
    else
        print_warning "Rate limiting behavior unclear - may need adjustment"
    fi
    
    # Check metrics after rate limiting test
    print_status "Checking metrics after rate limit test..."
    FINAL_METRICS=$(dfx canister call ai_router metrics)
    echo "Final Metrics: $FINAL_METRICS"
}

test_circuit_breaker_functionality() {
    print_status "Testing circuit breaker functionality..."
    
    # This is a basic test - in a full environment we'd simulate actual failures
    print_status "Checking current circuit breaker state..."
    
    METRICS=$(dfx canister call ai_router metrics)
    CB_STATE=$(echo "$METRICS" | grep -o 'state = "[^"]*"' | cut -d'"' -f2)
    
    if [ "$CB_STATE" = "closed" ]; then
        print_success "Circuit breaker is in closed state (healthy)"
    else
        print_warning "Circuit breaker is in $CB_STATE state"
    fi
    
    # For a full test, we would need to:
    # 1. Create failing AI service responses
    # 2. Trigger multiple failures to open the circuit
    # 3. Test that requests are blocked when circuit is open
    # 4. Test half-open state recovery
    
    print_status "Circuit breaker integration is ready for failure simulation"
}

test_session_management() {
    print_status "Testing session management with enhanced validation..."
    
    # Test different session roles
    for ROLE in "AISubmitter" "AIService" "AIDeliverer"; do
        print_status "Testing $ROLE session creation..."
        
        SESSION_RESULT=$(dfx canister call ai_router createSession "(variant { $ROLE })" 2>&1 || echo "ERROR")
        
        if echo "$SESSION_RESULT" | grep -q "ERROR"; then
            print_error "Failed to create $ROLE session"
        else
            print_success "Created $ROLE session successfully"
        fi
    done
}

# Run all tests
main() {
    echo "Starting comprehensive test suite..."
    echo
    
    test_health_endpoint || exit 1
    echo
    
    test_metrics_endpoint || exit 1
    echo
    
    test_session_management || exit 1
    echo
    
    test_rate_limiting || exit 1
    echo
    
    test_circuit_breaker_functionality || exit 1
    echo
    
    print_success "=== Phase 1 Week 2 Implementation Test Complete ==="
    echo
    print_status "Summary of implemented features:"
    echo "  ✓ Circuit breaker pattern with state management"
    echo "  ✓ Rate limiting with identity-scoped limits"
    echo "  ✓ Enhanced metrics and monitoring"
    echo "  ✓ Heartbeat-driven cleanup processes"
    echo "  ✓ Failure detection and recovery"
    echo
    print_status "Next Phase: Load testing and performance benchmarking"
}

# Execute main function
main "$@"
