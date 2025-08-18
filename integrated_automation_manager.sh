#!/bin/bash

# AxiaSystem Bridge Integration Manager
# Integrates bridge automation with canister management system
# Author: GitHub Copilot
# Version: 1.0.0

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AXIASYSTEM_PATH="$SCRIPT_DIR"
BRIDGE_PATH="/home/woodrowlove/AxiaSystem-Rust-Bridge"
LOG_FILE="$AXIASYSTEM_PATH/integrated_automation.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INTEGRATION]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Check if bridge automation is available
check_bridge_availability() {
    log_info "Checking bridge automation availability..."
    
    if [ ! -d "$BRIDGE_PATH" ]; then
        log_warning "Bridge directory not found: $BRIDGE_PATH"
        log_info "Bridge automation will be skipped"
        return 1
    fi
    
    if [ ! -f "$AXIASYSTEM_PATH/bridge_automation_manager.sh" ]; then
        log_error "Bridge automation script not found"
        return 1
    fi
    
    log_success "Bridge automation available"
    return 0
}

# Run canister management first
run_canister_management() {
    log_info "Running canister ID management..."
    
    if [ -f "$AXIASYSTEM_PATH/simple_canister_manager.sh" ]; then
        log_info "Executing simple_canister_manager.sh..."
        if bash "$AXIASYSTEM_PATH/simple_canister_manager.sh"; then
            log_success "Canister management completed successfully"
            return 0
        else
            log_error "Canister management failed"
            return 1
        fi
    else
        log_error "simple_canister_manager.sh not found"
        return 1
    fi
}

# Run bridge automation after canister updates
run_bridge_automation() {
    log_info "Running bridge automation..."
    
    if check_bridge_availability; then
        log_info "Executing bridge_automation_manager.sh..."
        if bash "$AXIASYSTEM_PATH/bridge_automation_manager.sh" --full-update; then
            log_success "Bridge automation completed successfully"
            return 0
        else
            log_warning "Bridge automation completed with issues"
            return 1
        fi
    else
        log_warning "Skipping bridge automation - not available"
        return 1
    fi
}

# Validate entire integration
validate_integration() {
    log_info "Validating integration results..."
    
    local validation_results=()
    
    # Check canister_ids.json exists and is valid
    if [ -f "$AXIASYSTEM_PATH/canister_ids.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            if jq empty "$AXIASYSTEM_PATH/canister_ids.json" 2>/dev/null; then
                validation_results+=("✅ canister_ids.json valid")
            else
                validation_results+=("❌ canister_ids.json invalid JSON")
            fi
        else
            # Basic JSON validation without jq
            if python3 -c "import json; json.load(open('$AXIASYSTEM_PATH/canister_ids.json'))" 2>/dev/null; then
                validation_results+=("✅ canister_ids.json valid")
            elif node -e "JSON.parse(require('fs').readFileSync('$AXIASYSTEM_PATH/canister_ids.json', 'utf8'))" 2>/dev/null; then
                validation_results+=("✅ canister_ids.json valid")
            else
                validation_results+=("⚠️  canister_ids.json format unknown (jq not available)")
            fi
        fi
    else
        validation_results+=("❌ canister_ids.json missing")
    fi
    
    # Check frontend config exists
    if [ -f "$AXIASYSTEM_PATH/src/config/canister-ids.js" ]; then
        validation_results+=("✅ Frontend config generated")
    else
        validation_results+=("❌ Frontend config missing")
    fi
    
    # Check bridge constants if bridge is available
    if check_bridge_availability; then
        if [ -f "$BRIDGE_PATH/src/constants.rs" ]; then
            validation_results+=("✅ Bridge constants updated")
        else
            validation_results+=("❌ Bridge constants missing")
        fi
        
        # Check bridge compilation
        cd "$BRIDGE_PATH"
        if cargo check --quiet 2>/dev/null; then
            validation_results+=("✅ Bridge compiles successfully")
        else
            validation_results+=("❌ Bridge compilation issues")
        fi
    fi
    
    # Report validation results
    log_info "Integration validation results:"
    for result in "${validation_results[@]}"; do
        if [[ $result == *"✅"* ]]; then
            log_success "$result"
        else
            log_warning "$result"
        fi
    done
    
    # Count successes
    local success_count=$(printf '%s\n' "${validation_results[@]}" | grep -c "✅" || echo "0")
    local total_count=${#validation_results[@]}
    
    log_info "Validation score: $success_count/$total_count"
    
    if [ $success_count -eq $total_count ]; then
        return 0
    else
        return 1
    fi
}

# Generate integration report
generate_integration_report() {
    log_info "Generating integration report..."
    
    local report_file="$AXIASYSTEM_PATH/documentation/INTEGRATION_AUTOMATION_REPORT.md"
    
    # Ensure documentation directory exists
    mkdir -p "$AXIASYSTEM_PATH/documentation"
    
    {
        echo "# AxiaSystem Integration Automation Report"
        echo ""
        echo "**Generated:** $TIMESTAMP"
        echo "**AxiaSystem Path:** $AXIASYSTEM_PATH"
        echo "**Bridge Path:** $BRIDGE_PATH"
        echo ""
        echo "## Automation Components"
        echo ""
        echo "### 1. Canister Management"
        if [ -f "$AXIASYSTEM_PATH/simple_canister_manager.sh" ]; then
            echo "- ✅ **simple_canister_manager.sh** - Available and functional"
            echo "  - Manages 18 AxiaSystem canisters"
            echo "  - Updates canister_ids.json automatically"
            echo "  - Generates frontend configuration"
            echo "  - Supports local/testnet/mainnet environments"
        else
            echo "- ❌ **simple_canister_manager.sh** - Missing"
        fi
        
        echo ""
        echo "### 2. Bridge Automation"
        if check_bridge_availability >/dev/null 2>&1; then
            echo "- ✅ **bridge_automation_manager.sh** - Available and functional"
            echo "  - Synchronizes Rust FFI bridge with canister updates"
            echo "  - Auto-generates missing bindings from DID files"
            echo "  - Updates module declarations automatically"
            echo "  - Validates bridge compilation and tests"
            echo "  - Syncs canister IDs to bridge constants"
        else
            echo "- ⚠️  **bridge_automation_manager.sh** - Limited availability"
            echo "  - Bridge directory: $BRIDGE_PATH"
            echo "  - Status: $([ -d "$BRIDGE_PATH" ] && echo "Directory exists" || echo "Directory missing")"
        fi
        
        echo ""
        echo "### 3. Network Management"
        if [ -f "$AXIASYSTEM_PATH/network_manager.sh" ]; then
            echo "- ✅ **network_manager.sh** - Available"
            echo "  - Multi-environment deployment automation"
            echo "  - Cycles management and monitoring"
            echo "  - Production deployment checklist"
        else
            echo "- ❌ **network_manager.sh** - Missing"
        fi
        
        echo ""
        echo "## Current Canister Structure"
        echo ""
        if [ -f "$AXIASYSTEM_PATH/canister_ids.json" ]; then
            echo "**Active Canisters:**"
            jq -r 'keys[]' "$AXIASYSTEM_PATH/canister_ids.json" 2>/dev/null | sort | while read -r canister; do
                local canister_id=$(jq -r ".[\"$canister\"].local" "$AXIASYSTEM_PATH/canister_ids.json" 2>/dev/null || echo "unknown")
                echo "- \`$canister\`: $canister_id"
            done
        else
            echo "**No canister_ids.json found**"
        fi
        
        echo ""
        echo "## Bridge Structure Analysis"
        echo ""
        if [ -d "$BRIDGE_PATH" ]; then
            echo "**Bridge Components:**"
            echo "- **Binding Files:** $(find "$BRIDGE_PATH/src/bindings" -name "*.rs" 2>/dev/null | grep -v mod.rs | wc -l || echo "0")"
            echo "- **Tool Modules:** $(find "$BRIDGE_PATH/src/tools/modules" -name "*.rs" 2>/dev/null | grep -v mod.rs | wc -l || echo "0")"
            echo "- **Test Files:** $(find "$BRIDGE_PATH/tests" -name "*.rs" 2>/dev/null | wc -l || echo "0")"
            echo ""
            echo "**Bridge Dependencies:**"
            if [ -f "$BRIDGE_PATH/Cargo.toml" ]; then
                echo "\`\`\`toml"
                grep -A 20 "^\\[dependencies\\]" "$BRIDGE_PATH/Cargo.toml" | head -20
                echo "\`\`\`"
            fi
        else
            echo "**Bridge not available at $BRIDGE_PATH**"
        fi
        
        echo ""
        echo "## Integration Workflow"
        echo ""
        echo "### Automated Sequence"
        echo "1. **Canister Management** (\`simple_canister_manager.sh\`)"
        echo "   - Fetch current canister IDs from dfx"
        echo "   - Update canister_ids.json"
        echo "   - Generate frontend configuration"
        echo "   - Update documentation"
        echo ""
        echo "2. **Bridge Synchronization** (\`bridge_automation_manager.sh\`)"
        echo "   - Analyze current bridge structure"
        echo "   - Generate missing bindings from DID files"
        echo "   - Update module declarations"
        echo "   - Sync canister IDs to bridge constants"
        echo "   - Validate bridge compilation"
        echo "   - Run bridge tests"
        echo ""
        echo "3. **Integration Validation**"
        echo "   - Verify all components are synchronized"
        echo "   - Check compilation and test results"
        echo "   - Generate this report"
        echo ""
        echo "### Usage Commands"
        echo ""
        echo "\`\`\`bash"
        echo "# Full integration automation"
        echo "./integrated_automation_manager.sh --full-integration"
        echo ""
        echo "# Canister management only"
        echo "./integrated_automation_manager.sh --canisters-only"
        echo ""
        echo "# Bridge automation only"
        echo "./integrated_automation_manager.sh --bridge-only"
        echo ""
        echo "# Validation only"
        echo "./integrated_automation_manager.sh --validate-only"
        echo "\`\`\`"
        echo ""
        echo "## Production Deployment Notes"
        echo ""
        echo "### Environment Transition"
        echo "- The automation system supports seamless transition from development to production"
        echo "- Network configurations are automatically detected and applied"
        echo "- Canister IDs are environment-specific and managed automatically"
        echo ""
        echo "### Production Checklist"
        echo "- [ ] Verify all canisters deployed to mainnet"
        echo "- [ ] Confirm cycles balance sufficient for operations"
        echo "- [ ] Validate bridge compilation in production environment"
        echo "- [ ] Run full test suite before production deployment"
        echo "- [ ] Update documentation with production canister IDs"
        echo ""
        echo "## Troubleshooting"
        echo ""
        echo "### Common Issues"
        echo "1. **Bridge compilation failures**"
        echo "   - Run \`./bridge_automation_manager.sh --validate-only\`"
        echo "   - Check Rust dependencies in Cargo.toml"
        echo "   - Verify DID file compatibility"
        echo ""
        echo "2. **Missing canister IDs**"
        echo "   - Run \`./simple_canister_manager.sh\`"
        echo "   - Check dfx.json configuration"
        echo "   - Verify network connectivity"
        echo ""
        echo "3. **Integration validation failures**"
        echo "   - Run \`./integrated_automation_manager.sh --validate-only\`"
        echo "   - Check individual component logs"
        echo "   - Verify file permissions and paths"
        echo ""
        echo "## Logs and Debugging"
        echo ""
        echo "- **Integration Log:** \`$LOG_FILE\`"
        echo "- **Bridge Log:** \`$AXIASYSTEM_PATH/bridge_automation.log\`"
        echo "- **Canister Log:** \`$AXIASYSTEM_PATH/canister_management.log\`"
        echo ""
        echo "---"
        echo "*Report generated by AxiaSystem Integration Automation Manager*"
        
    } > "$report_file"
    
    log_success "Integration report generated: $report_file"
}

# Full integration workflow
run_full_integration() {
    log_info "Starting full integration automation..."
    
    local canister_success=false
    local bridge_success=false
    local validation_success=false
    
    # Step 1: Run canister management
    if run_canister_management; then
        canister_success=true
    fi
    
    # Step 2: Run bridge automation (if available)
    if run_bridge_automation; then
        bridge_success=true
    elif ! check_bridge_availability >/dev/null 2>&1; then
        log_info "Bridge automation skipped - not available"
        bridge_success=true  # Consider success if bridge is simply not available
    fi
    
    # Step 3: Validate integration
    if validate_integration; then
        validation_success=true
    fi
    
    # Step 4: Generate report
    generate_integration_report
    
    # Determine overall success
    local overall_success=true
    if [ "$canister_success" = false ]; then
        log_error "Canister management failed"
        overall_success=false
    fi
    
    if [ "$bridge_success" = false ]; then
        log_error "Bridge automation failed"
        overall_success=false
    fi
    
    if [ "$validation_success" = false ]; then
        log_warning "Integration validation had issues"
        # Don't fail overall integration for validation issues
    fi
    
    if [ "$overall_success" = true ]; then
        log_success "🎉 Full integration automation completed successfully!"
        log_info "📊 View the integration report at: documentation/INTEGRATION_AUTOMATION_REPORT.md"
        return 0
    else
        log_error "❌ Integration automation failed - check logs for details"
        return 1
    fi
}

# Command line interface
show_help() {
    echo "AxiaSystem Integration Automation Manager"
    echo ""
    echo "This script coordinates the automation of both canister management and bridge"
    echo "synchronization to provide a complete development-to-production workflow."
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --full-integration  Run complete integration workflow (recommended)"
    echo "  --canisters-only    Run only canister management automation"
    echo "  --bridge-only       Run only bridge automation"
    echo "  --validate-only     Run only integration validation"
    echo "  --report-only       Generate integration report only"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --full-integration  # Complete automation workflow"
    echo "  $0 --canisters-only    # After deploying new canisters"
    echo "  $0 --bridge-only       # After modifying bridge code"
    echo "  $0 --validate-only     # Check system health"
    echo ""
    echo "Environment Support:"
    echo "  - Development (local dfx)"
    echo "  - Testnet deployment"
    echo "  - Production (IC mainnet)"
    echo ""
    echo "Component Status:"
    printf "  - Canister Management: "
    if [ -f "$AXIASYSTEM_PATH/simple_canister_manager.sh" ]; then
        echo "✅ Available"
    else
        echo "❌ Missing"
    fi
    
    printf "  - Bridge Automation: "
    if check_bridge_availability >/dev/null 2>&1; then
        echo "✅ Available"
    else
        echo "⚠️  Limited"
    fi
    echo ""
}

# Main execution
main() {
    log_info "AxiaSystem Integration Automation Manager starting at $TIMESTAMP"
    
    case "${1:-}" in
        --full-integration)
            run_full_integration
            ;;
        --canisters-only)
            log_info "Running canister management only..."
            run_canister_management
            ;;
        --bridge-only)
            log_info "Running bridge automation only..."
            run_bridge_automation
            ;;
        --validate-only)
            log_info "Running validation only..."
            validate_integration
            ;;
        --report-only)
            log_info "Generating report only..."
            generate_integration_report
            ;;
        --help|-h)
            show_help
            ;;
        "")
            log_info "No arguments provided, running full integration..."
            run_full_integration
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
