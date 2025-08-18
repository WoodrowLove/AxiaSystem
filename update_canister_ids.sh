#!/bin/bash

# AxiaSystem Canister ID Management Script
# Automatically updates canister IDs across documentation and configuration files

set -e

echo "🔧 AxiaSystem Canister ID Management"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="/home/woodrowlove/AxiaSystem"
DFX_JSON="$PROJECT_ROOT/dfx.json"
CANISTER_IDS_JSON="$PROJECT_ROOT/canister_ids.json"
DOCS_DIR="$PROJECT_ROOT/documentation"
FRONTEND_CONFIG="$PROJECT_ROOT/src/declarations"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to get current canister IDs
get_current_canister_ids() {
    local network=${1:-local}
    local temp_file=$(mktemp)
    
    log_info "Retrieving canister IDs for network: $network"
    
    echo "{" > "$temp_file"
    local first=true
    
    # Get all canister names from dfx.json
    local canisters=$(jq -r '.canisters | keys[]' "$DFX_JSON" 2>/dev/null || echo "")
    
    for canister in $canisters; do
        if [[ "$first" == "false" ]]; then
            echo "," >> "$temp_file"
        fi
        
        # Try to get canister ID
        local canister_id=""
        if [[ "$network" == "local" ]]; then
            canister_id=$(dfx canister id "$canister" 2>/dev/null || echo "")
        else
            canister_id=$(dfx canister id "$canister" --network "$network" 2>/dev/null || echo "")
        fi
        
        if [[ -n "$canister_id" ]]; then
            echo "  \"$canister\": \"$canister_id\"" >> "$temp_file"
            log_success "Found $canister: $canister_id"
            first=false
        else
            log_warning "Could not retrieve ID for canister: $canister"
        fi
    done
    
    echo "}" >> "$temp_file"
    
    # Copy to canister_ids.json
    cp "$temp_file" "$CANISTER_IDS_JSON"
    rm "$temp_file"
    
    log_success "Updated $CANISTER_IDS_JSON"
}

# Function to update documentation files
update_documentation() {
    log_info "Updating documentation with current canister IDs"
    
    if [[ ! -f "$CANISTER_IDS_JSON" ]]; then
        log_error "canister_ids.json not found. Run with --fetch first."
        return 1
    fi
    
    # Read canister IDs
    local asset_canister=$(jq -r '.asset // empty' "$CANISTER_IDS_JSON")
    local asset_registry_canister=$(jq -r '.asset_registry // empty' "$CANISTER_IDS_JSON")
    local user_canister=$(jq -r '.user // empty' "$CANISTER_IDS_JSON")
    local identity_canister=$(jq -r '.identity // empty' "$CANISTER_IDS_JSON")
    local wallet_canister=$(jq -r '.wallet // empty' "$CANISTER_IDS_JSON")
    local backend_canister=$(jq -r '.AxiaSystem_backend // empty' "$CANISTER_IDS_JSON")
    
    # Update documentation files
    for doc_file in "$DOCS_DIR"/*.md; do
        if [[ -f "$doc_file" ]]; then
            local updated=false
            
            # Asset canister ID updates
            if [[ -n "$asset_canister" ]] && grep -q "bw4dl-smaaa-aaaaa-qaacq-cai\|asset-canister-id" "$doc_file"; then
                sed -i "s/bw4dl-smaaa-aaaaa-qaacq-cai/$asset_canister/g" "$doc_file"
                sed -i "s/asset-canister-id/$asset_canister/g" "$doc_file"
                updated=true
            fi
            
            # Asset registry canister ID updates
            if [[ -n "$asset_registry_canister" ]] && grep -q "asset-registry-canister-id\|b77ix-eeaaa-aaaaa-qaada-cai" "$doc_file"; then
                sed -i "s/asset-registry-canister-id/$asset_registry_canister/g" "$doc_file"
                sed -i "s/b77ix-eeaaa-aaaaa-qaada-cai/$asset_registry_canister/g" "$doc_file"
                updated=true
            fi
            
            # Backend canister ID updates
            if [[ -n "$backend_canister" ]] && grep -q "be2us-64aaa-aaaaa-qaabq-cai\|backend-canister-id" "$doc_file"; then
                sed -i "s/be2us-64aaa-aaaaa-qaabq-cai/$backend_canister/g" "$doc_file"
                sed -i "s/backend-canister-id/$backend_canister/g" "$doc_file"
                updated=true
            fi
            
            if [[ "$updated" == "true" ]]; then
                log_success "Updated $(basename "$doc_file")"
            fi
        fi
    done
}

# Function to generate frontend canister configuration
generate_frontend_config() {
    log_info "Generating frontend canister configuration"
    
    if [[ ! -f "$CANISTER_IDS_JSON" ]]; then
        log_error "canister_ids.json not found. Run with --fetch first."
        return 1
    fi
    
    # Create frontend config directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/src/config"
    
    # Generate TypeScript canister configuration
    cat > "$PROJECT_ROOT/src/config/canister-ids.ts" << EOF
// Auto-generated canister IDs - DO NOT EDIT MANUALLY
// Generated by update_canister_ids.sh on $(date)

export const CANISTER_IDS = $(cat "$CANISTER_IDS_JSON") as const;

// Individual canister exports for convenience
$(jq -r 'to_entries[] | "export const \(.key | ascii_upcase)_CANISTER_ID = \"\(.value)\";"' "$CANISTER_IDS_JSON")

// Network detection helper
export const getCanisterIds = (network: string = 'local') => {
  // In production, these IDs will be different
  // This function allows for network-specific overrides
  return CANISTER_IDS;
};

// Actor creation helper
export const createActorConfig = (canisterName: keyof typeof CANISTER_IDS) => {
  return {
    canisterId: CANISTER_IDS[canisterName],
    idlFactory: () => import(\`../declarations/\${canisterName}/\${canisterName}.did.js\`),
  };
};
EOF

    log_success "Generated src/config/canister-ids.ts"
    
    # Generate JavaScript version for non-TypeScript projects
    cat > "$PROJECT_ROOT/src/config/canister-ids.js" << EOF
// Auto-generated canister IDs - DO NOT EDIT MANUALLY
// Generated by update_canister_ids.sh on $(date)

export const CANISTER_IDS = $(cat "$CANISTER_IDS_JSON");

// Individual canister exports for convenience
$(jq -r 'to_entries[] | "export const \(.key | ascii_upcase)_CANISTER_ID = \"\(.value)\";"' "$CANISTER_IDS_JSON")

// Network detection helper
export const getCanisterIds = (network = 'local') => {
  // In production, these IDs will be different
  // This function allows for network-specific overrides
  return CANISTER_IDS;
};
EOF

    log_success "Generated src/config/canister-ids.js"
}

# Function to update dfx.json with current IDs
update_dfx_json() {
    log_info "Updating dfx.json with current canister IDs"
    
    if [[ ! -f "$CANISTER_IDS_JSON" ]]; then
        log_error "canister_ids.json not found. Run with --fetch first."
        return 1
    fi
    
    # Backup dfx.json
    cp "$DFX_JSON" "$DFX_JSON.backup"
    
    # Update canister IDs in dfx.json
    jq --argjson ids "$(cat "$CANISTER_IDS_JSON")" '
      .canisters |= with_entries(
        if $ids[.key] then 
          .value.canister_id = $ids[.key]
        else 
          .
        end
      )
    ' "$DFX_JSON" > "$DFX_JSON.tmp" && mv "$DFX_JSON.tmp" "$DFX_JSON"
    
    log_success "Updated dfx.json (backup saved as dfx.json.backup)"
}

# Function to create network-specific configuration
create_network_config() {
    local network=${1:-local}
    
    log_info "Creating network-specific configuration for: $network"
    
    # Create network-specific canister IDs file
    local network_file="$PROJECT_ROOT/canister_ids_$network.json"
    get_current_canister_ids "$network"
    cp "$CANISTER_IDS_JSON" "$network_file"
    
    log_success "Created $network_file"
}

# Function to validate canister IDs
validate_canister_ids() {
    log_info "Validating canister IDs"
    
    if [[ ! -f "$CANISTER_IDS_JSON" ]]; then
        log_error "canister_ids.json not found"
        return 1
    fi
    
    local valid=true
    
    # Check each canister ID format
    while IFS= read -r line; do
        local canister=$(echo "$line" | jq -r '.key')
        local id=$(echo "$line" | jq -r '.value')
        
        # Basic canister ID format validation (principal format)
        if [[ "$id" =~ ^[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{5}-[a-z0-9]{3}$ ]]; then
            log_success "Valid ID for $canister: $id"
        else
            log_error "Invalid ID format for $canister: $id"
            valid=false
        fi
    done < <(jq -r 'to_entries[]' "$CANISTER_IDS_JSON")
    
    if [[ "$valid" == "true" ]]; then
        log_success "All canister IDs are valid"
        return 0
    else
        log_error "Some canister IDs are invalid"
        return 1
    fi
}

# Main execution logic
case "${1:-}" in
    --fetch)
        NETWORK=${2:-local}
        get_current_canister_ids "$NETWORK"
        ;;
    --update-docs)
        update_documentation
        ;;
    --generate-frontend)
        generate_frontend_config
        ;;
    --update-dfx)
        update_dfx_json
        ;;
    --network)
        create_network_config "$2"
        ;;
    --validate)
        validate_canister_ids
        ;;
    --all)
        NETWORK=${2:-local}
        log_info "Running complete canister ID update for network: $NETWORK"
        get_current_canister_ids "$NETWORK"
        update_documentation
        generate_frontend_config
        update_dfx_json
        validate_canister_ids
        log_success "Complete canister ID update finished!"
        ;;
    --help|-h)
        echo "AxiaSystem Canister ID Management Script"
        echo ""
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  --fetch [network]      Fetch current canister IDs (default: local)"
        echo "  --update-docs          Update documentation with current IDs"
        echo "  --generate-frontend    Generate frontend configuration files"
        echo "  --update-dfx           Update dfx.json with current IDs"
        echo "  --network [name]       Create network-specific configuration"
        echo "  --validate             Validate canister ID formats"
        echo "  --all [network]        Run all updates (default: local)"
        echo "  --help, -h             Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 --fetch local       # Fetch local canister IDs"
        echo "  $0 --fetch ic          # Fetch mainnet canister IDs"
        echo "  $0 --all local         # Complete local update"
        echo "  $0 --all ic            # Complete mainnet update"
        echo ""
        ;;
    *)
        log_info "Running default: fetch local canister IDs and update documentation"
        get_current_canister_ids "local"
        update_documentation
        generate_frontend_config
        log_success "Basic update complete. Use --help for more options."
        ;;
esac

echo ""
echo "📊 Current Canister Status:"
if [[ -f "$CANISTER_IDS_JSON" ]]; then
    jq -r 'to_entries[] | "  \(.key): \(.value)"' "$CANISTER_IDS_JSON"
else
    echo "  No canister IDs file found."
fi
echo ""
