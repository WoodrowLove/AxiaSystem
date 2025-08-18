#!/bin/bash

# AxiaSystem Rust Bridge Automation Manager
# Automatically updates and synchronizes the Rust FFI bridge with AxiaSystem canisters
# Author: GitHub Copilot
# Version: 1.0.0

set -euo pipefail

# Configuration
BRIDGE_PATH="/home/woodrowlove/AxiaSystem-Rust-Bridge"
AXIASYSTEM_PATH="/home/woodrowlove/AxiaSystem"
LOG_FILE="$AXIASYSTEM_PATH/bridge_automation.log"
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
    log "${BLUE}[INFO]${NC} $1"
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

# Initialize automation session
init_automation() {
    log_info "Starting AxiaSystem Bridge Automation at $TIMESTAMP"
    log_info "Bridge Path: $BRIDGE_PATH"
    log_info "AxiaSystem Path: $AXIASYSTEM_PATH"
    
    # Verify paths exist
    if [ ! -d "$BRIDGE_PATH" ]; then
        log_error "Bridge directory not found: $BRIDGE_PATH"
        exit 1
    fi
    
    if [ ! -d "$AXIASYSTEM_PATH" ]; then
        log_error "AxiaSystem directory not found: $AXIASYSTEM_PATH"
        exit 1
    fi
    
    log_success "Environment validation complete"
}

# Get current canister IDs from AxiaSystem
get_current_canister_ids() {
    local canister_ids_file="$AXIASYSTEM_PATH/canister_ids.json"
    if [ ! -f "$canister_ids_file" ]; then
        log_warning "canister_ids.json not found, attempting to generate..."
        cd "$AXIASYSTEM_PATH"
        if command -v dfx >/dev/null 2>&1; then
            dfx canister id --all 2>/dev/null || log_warning "Could not fetch canister IDs with dfx"
        fi
    fi
    
    # Extract canister names from dfx.json
    if [ -f "$AXIASYSTEM_PATH/dfx.json" ]; then
        local canister_names=$(jq -r '.canisters | keys[]' "$AXIASYSTEM_PATH/dfx.json" 2>/dev/null || echo "")
        if [ -n "$canister_names" ]; then
            echo "$canister_names"
            return 0
        fi
    fi
    
    # Fallback: extract from canister_ids.json if it exists
    if [ -f "$canister_ids_file" ]; then
        local canister_names=$(jq -r 'keys[]' "$canister_ids_file" 2>/dev/null || echo "")
        if [ -n "$canister_names" ]; then
            echo "$canister_names"
            return 0
        fi
    fi
    
    log_error "Could not retrieve canister names from dfx.json or canister_ids.json"
    return 1
}

# Analyze bridge structure and dependencies
analyze_bridge_structure() {
    log_info "Analyzing current bridge structure..."
    
    # Count binding files
    local binding_count=$(find "$BRIDGE_PATH/src/bindings" -name "*.rs" | grep -v mod.rs | wc -l)
    log_info "Current binding files: $binding_count"
    
    # Count module files
    local module_count=$(find "$BRIDGE_PATH/src/tools/modules" -name "*.rs" | grep -v mod.rs | wc -l)
    log_info "Current module files: $module_count"
    
    # List missing bindings
    log_info "Checking for missing bindings..."
    local canister_names_output=$(get_current_canister_ids 2>/dev/null)
    local missing_bindings=()
    
    # Parse canister names properly
    if [ -n "$canister_names_output" ]; then
        local canister_names=$(echo "$canister_names_output" | tr '\n' ' ')
        
        for canister in $canister_names; do
            if [ ! -f "$BRIDGE_PATH/src/bindings/${canister}.rs" ]; then
                missing_bindings+=("$canister")
            fi
        done
        
        if [ ${#missing_bindings[@]} -gt 0 ]; then
            log_warning "Missing bindings for: ${missing_bindings[*]}"
        else
            log_success "All canisters have corresponding bindings"
        fi
    else
        log_warning "Could not retrieve canister names for analysis"
    fi
    
    # List existing bindings
    log_info "Existing bindings:"
    find "$BRIDGE_PATH/src/bindings" -name "*.rs" | grep -v mod.rs | sort | while read -r file; do
        local module_name=$(basename "$file" .rs)
        log_info "  - $module_name"
    done
}

# Generate missing bindings automatically
generate_missing_bindings() {
    log_info "Generating missing bindings..."
    
    local missing_bindings_result=$(analyze_bridge_structure | grep "MISSING_BINDINGS=" | cut -d'=' -f2)
    
    if [ -z "$missing_bindings_result" ]; then
        log_success "No missing bindings to generate"
        return 0
    fi
    
    local missing_bindings=($missing_bindings_result)
    
    for canister in "${missing_bindings[@]}"; do
        log_info "Generating binding for: $canister"
        
        # Check if canister has a .did file
        local did_file_paths=(
            "$AXIASYSTEM_PATH/src/declarations/$canister/$canister.did"
            "$AXIASYSTEM_PATH/.dfx/local/canisters/$canister/$canister.did"
            "$AXIASYSTEM_PATH/.dfx/testnet/canisters/$canister/$canister.did"
            "$AXIASYSTEM_PATH/.dfx/ic/canisters/$canister/$canister.did"
        )
        
        local did_file=""
        for path in "${did_file_paths[@]}"; do
            if [ -f "$path" ]; then
                did_file="$path"
                break
            fi
        done
        
        if [ -n "$did_file" ]; then
            log_info "Found DID file: $did_file"
            
            # Generate Rust binding using candid-extractor or didc
            if command -v didc >/dev/null 2>&1; then
                log_info "Generating Rust binding with didc..."
                cd "$BRIDGE_PATH"
                didc bind --target rust "$did_file" > "src/bindings/${canister}.rs" 2>/dev/null || {
                    log_warning "Failed to generate binding with didc for $canister"
                    continue
                }
                log_success "Generated binding: src/bindings/${canister}.rs"
            else
                log_warning "didc not found, cannot generate bindings automatically"
                log_info "Please install didc: cargo install didc"
            fi
        else
            log_warning "No DID file found for canister: $canister"
        fi
    done
}

# Update mod.rs files to include new bindings
update_mod_files() {
    log_info "Updating mod.rs files..."
    
    # Update bindings/mod.rs
    local bindings_mod="$BRIDGE_PATH/src/bindings/mod.rs"
    log_info "Updating $bindings_mod"
    
    # Backup original
    cp "$bindings_mod" "${bindings_mod}.backup"
    
    # Generate new mod.rs content
    {
        echo "// Auto-generated binding declarations"
        echo "// Last updated: $TIMESTAMP"
        echo ""
        
        # Add all binding modules
        find "$BRIDGE_PATH/src/bindings" -name "*.rs" | grep -v mod.rs | sort | while read -r file; do
            local module_name=$(basename "$file" .rs)
            echo "pub mod $module_name;"
        done
    } > "$bindings_mod"
    
    log_success "Updated bindings/mod.rs"
    
    # Update tools/modules/mod.rs if it exists
    local modules_mod="$BRIDGE_PATH/src/tools/modules/mod.rs"
    if [ -f "$modules_mod" ]; then
        log_info "Updating $modules_mod"
        cp "$modules_mod" "${modules_mod}.backup"
        
        {
            echo "// Auto-generated module declarations"
            echo "// Last updated: $TIMESTAMP"
            echo ""
            
            # Add all module declarations
            find "$BRIDGE_PATH/src/tools/modules" -name "*.rs" | grep -v mod.rs | sort | while read -r file; do
                local module_name=$(basename "$file" .rs)
                echo "pub mod $module_name;"
            done
        } > "$modules_mod"
        
        log_success "Updated tools/modules/mod.rs"
    fi
}

# Validate bridge compilation
validate_bridge() {
    log_info "Validating bridge compilation..."
    
    cd "$BRIDGE_PATH"
    
    # Check if Cargo.toml exists
    if [ ! -f "Cargo.toml" ]; then
        log_error "Cargo.toml not found in bridge directory"
        return 1
    fi
    
    # Attempt compilation check
    log_info "Running cargo check..."
    if cargo check --quiet 2>/dev/null; then
        log_success "Bridge compilation validation passed"
        return 0
    else
        log_warning "Bridge compilation issues detected, running detailed check..."
        cargo check 2>&1 | tee -a "$LOG_FILE"
        return 1
    fi
}

# Sync canister IDs to bridge constants
sync_canister_ids() {
    log_info "Syncing canister IDs to bridge constants..."
    
    local constants_file="$BRIDGE_PATH/src/constants.rs"
    local canister_ids_file="$AXIASYSTEM_PATH/canister_ids.json"
    
    if [ ! -f "$canister_ids_file" ]; then
        log_warning "canister_ids.json not found, skipping ID sync"
        return 0
    fi
    
    # Backup existing constants
    if [ -f "$constants_file" ]; then
        cp "$constants_file" "${constants_file}.backup"
    fi
    
    # Generate new constants file
    {
        echo "// Auto-generated canister ID constants"
        echo "// Last updated: $TIMESTAMP"
        echo "// Source: $canister_ids_file"
        echo ""
        echo "use ic_agent::Principal;"
        echo ""
        
        # Extract canister IDs and generate constants
        if command -v jq >/dev/null 2>&1; then
            jq -r 'to_entries[] | "\(.key | ascii_upcase)_CANISTER_ID"' "$canister_ids_file" 2>/dev/null | while read -r const_name; do
                local canister_name=$(echo "$const_name" | sed 's/_CANISTER_ID$//' | tr '[:upper:]' '[:lower:]')
                local canister_id=$(jq -r ".[\"$canister_name\"].local" "$canister_ids_file" 2>/dev/null || echo "")
                
                if [ -n "$canister_id" ] && [ "$canister_id" != "null" ]; then
                    echo "pub const $const_name: &str = \"$canister_id\";"
                fi
            done
        elif command -v python3 >/dev/null 2>&1; then
            # Use Python as fallback
            python3 -c "
import json
with open('$canister_ids_file', 'r') as f:
    data = json.load(f)
    for canister_name, info in data.items():
        const_name = canister_name.upper() + '_CANISTER_ID'
        if isinstance(info, dict) and 'local' in info:
            canister_id = info['local']
            print(f'pub const {const_name}: &str = \"{canister_id}\";')
        elif isinstance(info, str):
            print(f'pub const {const_name}: &str = \"{info}\";')
"
        else
            echo "// No JSON parser available (jq or python3 required)"
            echo "// Please manually update canister IDs"
        fi
        
        echo ""
        echo "// Helper function to get canister principal"
        echo "pub fn get_canister_principal(canister_id: &str) -> Result<Principal, String> {"
        echo "    Principal::from_text(canister_id).map_err(|e| format!(\"Invalid principal: {}\", e))"
        echo "}"
    } > "$constants_file"
    
    log_success "Updated bridge constants with current canister IDs"
}

# Run bridge tests if available
run_bridge_tests() {
    log_info "Running bridge tests..."
    
    cd "$BRIDGE_PATH"
    
    if [ -d "tests" ] && [ "$(find tests -name "*.rs" | wc -l)" -gt 0 ]; then
        log_info "Found test files, running cargo test..."
        
        if cargo test --quiet 2>/dev/null; then
            log_success "All bridge tests passed"
            return 0
        else
            log_warning "Some bridge tests failed, running with details..."
            cargo test 2>&1 | tee -a "$LOG_FILE"
            return 1
        fi
    else
        log_info "No test files found, skipping test execution"
        return 0
    fi
}

# Generate bridge documentation
generate_bridge_docs() {
    log_info "Generating bridge documentation..."
    
    cd "$BRIDGE_PATH"
    
    # Generate Rust docs
    if cargo doc --quiet --no-deps 2>/dev/null; then
        log_success "Generated Rust documentation"
    else
        log_warning "Failed to generate Rust documentation"
    fi
    
    # Create/update bridge overview documentation
    local bridge_doc="$AXIASYSTEM_PATH/documentation/BRIDGE_AUTOMATION_STATUS.md"
    
    {
        echo "# AxiaSystem Rust Bridge Automation Status"
        echo ""
        echo "**Last Updated:** $TIMESTAMP"
        echo "**Bridge Path:** $BRIDGE_PATH"
        echo ""
        echo "## Current Bridge Structure"
        echo ""
        echo "### Binding Files"
        find "$BRIDGE_PATH/src/bindings" -name "*.rs" | grep -v mod.rs | sort | while read -r file; do
            local module_name=$(basename "$file" .rs)
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            echo "- \`$module_name\` ($file_size bytes)"
        done
        
        echo ""
        echo "### Tool Modules"
        find "$BRIDGE_PATH/src/tools/modules" -name "*.rs" | grep -v mod.rs | sort | while read -r file; do
            local module_name=$(basename "$file" .rs)
            local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            echo "- \`$module_name\` ($file_size bytes)"
        done
        
        echo ""
        echo "## Automation Features"
        echo ""
        echo "- ✅ Automatic binding generation from DID files"
        echo "- ✅ Canister ID synchronization"
        echo "- ✅ Module declaration updates"
        echo "- ✅ Compilation validation"
        echo "- ✅ Test execution"
        echo "- ✅ Documentation generation"
        echo ""
        echo "## Usage"
        echo ""
        echo "\`\`\`bash"
        echo "# Full bridge update"
        echo "./bridge_automation_manager.sh --full-update"
        echo ""
        echo "# Quick sync only"
        echo "./bridge_automation_manager.sh --sync-only"
        echo ""
        echo "# Validation only"
        echo "./bridge_automation_manager.sh --validate-only"
        echo "\`\`\`"
        echo ""
        echo "## Logs"
        echo ""
        echo "Automation logs are stored in: \`$LOG_FILE\`"
        
    } > "$bridge_doc"
    
    log_success "Generated bridge documentation: $bridge_doc"
}

# Main automation workflow
run_full_update() {
    log_info "Running full bridge update workflow..."
    
    local success_count=0
    local total_steps=7
    
    # Step 1: Analyze current structure
    if analyze_bridge_structure; then
        ((success_count++))
    fi
    
    # Step 2: Generate missing bindings
    if generate_missing_bindings; then
        ((success_count++))
    fi
    
    # Step 3: Update mod files
    if update_mod_files; then
        ((success_count++))
    fi
    
    # Step 4: Sync canister IDs
    if sync_canister_ids; then
        ((success_count++))
    fi
    
    # Step 5: Validate compilation
    if validate_bridge; then
        ((success_count++))
    fi
    
    # Step 6: Run tests
    if run_bridge_tests; then
        ((success_count++))
    fi
    
    # Step 7: Generate documentation
    if generate_bridge_docs; then
        ((success_count++))
    fi
    
    # Report results
    log_info "Bridge automation completed: $success_count/$total_steps steps successful"
    
    if [ $success_count -eq $total_steps ]; then
        log_success "🎉 Bridge automation completed successfully!"
        return 0
    elif [ $success_count -gt $((total_steps / 2)) ]; then
        log_warning "⚠️  Bridge automation completed with some issues"
        return 1
    else
        log_error "❌ Bridge automation failed - multiple critical issues"
        return 2
    fi
}

# Command line interface
show_help() {
    echo "AxiaSystem Rust Bridge Automation Manager"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --full-update     Run complete bridge update workflow"
    echo "  --sync-only       Only sync canister IDs and update mod files"
    echo "  --validate-only   Only validate bridge compilation and tests"
    echo "  --analyze-only    Only analyze current bridge structure"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --full-update      # Complete automation"
    echo "  $0 --sync-only        # Quick sync after canister changes"
    echo "  $0 --validate-only    # Check bridge health"
    echo ""
}

# Main execution
main() {
    init_automation
    
    case "${1:-}" in
        --full-update)
            run_full_update
            ;;
        --sync-only)
            log_info "Running sync-only workflow..."
            sync_canister_ids && update_mod_files
            ;;
        --validate-only)
            log_info "Running validation-only workflow..."
            validate_bridge && run_bridge_tests
            ;;
        --analyze-only)
            log_info "Running analysis-only workflow..."
            analyze_bridge_structure
            ;;
        --help|-h)
            show_help
            ;;
        "")
            log_info "No arguments provided, running full update..."
            run_full_update
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
