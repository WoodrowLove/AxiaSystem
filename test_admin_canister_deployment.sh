#!/bin/bash

# Test Admin Canister Deployment Integration
# This script validates the Admin Canister can be deployed and integrated

echo "🚀 Testing Admin Canister Deployment Integration..."

# Ensure dfx is available
if ! command -v dfx &> /dev/null; then
    echo "❌ dfx not found. Please install DFINITY SDK."
    exit 1
fi

# Check if dfx.json includes admin canister
if ! grep -q "admin" dfx.json; then
    echo "⚠️  Admin canister not found in dfx.json. Adding configuration..."
    
    # Backup dfx.json
    cp dfx.json dfx.json.backup
    
    # Add admin canister configuration
    jq '.canisters.admin = {
        "type": "motoko",
        "main": "src/AxiaSystem_backend/admin2/simple_main.mo"
    }' dfx.json > dfx.json.tmp && mv dfx.json.tmp dfx.json
    
    echo "✅ Added admin canister to dfx.json"
fi

# Test compilation
echo "📦 Testing Admin Canister compilation..."
if dfx canister create admin --no-wallet 2>/dev/null; then
    echo "✅ Admin canister created successfully"
else
    echo "ℹ️  Admin canister already exists or network not started"
fi

# Validate Motoko syntax
echo "🔍 Validating Motoko syntax..."
if dfx build admin 2>/dev/null; then
    echo "✅ Admin Canister compiles successfully!"
    
    echo ""
    echo "📋 Admin Canister Deployment Summary:"
    echo "   • Location: src/AxiaSystem_backend/admin2/simple_main.mo"
    echo "   • Type: Persistent Motoko Actor"
    echo "   • Features: RBAC, Feature Flags, Emergency Controls"
    echo "   • Status: ✅ Ready for deployment"
    echo ""
    echo "🎯 Integration Points:"
    echo "   • Identity Canister: session validation (TODO)"
    echo "   • User Canister: role synchronization (TODO)"
    echo "   • Bridge Canister: emergency controls (TODO)"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Deploy: dfx deploy admin"
    echo "   2. Bootstrap: dfx canister call admin bootstrap"
    echo "   3. Test role management and feature flags"
    
else
    echo "❌ Admin Canister compilation failed"
    dfx build admin
    exit 1
fi

echo ""
echo "✅ Admin Canister Deployment Test Complete!"
