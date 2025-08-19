#!/bin/bash

# Real-time Performance Dashboard for AI Router
# Provides live monitoring of P95/P99 latency, throughput, and circuit breaker status

set -e

# Color codes for dashboard
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Dashboard configuration
REFRESH_INTERVAL=5  # seconds
MAX_ITERATIONS=60   # Total monitoring time = REFRESH_INTERVAL * MAX_ITERATIONS

print_header() {
    clear
    echo -e "${WHITE}========================================================================${NC}"
    echo -e "${WHITE}                   AI Router Performance Dashboard                      ${NC}"
    echo -e "${WHITE}========================================================================${NC}"
    echo -e "${CYAN}Monitoring: P95/P99 Latency | Throughput | Circuit Breaker | Errors${NC}"
    echo -e "${WHITE}Update Interval: ${REFRESH_INTERVAL}s | Total Runtime: $((MAX_ITERATIONS * REFRESH_INTERVAL))s${NC}"
    echo -e "${WHITE}========================================================================${NC}"
    echo
}

format_number() {
    local num="$1"
    local precision="${2:-2}"
    
    if [ "$num" = "0" ] || [ "$num" = "0.0" ]; then
        echo "0.00"
    else
        printf "%.${precision}f" "$num" 2>/dev/null || echo "$num"
    fi
}

get_health_status() {
    dfx canister call ai_router health 2>/dev/null || echo "ERROR"
}

get_performance_metrics() {
    dfx canister call ai_router performanceMetrics 2>/dev/null || echo "ERROR"
}

get_basic_metrics() {
    dfx canister call ai_router metrics 2>/dev/null || echo "ERROR"
}

parse_metric() {
    local data="$1"
    local field="$2"
    echo "$data" | grep -o "$field = [0-9.]*" | cut -d' ' -f3 | head -1
}

parse_text_metric() {
    local data="$1"
    local field="$2"
    echo "$data" | grep -o "$field = \"[^\"]*\"" | cut -d'"' -f2 | head -1
}

parse_bool_metric() {
    local data="$1"
    local field="$2"
    echo "$data" | grep -o "$field = [a-z]*" | cut -d' ' -f3 | head -1
}

display_latency_metrics() {
    local perf_data="$1"
    
    local p50=$(parse_metric "$perf_data" "p50")
    local p90=$(parse_metric "$perf_data" "p90")
    local p95=$(parse_metric "$perf_data" "p95")
    local p99=$(parse_metric "$perf_data" "p99")
    local avg=$(parse_metric "$perf_data" "avg")
    local max=$(parse_metric "$perf_data" "max")
    local count=$(parse_metric "$perf_data" "count")
    
    echo -e "${WHITE}📊 LATENCY METRICS${NC}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    
    # Color code latencies based on performance targets
    local p95_color=$GREEN
    local p99_color=$GREEN
    
    if (( $(echo "$p95 > 150" | bc -l 2>/dev/null || echo 0) )); then
        p95_color=$YELLOW
    fi
    if (( $(echo "$p95 > 300" | bc -l 2>/dev/null || echo 0) )); then
        p95_color=$RED
    fi
    
    if (( $(echo "$p99 > 500" | bc -l 2>/dev/null || echo 0) )); then
        p99_color=$YELLOW
    fi
    if (( $(echo "$p99 > 1000" | bc -l 2>/dev/null || echo 0) )); then
        p99_color=$RED
    fi
    
    printf "  │ P50 (Median): %8s ms   │ P90: %8s ms        │\n" "$(format_number "$p50")" "$(format_number "$p90")"
    printf "  │ ${p95_color}P95: %12s ms${NC}   │ ${p99_color}P99: %8s ms${NC}        │\n" "$(format_number "$p95")" "$(format_number "$p99")"
    printf "  │ Average: %11s ms   │ Max: %8s ms        │\n" "$(format_number "$avg")" "$(format_number "$max")"
    printf "  │ Sample Count: %10s     │                      │\n" "$count"
    echo "  └─────────────────────────────────────────────────────┘"
    echo
}

display_throughput_metrics() {
    local perf_data="$1"
    
    local rps=$(parse_metric "$perf_data" "requestsPerSecond")
    local rpm=$(parse_metric "$perf_data" "requestsPerMinute")
    
    # Color code throughput
    local rps_color=$GREEN
    if (( $(echo "$rps < 50" | bc -l 2>/dev/null || echo 0) )); then
        rps_color=$YELLOW
    fi
    if (( $(echo "$rps < 10" | bc -l 2>/dev/null || echo 0) )); then
        rps_color=$RED
    fi
    
    echo -e "${WHITE}🚀 THROUGHPUT METRICS${NC}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    printf "  │ ${rps_color}Requests/Second: %8s${NC}     │ Target: >100 RPS     │\n" "$(format_number "$rps")"
    printf "  │ Requests/Minute: %8s     │                      │\n" "$(format_number "$rpm")"
    echo "  └─────────────────────────────────────────────────────┘"
    echo
}

display_circuit_breaker_status() {
    local perf_data="$1"
    local health_data="$2"
    
    local cb_state=$(parse_text_metric "$perf_data" "state")
    local cb_healthy=$(parse_bool_metric "$perf_data" "isHealthy")
    local failure_rate=$(parse_metric "$perf_data" "failureRate")
    local avg_response_time=$(parse_metric "$perf_data" "avgResponseTime")
    
    # Color code circuit breaker status
    local cb_color=$GREEN
    local status_icon="🟢"
    
    case "$cb_state" in
        "open")
            cb_color=$RED
            status_icon="🔴"
            ;;
        "half-open")
            cb_color=$YELLOW
            status_icon="🟡"
            ;;
        "closed")
            cb_color=$GREEN
            status_icon="🟢"
            ;;
    esac
    
    echo -e "${WHITE}🛡️  CIRCUIT BREAKER STATUS${NC}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    printf "  │ Status: ${cb_color}%s %-12s${NC} │ ${status_icon} %s            │\n" "$cb_state" "" "$([ "$cb_healthy" = "true" ] && echo "HEALTHY" || echo "UNHEALTHY")"
    printf "  │ Failure Rate: %8s%%     │ Avg Response: %6s ms │\n" "$(format_number "$failure_rate" 1)" "$(format_number "$avg_response_time")"
    echo "  └─────────────────────────────────────────────────────┘"
    echo
}

display_error_metrics() {
    local perf_data="$1"
    
    local cb_trips=$(parse_metric "$perf_data" "circuitBreakerTrips")
    local rate_violations=$(parse_metric "$perf_data" "rateLimitViolations") 
    local timeouts=$(parse_metric "$perf_data" "timeouts")
    local failures=$(parse_metric "$perf_data" "failures")
    
    # Calculate total errors
    local total_errors=$((cb_trips + rate_violations + timeouts + failures))
    
    echo -e "${WHITE}⚠️  ERROR TRACKING${NC}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    printf "  │ Circuit Breaker Trips: %6s     │ Rate Limit Hits: %6s │\n" "$cb_trips" "$rate_violations"
    printf "  │ Timeouts: %12s       │ Failures: %11s │\n" "$timeouts" "$failures"
    printf "  │ ${YELLOW}Total Errors: %10s${NC}       │                      │\n" "$total_errors"
    echo "  └─────────────────────────────────────────────────────┘"
    echo
}

display_system_info() {
    local basic_data="$1"
    
    local total_requests=$(parse_metric "$basic_data" "totalRequests")
    local pending_requests=$(parse_metric "$basic_data" "pendingRequests")
    local completed_requests=$(parse_metric "$basic_data" "completedRequests")
    local failed_requests=$(parse_metric "$basic_data" "failedRequests")
    local active_users=$(parse_metric "$basic_data" "activeUsers")
    
    echo -e "${WHITE}📈 SYSTEM OVERVIEW${NC}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    printf "  │ Total Requests: %9s     │ Pending: %12s │\n" "$total_requests" "$pending_requests"
    printf "  │ Completed: %12s       │ Failed: %13s │\n" "$completed_requests" "$failed_requests"
    printf "  │ Active Users: %10s       │ Timestamp: $(date '+%H:%M:%S') │\n" "$active_users"
    echo "  └─────────────────────────────────────────────────────┘"
    echo
}

display_performance_targets() {
    echo -e "${WHITE}🎯 PERFORMANCE TARGETS${NC}"
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │ P95 Latency: < 150ms          │ P99 Latency: < 500ms │"
    echo "  │ Throughput: > 100 RPS         │ Circuit Breaker: OK  │"
    echo "  │ Error Rate: < 1%              │ Recovery: < 60s      │"
    echo "  └─────────────────────────────────────────────────────┘"
    echo
}

show_dashboard() {
    local iteration="$1"
    
    print_header
    
    # Fetch all metrics
    local health_data=$(get_health_status)
    local perf_data=$(get_performance_metrics)
    local basic_data=$(get_basic_metrics)
    
    if [ "$health_data" = "ERROR" ] || [ "$perf_data" = "ERROR" ] || [ "$basic_data" = "ERROR" ]; then
        echo -e "${RED}❌ ERROR: Unable to fetch metrics from AI Router${NC}"
        echo "   Please ensure the AI Router is deployed and accessible"
        echo
        return 1
    fi
    
    # Display metrics sections
    display_latency_metrics "$perf_data"
    display_throughput_metrics "$perf_data"
    display_circuit_breaker_status "$perf_data" "$health_data"
    display_error_metrics "$perf_data"
    display_system_info "$basic_data"
    display_performance_targets
    
    # Footer with progress
    local progress=$((iteration * 100 / MAX_ITERATIONS))
    echo -e "${WHITE}========================================================================${NC}"
    echo -e "${CYAN}Progress: [$iteration/$MAX_ITERATIONS] ${progress}% | Next update in ${REFRESH_INTERVAL}s | Press Ctrl+C to exit${NC}"
    echo -e "${WHITE}========================================================================${NC}"
}

# Main monitoring loop
main() {
    echo "Starting AI Router Performance Dashboard..."
    echo "Monitoring for $((MAX_ITERATIONS * REFRESH_INTERVAL)) seconds with ${REFRESH_INTERVAL}s intervals"
    echo "Press Ctrl+C to stop monitoring"
    echo
    
    # Check if bc is available for calculations
    if ! command -v bc &> /dev/null; then
        echo "Warning: bc calculator not found - some calculations may not work properly"
        sleep 2
    fi
    
    # Trap Ctrl+C for clean exit
    trap 'echo -e "\n${GREEN}Dashboard monitoring stopped by user${NC}"; exit 0' INT
    
    for iteration in $(seq 1 $MAX_ITERATIONS); do
        show_dashboard "$iteration"
        
        if [ "$iteration" -lt "$MAX_ITERATIONS" ]; then
            sleep "$REFRESH_INTERVAL"
        fi
    done
    
    echo -e "\n${GREEN}Dashboard monitoring completed after $((MAX_ITERATIONS * REFRESH_INTERVAL)) seconds${NC}"
}

# Check if running standalone or being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
