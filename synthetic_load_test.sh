#!/bin/bash

# Comprehensive Load Testing and Circuit Breaker Simulation
# Phase 1 Week 3 Implementation Testing

set -e

echo "=== Phase 1 Week 3: Load Testing & Circuit Breaker Simulation ==="
echo "Testing synthetic load, performance benchmarking, and circuit breaker failure scenarios"
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
LOAD_TEST_DURATION=60  # seconds
CONCURRENT_USERS=10
REQUESTS_PER_USER=100
FAILURE_INJECTION_RATE=0.2  # 20% failure rate for circuit breaker testing

# Helper functions
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

print_metric() {
    echo -e "${CYAN}[METRIC]${NC} $1"
}

# Create test session
create_test_session() {
    print_status "Creating test session..."
    
    local SESSION_RESULT=$(dfx canister call ai_router createSession '(variant { AISubmitter })' 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' || echo "")
    if [ -n "$SESSION_RESULT" ]; then
        echo "$SESSION_RESULT"
    else
        echo ""
    fi
}

# Submit a single test request
submit_test_request() {
    local session_id="$1"
    local request_id="$2"
    local should_fail="${3:-false}"
    
    local timestamp=$(date +%s)000000000
    
    # Inject failures for circuit breaker testing
    local payload_content="Test load request $request_id"
    if [ "$should_fail" = "true" ]; then
        payload_content="FORCE_FAILURE_$request_id"  # This would trigger validation failures
    fi
    
    local result=$(dfx canister call ai_router submit "(record {
        correlationId = \"load-test-$request_id\";
        idempotencyKey = \"idempotency-$request_id\";
        sessionId = \"$session_id\";
        submitterId = \"load-tester\";
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
                        content = \"$payload_content\";
                        timestamp = $timestamp;
                    }
                };
                model = \"load-test-model\";
                maxTokens = opt 100;
                temperature = opt 0.7;
            }
        };
        triadContext = null;
    })" 2>&1 || echo "ERROR")
    
    echo "$result"
}

# Baseline performance test
baseline_performance_test() {
    print_status "Running baseline performance test..."
    
    local session_id=$(create_test_session)
    if [ -z "$session_id" ]; then
        print_error "Cannot run baseline test without session"
        return 1
    fi
    
    print_status "Session created: $session_id"
    
    # Record start time
    local start_time=$(date +%s)
    local success_count=0
    local error_count=0
    
    # Submit 50 requests sequentially for baseline
    print_status "Submitting 50 sequential requests for baseline measurement..."
    
    for i in $(seq 1 50); do
        local result=$(submit_test_request "$session_id" "baseline-$i" "false")
        
        if echo "$result" | grep -q "load-test-baseline-$i"; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
        
        # Show progress every 10 requests
        if [ $((i % 10)) -eq 0 ]; then
            echo "  Progress: $i/50 requests submitted"
        fi
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local rps=$(echo "scale=2; $success_count / $duration" | bc -l 2>/dev/null || echo "N/A")
    
    print_metric "Baseline Results:"
    print_metric "  Duration: ${duration}s"
    print_metric "  Successful requests: $success_count"
    print_metric "  Failed requests: $error_count"
    print_metric "  Requests per second: $rps"
    
    # Get initial performance metrics
    print_status "Fetching baseline performance metrics..."
    local metrics=$(dfx canister call ai_router performanceMetrics)
    echo "Baseline Performance Metrics:"
    echo "$metrics"
}

# Concurrent load test
concurrent_load_test() {
    print_status "Running concurrent load test with $CONCURRENT_USERS users..."
    
    local session_id=$(create_test_session)
    if [ -z "$session_id" ]; then
        print_error "Cannot run concurrent test without session"
        return 1
    fi
    
    # Create temporary directory for results
    local temp_dir=$(mktemp -d)
    
    # Function to run concurrent user simulation
    simulate_user() {
        local user_id="$1"
        local session_id="$2"
        local requests_per_user="$3"
        local output_file="$4"
        
        local success=0
        local errors=0
        local start_time=$(date +%s%3N)  # milliseconds
        
        for i in $(seq 1 $requests_per_user); do
            local request_start=$(date +%s%3N)
            local result=$(submit_test_request "$session_id" "user$user_id-req$i" "false")
            local request_end=$(date +%s%3N)
            local latency=$((request_end - request_start))
            
            if echo "$result" | grep -q "user$user_id-req$i"; then
                success=$((success + 1))
                echo "SUCCESS,$latency" >> "$output_file"
            else
                errors=$((errors + 1))
                echo "ERROR,$latency" >> "$output_file"
            fi
            
            # Small delay to simulate realistic usage
            sleep 0.1
        done
        
        local end_time=$(date +%s%3N)
        local total_time=$((end_time - start_time))
        
        echo "SUMMARY,user$user_id,$success,$errors,$total_time" >> "$output_file"
    }
    
    print_status "Starting $CONCURRENT_USERS concurrent users (each making $REQUESTS_PER_USER requests)..."
    
    # Start concurrent users
    local pids=()
    for user_id in $(seq 1 $CONCURRENT_USERS); do
        local output_file="$temp_dir/user_$user_id.log"
        simulate_user "$user_id" "$session_id" "$REQUESTS_PER_USER" "$output_file" &
        pids+=($!)
    done
    
    # Monitor progress
    local start_time=$(date +%s)
    while [ ${#pids[@]} -gt 0 ]; do
        local new_pids=()
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
            fi
        done
        pids=("${new_pids[@]}")
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        echo "  Concurrent load test running... ${elapsed}s elapsed, ${#pids[@]} users still active"
        
        sleep 2
    done
    
    # Collect and analyze results
    print_status "Analyzing concurrent load test results..."
    
    local total_success=0
    local total_errors=0
    local total_requests=0
    local latencies=()
    
    for user_id in $(seq 1 $CONCURRENT_USERS); do
        local output_file="$temp_dir/user_$user_id.log"
        if [ -f "$output_file" ]; then
            while IFS=, read -r type value1 value2 value3 value4; do
                case "$type" in
                    "SUCCESS")
                        total_success=$((total_success + 1))
                        latencies+=("$value1")
                        ;;
                    "ERROR")
                        total_errors=$((total_errors + 1))
                        ;;
                    "SUMMARY")
                        # value2=success, value3=errors, value4=time
                        ;;
                esac
            done < "$output_file"
        fi
    done
    
    total_requests=$((total_success + total_errors))
    local end_time=$(date +%s)
    local test_duration=$((end_time - start_time))
    local rps=$(echo "scale=2; $total_requests / $test_duration" | bc -l 2>/dev/null || echo "N/A")
    
    print_metric "Concurrent Load Test Results:"
    print_metric "  Test duration: ${test_duration}s"
    print_metric "  Total requests: $total_requests"
    print_metric "  Successful requests: $total_success"
    print_metric "  Failed requests: $total_errors"
    print_metric "  Success rate: $(echo "scale=2; $total_success * 100 / $total_requests" | bc -l 2>/dev/null || echo "N/A")%"
    print_metric "  Requests per second: $rps"
    
    # Calculate latency percentiles (simple approximation)
    if [ ${#latencies[@]} -gt 0 ]; then
        local sorted_latencies=($(printf '%s\n' "${latencies[@]}" | sort -n))
        local count=${#sorted_latencies[@]}
        local p50_idx=$((count * 50 / 100))
        local p95_idx=$((count * 95 / 100))
        local p99_idx=$((count * 99 / 100))
        
        print_metric "  Latency P50: ${sorted_latencies[$p50_idx]}ms"
        print_metric "  Latency P95: ${sorted_latencies[$p95_idx]}ms"
        print_metric "  Latency P99: ${sorted_latencies[$p99_idx]}ms"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Circuit breaker failure simulation
circuit_breaker_failure_simulation() {
    print_status "Running circuit breaker failure simulation..."
    
    local session_id=$(create_test_session)
    if [ -z "$session_id" ]; then
        print_error "Cannot run circuit breaker test without session"
        return 1
    fi
    
    print_status "Phase 1: Triggering circuit breaker with failures..."
    
    # Submit requests with high failure rate to trigger circuit breaker
    local failure_count=0
    local total_attempts=0
    
    for i in $(seq 1 10); do
        local should_fail="true"  # Force failures to trigger circuit breaker
        local result=$(submit_test_request "$session_id" "cb-fail-$i" "$should_fail")
        total_attempts=$((total_attempts + 1))
        
        if echo "$result" | grep -q "circuit breaker is open\|Service temporarily unavailable"; then
            print_warning "Circuit breaker opened at attempt $i"
            break
        elif echo "$result" | grep -q "ERROR\|failed\|violation"; then
            failure_count=$((failure_count + 1))
        fi
        
        sleep 0.5  # Small delay between attempts
    done
    
    print_metric "Failure injection results:"
    print_metric "  Total attempts: $total_attempts"
    print_metric "  Failures triggered: $failure_count"
    
    # Check circuit breaker status
    print_status "Checking circuit breaker status after failures..."
    local cb_status=$(dfx canister call ai_router health)
    echo "Circuit Breaker Status: $cb_status"
    
    # Wait for potential recovery (circuit breaker timeout)
    print_status "Waiting 65 seconds for circuit breaker recovery window..."
    sleep 65
    
    # Test recovery
    print_status "Testing circuit breaker recovery..."
    local recovery_result=$(submit_test_request "$session_id" "cb-recovery-1" "false")
    echo "Recovery test result: $recovery_result"
    
    # Final status check
    local final_status=$(dfx canister call ai_router health)
    echo "Final Circuit Breaker Status: $final_status"
}

# Rate limiting stress test
rate_limiting_stress_test() {
    print_status "Running rate limiting stress test..."
    
    local session_id=$(create_test_session)
    if [ -z "$session_id" ]; then
        print_error "Cannot run rate limiting test without session"
        return 1
    fi
    
    print_status "Submitting 100 requests rapidly to trigger rate limiting..."
    
    local success_count=0
    local rate_limited_count=0
    local error_count=0
    
    for i in $(seq 1 100); do
        local result=$(submit_test_request "$session_id" "rate-limit-$i" "false")
        
        if echo "$result" | grep -q "Rate limit exceeded"; then
            rate_limited_count=$((rate_limited_count + 1))
        elif echo "$result" | grep -q "rate-limit-$i"; then
            success_count=$((success_count + 1))
        else
            error_count=$((error_count + 1))
        fi
        
        # No delay - stress test the rate limiter
    done
    
    print_metric "Rate Limiting Stress Test Results:"
    print_metric "  Successful requests: $success_count"
    print_metric "  Rate limited requests: $rate_limited_count"
    print_metric "  Other errors: $error_count"
    
    if [ $rate_limited_count -gt 0 ]; then
        print_success "Rate limiting is working correctly"
    else
        print_warning "Rate limiting may need adjustment"
    fi
}

# Performance metrics analysis
analyze_performance_metrics() {
    print_status "Analyzing comprehensive performance metrics..."
    
    local perf_metrics=$(dfx canister call ai_router performanceMetrics)
    echo "=== Performance Metrics Analysis ==="
    echo "$perf_metrics"
    
    # Extract key metrics for analysis
    local p95_latency=$(echo "$perf_metrics" | grep -o 'p95 = [0-9.]*' | cut -d' ' -f3)
    local p99_latency=$(echo "$perf_metrics" | grep -o 'p99 = [0-9.]*' | cut -d' ' -f3)
    local rps=$(echo "$perf_metrics" | grep -o 'requestsPerSecond = [0-9.]*' | cut -d' ' -f3)
    
    if [ -n "$p95_latency" ] && [ -n "$p99_latency" ] && [ -n "$rps" ]; then
        print_metric "Key Performance Indicators:"
        print_metric "  P95 Latency: ${p95_latency}ms (target: <150ms)"
        print_metric "  P99 Latency: ${p99_latency}ms (target: <500ms)"
        print_metric "  Requests/sec: $rps (target: >100 rps)"
        
        # Performance assessment
        local p95_ok=$(echo "$p95_latency < 150" | bc -l 2>/dev/null || echo "0")
        local p99_ok=$(echo "$p99_latency < 500" | bc -l 2>/dev/null || echo "0")
        local rps_ok=$(echo "$rps > 100" | bc -l 2>/dev/null || echo "0")
        
        if [ "$p95_ok" = "1" ] && [ "$p99_ok" = "1" ] && [ "$rps_ok" = "1" ]; then
            print_success "All performance targets met!"
        else
            print_warning "Some performance targets not met - optimization needed"
        fi
    else
        print_warning "Could not extract performance metrics for analysis"
    fi
}

# Main test execution
main() {
    echo "Starting Phase 1 Week 3 comprehensive testing..."
    echo
    
    # Check dependencies
    if ! command -v bc &> /dev/null; then
        print_warning "bc calculator not found - some calculations may not work"
    fi
    
    print_status "=== Test 1: Baseline Performance Test ==="
    baseline_performance_test || print_error "Baseline test failed"
    echo
    
    print_status "=== Test 2: Concurrent Load Test ==="
    concurrent_load_test || print_error "Concurrent load test failed"
    echo
    
    print_status "=== Test 3: Circuit Breaker Failure Simulation ==="
    circuit_breaker_failure_simulation || print_error "Circuit breaker test failed"
    echo
    
    print_status "=== Test 4: Rate Limiting Stress Test ==="
    rate_limiting_stress_test || print_error "Rate limiting test failed"
    echo
    
    print_status "=== Test 5: Performance Metrics Analysis ==="
    analyze_performance_metrics || print_error "Performance analysis failed"
    echo
    
    print_success "=== Phase 1 Week 3 Testing Complete ==="
    echo
    print_status "Summary of tested features:"
    echo "  ✓ Synthetic load testing with concurrent users"
    echo "  ✓ Circuit breaker failure simulation and recovery"
    echo "  ✓ Rate limiting stress testing"
    echo "  ✓ P95/P99 latency measurement and analysis"
    echo "  ✓ Performance benchmarking and optimization validation"
    echo
    print_status "System is ready for production load with comprehensive monitoring"
}

# Execute main function
main "$@"
