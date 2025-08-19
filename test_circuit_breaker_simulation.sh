#!/bin/bash

# Circuit Breaker Failure Simulation Utility
# Simulates AI service failures to test circuit breaker behavior

set -e

echo "=== Circuit Breaker Failure Simulation ==="
echo "This script simulates AI service failures to test circuit breaker opening and recovery"
echo

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[CIRCUIT-BREAKER]${NC} $1"
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

# Get current circuit breaker status
get_cb_status() {
    local health=$(dfx canister call ai_router health)
    local cb_state=$(echo "$health" | grep -o 'circuitBreaker = "[^"]*"' | cut -d'"' -f2)
    echo "$cb_state"
}

# Get detailed performance metrics
get_performance_metrics() {
    dfx canister call ai_router performanceMetrics
}

# Create test session
create_test_session() {
    local result=$(dfx canister call ai_router createSession '(variant { AISubmitter })' 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' || echo "")
    echo "$result"
}

# Simulate AI service delivering a failed response
simulate_ai_service_failure() {
    local correlation_id="$1"
    local error_message="$2"
    
    # Create AI service session first
    local ai_service_session=$(dfx canister call ai_router createSession '(variant { AIService })' 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' || echo "")
    
    if [ -z "$ai_service_session" ]; then
        echo "ERROR: Could not create AI service session"
        return 1
    fi
    
    # Deliver a failure response
    local result=$(dfx canister call ai_router deliver "(
        \"$correlation_id\",
        record {
            correlationId = \"$correlation_id\";
            requestId = \"req-$correlation_id\";
            submitterId = \"ai-service\";
            timestamp = $(date +%s)000000000;
            status = variant { Failed = \"$error_message\" };
            payload = variant { 
                Error = record {
                    code = \"PROCESSING_FAILED\";
                    message = \"$error_message\";
                    details = opt \"Simulated failure for circuit breaker testing\";
                }
            };
            metadata = record {
                processingTimeMs = 1000;
                modelUsed = \"test-model\";
                tokensUsed = opt 0;
            };
        }
    )" 2>&1 || echo "ERROR")
    
    echo "$result"
}

# Main circuit breaker test sequence
main() {
    print_status "Starting circuit breaker failure simulation..."
    
    # Step 1: Check initial state
    print_status "Step 1: Checking initial circuit breaker state"
    local initial_state=$(get_cb_status)
    echo "Initial circuit breaker state: $initial_state"
    
    if [ "$initial_state" != "closed" ]; then
        print_warning "Circuit breaker is not in closed state. Waiting for reset..."
        sleep 70  # Wait for potential reset
        initial_state=$(get_cb_status)
        echo "Circuit breaker state after wait: $initial_state"
    fi
    
    # Step 2: Create test session
    print_status "Step 2: Creating test session"
    local session_id=$(create_test_session)
    if [ -z "$session_id" ]; then
        print_error "Failed to create test session"
        exit 1
    fi
    print_success "Created session: $session_id"
    
    # Step 3: Submit requests and simulate failures
    print_status "Step 3: Submitting requests and simulating failures to trigger circuit breaker"
    
    local failure_count=0
    local success_count=0
    
    for i in $(seq 1 10); do
        local correlation_id="cb-test-$i"
        local timestamp=$(date +%s)000000000
        
        # Submit request
        print_status "Submitting request $i..."
        local submit_result=$(dfx canister call ai_router submit "(record {
            correlationId = \"$correlation_id\";
            idempotencyKey = \"idempotency-cb-$i\";
            sessionId = \"$session_id\";
            submitterId = \"circuit-breaker-tester\";
            timestamp = $timestamp;
            requestType = variant { ChatCompletion };
            priority = variant { Normal };
            timeoutMs = 5000;
            retryCount = 0;
            payload = variant { 
                Chat = record {
                    messages = vec {
                        record {
                            role = variant { User };
                            content = \"Circuit breaker test message $i\";
                            timestamp = $timestamp;
                        }
                    };
                    model = \"test-model\";
                    maxTokens = opt 100;
                    temperature = opt 0.7;
                }
            };
            triadContext = null;
        })" 2>&1)
        
        if echo "$submit_result" | grep -q "circuit breaker is open\|Service temporarily unavailable"; then
            print_warning "Circuit breaker is now OPEN - blocking new requests"
            break
        elif echo "$submit_result" | grep -q "$correlation_id"; then
            print_success "Request $i submitted successfully"
            
            # Simulate AI service failure response
            sleep 1  # Small delay before failure simulation
            
            local failure_result=$(simulate_ai_service_failure "$correlation_id" "Simulated processing failure #$i")
            if echo "$failure_result" | grep -q "ERROR"; then
                print_warning "Failed to simulate AI service failure for request $i"
            else
                print_status "Simulated failure for request $i"
                failure_count=$((failure_count + 1))
            fi
        else
            print_error "Failed to submit request $i: $submit_result"
        fi
        
        # Check circuit breaker state after each request
        local current_state=$(get_cb_status)
        echo "  Circuit breaker state after request $i: $current_state"
        
        if [ "$current_state" = "open" ]; then
            print_warning "Circuit breaker opened after $i requests"
            break
        fi
        
        sleep 2  # Delay between requests
    done
    
    # Step 4: Verify circuit breaker opened
    print_status "Step 4: Verifying circuit breaker behavior"
    local final_state=$(get_cb_status)
    echo "Final circuit breaker state: $final_state"
    
    if [ "$final_state" = "open" ]; then
        print_success "Circuit breaker successfully opened due to failures"
        
        # Test that new requests are blocked
        print_status "Testing that new requests are blocked..."
        local blocked_request=$(dfx canister call ai_router submit "(record {
            correlationId = \"blocked-test\";
            idempotencyKey = \"blocked-idempotency\";
            sessionId = \"$session_id\";
            submitterId = \"circuit-breaker-tester\";
            timestamp = $(date +%s)000000000;
            requestType = variant { ChatCompletion };
            priority = variant { Normal };
            timeoutMs = 5000;
            retryCount = 0;
            payload = variant { 
                Chat = record {
                    messages = vec {
                        record {
                            role = variant { User };
                            content = \"This should be blocked\";
                            timestamp = $(date +%s)000000000;
                        }
                    };
                    model = \"test-model\";
                    maxTokens = opt 100;
                    temperature = opt 0.7;
                }
            };
            triadContext = null;
        })" 2>&1)
        
        if echo "$blocked_request" | grep -q "circuit breaker is open\|Service temporarily unavailable"; then
            print_success "New requests are correctly blocked by open circuit breaker"
        else
            print_error "Circuit breaker is not properly blocking new requests"
        fi
    else
        print_warning "Circuit breaker did not open as expected. State: $final_state"
    fi
    
    # Step 5: Get performance metrics
    print_status "Step 5: Getting performance metrics after failure simulation"
    local perf_metrics=$(get_performance_metrics)
    echo "Performance Metrics:"
    echo "$perf_metrics"
    
    # Extract key metrics
    local cb_trips=$(echo "$perf_metrics" | grep -o 'circuitBreakerTrips = [0-9]*' | cut -d' ' -f3)
    local failures=$(echo "$perf_metrics" | grep -o 'failures = [0-9]*' | cut -d' ' -f3)
    local cb_healthy=$(echo "$perf_metrics" | grep -o 'isHealthy = [a-z]*' | cut -d' ' -f3)
    
    echo ""
    echo "=== Circuit Breaker Test Summary ==="
    echo "Circuit breaker trips: $cb_trips"
    echo "Total failures recorded: $failures"
    echo "Circuit breaker healthy: $cb_healthy"
    echo "Simulated failures: $failure_count"
    
    # Step 6: Test recovery (optional)
    read -p "Do you want to test circuit breaker recovery? This will wait 60+ seconds. (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Step 6: Testing circuit breaker recovery"
        print_status "Waiting 65 seconds for circuit breaker timeout..."
        
        for i in $(seq 65 -1 1); do
            echo -ne "\r  Waiting... ${i}s remaining"
            sleep 1
        done
        echo
        
        print_status "Testing recovery with successful request..."
        local recovery_state=$(get_cb_status)
        echo "Circuit breaker state before recovery test: $recovery_state"
        
        # Try a recovery request
        local recovery_result=$(dfx canister call ai_router submit "(record {
            correlationId = \"recovery-test\";
            idempotencyKey = \"recovery-idempotency\";
            sessionId = \"$session_id\";
            submitterId = \"circuit-breaker-tester\";
            timestamp = $(date +%s)000000000;
            requestType = variant { ChatCompletion };
            priority = variant { Normal };
            timeoutMs = 5000;
            retryCount = 0;
            payload = variant { 
                Chat = record {
                    messages = vec {
                        record {
                            role = variant { User };
                            content = \"Recovery test message\";
                            timestamp = $(date +%s)000000000;
                        }
                    };
                    model = \"test-model\";
                    maxTokens = opt 100;
                    temperature = opt 0.7;
                }
            };
            triadContext = null;
        })" 2>&1)
        
        if echo "$recovery_result" | grep -q "recovery-test"; then
            print_success "Recovery request accepted - circuit breaker is allowing requests"
            
            # Check final state
            local recovered_state=$(get_cb_status)
            echo "Circuit breaker state after recovery: $recovered_state"
            
            if [ "$recovered_state" = "half-open" ] || [ "$recovered_state" = "closed" ]; then
                print_success "Circuit breaker successfully recovered"
            fi
        else
            print_warning "Recovery request failed: $recovery_result"
        fi
    fi
    
    print_success "Circuit breaker failure simulation complete!"
}

# Execute main function
main "$@"
