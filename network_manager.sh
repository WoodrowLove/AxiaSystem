#!/bin/bash

# Network Environment Manager for AxiaSystem
# Manages deployment and canister IDs across different environments

set -e

echo "🌐 AxiaSystem Network Environment Manager"
echo "========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="/home/woodrowlove/AxiaSystem"
NETWORKS_CONFIG="$PROJECT_ROOT/networks.json"

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to deploy to specific network
deploy_to_network() {
    local network=$1
    local canister=${2:-"all"}
    
    log_info "Deploying to network: $network"
    
    if [[ "$network" == "local" ]]; then
        # Local deployment
        if [[ "$canister" == "all" ]]; then
            dfx deploy --network local
        else
            dfx deploy "$canister" --network local
        fi
    elif [[ "$network" == "ic" ]]; then
        # Mainnet deployment (with cycles check)
        log_warning "Deploying to IC mainnet - this will consume cycles!"
        read -p "Are you sure you want to deploy to mainnet? (y/N): " confirm
        
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            if [[ "$canister" == "all" ]]; then
                dfx deploy --network ic --with-cycles 1000000000000
            else
                dfx deploy "$canister" --network ic --with-cycles 1000000000000
            fi
        else
            log_info "Mainnet deployment cancelled"
            return 0
        fi
    elif [[ "$network" == "testnet" ]]; then
        # Testnet deployment
        if [[ "$canister" == "all" ]]; then
            dfx deploy --network testnet
        else
            dfx deploy "$canister" --network testnet
        fi
    else
        log_error "Unknown network: $network"
        return 1
    fi
    
    # Update canister IDs after deployment
    log_info "Updating canister IDs for network: $network"
    "$PROJECT_ROOT/update_canister_ids.sh" --fetch "$network"
    
    # Create network-specific configuration
    "$PROJECT_ROOT/update_canister_ids.sh" --network "$network"
    
    log_success "Deployment to $network completed!"
}

# Function to switch between networks
switch_network() {
    local network=$1
    
    log_info "Switching to network: $network"
    
    # Update frontend configuration for the network
    if [[ -f "$PROJECT_ROOT/canister_ids_$network.json" ]]; then
        cp "$PROJECT_ROOT/canister_ids_$network.json" "$PROJECT_ROOT/canister_ids.json"
        "$PROJECT_ROOT/update_canister_ids.sh" --generate-frontend
        log_success "Switched to $network configuration"
    else
        log_warning "No configuration found for $network. Run deploy first."
    fi
}

# Function to check cycles balance (for IC mainnet)
check_cycles() {
    log_info "Checking cycles balance..."
    
    # Check wallet balance
    if dfx wallet balance --network ic 2>/dev/null; then
        log_success "Cycles balance retrieved"
    else
        log_warning "Could not retrieve cycles balance. Make sure you're authenticated with dfx."
    fi
}

# Function to create production deployment checklist
production_checklist() {
    echo ""
    echo "🚀 Production Deployment Checklist"
    echo "=================================="
    echo ""
    echo "Before deploying to IC mainnet:"
    echo "  ✅ Code has been tested locally"
    echo "  ✅ All tests pass"
    echo "  ✅ Security audit completed"
    echo "  ✅ Backup of current state created"
    echo "  ✅ Cycles wallet has sufficient balance"
    echo "  ✅ All dependencies are up to date"
    echo "  ✅ Configuration verified"
    echo ""
    echo "Deployment steps:"
    echo "  1. Deploy to testnet first: ./network_manager.sh --deploy testnet"
    echo "  2. Test on testnet thoroughly"
    echo "  3. Deploy to mainnet: ./network_manager.sh --deploy ic"
    echo "  4. Update frontend: ./network_manager.sh --switch ic"
    echo "  5. Verify all functionality"
    echo ""
}

# Main execution
case "${1:-}" in
    --deploy)
        NETWORK=${2:-local}
        CANISTER=${3:-all}
        deploy_to_network "$NETWORK" "$CANISTER"
        ;;
    --switch)
        NETWORK=${2:-local}
        switch_network "$NETWORK"
        ;;
    --cycles)
        check_cycles
        ;;
    --checklist)
        production_checklist
        ;;
    --status)
        log_info "Network Status:"
        echo ""
        for network in local ic testnet; do
            if [[ -f "$PROJECT_ROOT/canister_ids_$network.json" ]]; then
                echo "📍 $network: Configured"
                jq -r 'to_entries[] | "  \(.key): \(.value)"' "$PROJECT_ROOT/canister_ids_$network.json" | head -3
                echo "  ..."
            else
                echo "📍 $network: Not configured"
            fi
            echo ""
        done
        ;;
    --help|-h)
        echo "AxiaSystem Network Environment Manager"
        echo ""
        echo "Usage: $0 [COMMAND] [OPTIONS]"
        echo ""
        echo "Commands:"
        echo "  --deploy [network] [canister]  Deploy to network (local/ic/testnet)"
        echo "  --switch [network]             Switch frontend to network config"
        echo "  --cycles                       Check cycles balance for IC"
        echo "  --checklist                    Show production deployment checklist"
        echo "  --status                       Show configuration status for all networks"
        echo "  --help, -h                     Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 --deploy local              # Deploy all canisters locally"
        echo "  $0 --deploy ic asset           # Deploy asset canister to mainnet"
        echo "  $0 --switch ic                 # Switch frontend to mainnet config"
        echo "  $0 --cycles                    # Check cycles balance"
        echo ""
        ;;
    *)
        log_info "AxiaSystem Network Manager - use --help for commands"
        echo ""
        echo "Quick actions:"
        echo "  🏠 Local development:  $0 --deploy local"
        echo "  🧪 Testnet testing:   $0 --deploy testnet"  
        echo "  🚀 Mainnet deploy:    $0 --deploy ic"
        echo "  📊 Check status:      $0 --status"
        echo ""
        ;;
esac
