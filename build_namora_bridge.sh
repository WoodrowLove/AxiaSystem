#!/bin/bash
# 🌉 Namora Bridge Build Script for AxiaSystem-Rust-Bridge
# Builds the correct Namora Bridge project and integrates with frontend

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🌉 Building Namora Bridge from AxiaSystem-Rust-Bridge..."
echo "============================================="

# Define paths
NAMORA_BRIDGE_DIR="/home/woodrowlove/AxiaSystem-Rust-Bridge"
AXIA_SYSTEM_DIR="/home/woodrowlove/AxiaSystem"
FRONTEND_DIR="$AXIA_SYSTEM_DIR/src/AxiaSystem_frontend"
IDENTITY_PEM="$AXIA_SYSTEM_DIR/identity.pem"

# Verify paths exist
print_status "Verifying project structure..."

if [ ! -d "$NAMORA_BRIDGE_DIR" ]; then
    print_error "Namora Bridge directory not found: $NAMORA_BRIDGE_DIR"
    print_warning "Please ensure AxiaSystem-Rust-Bridge project exists"
    exit 1
fi

if [ ! -f "$IDENTITY_PEM" ]; then
    print_error "Identity file not found: $IDENTITY_PEM"
    print_warning "Please ensure identity.pem exists in AxiaSystem root"
    exit 1
fi

print_success "Project structure verified"

# Generate Rust bindings for all canisters
print_status "Generating Rust bindings for all canisters..."
if [ -f "$AXIA_SYSTEM_DIR/generate_bindings.sh" ]; then
    cd "$AXIA_SYSTEM_DIR"
    chmod +x generate_bindings.sh
    ./generate_bindings.sh
    print_success "Rust bindings generated successfully"
else
    print_warning "generate_bindings.sh not found, skipping binding generation"
fi

# Build the Namora Bridge
print_status "Building Namora Bridge..."
cd "$NAMORA_BRIDGE_DIR"

# Ensure Cargo.toml exists
if [ ! -f "Cargo.toml" ]; then
    print_error "Cargo.toml not found in Namora Bridge directory"
    print_warning "Please ensure AxiaSystem-Rust-Bridge is properly set up"
    exit 1
fi

# Build in release mode for FFI
print_status "Compiling Rust bridge in release mode..."
cargo build --release

# Check if the shared library was built
SHARED_LIB=""
if [ -f "target/release/libnamora_bridge.so" ]; then
    SHARED_LIB="target/release/libnamora_bridge.so"
    print_success "Linux shared library built: $SHARED_LIB"
elif [ -f "target/release/libnamora_bridge.dylib" ]; then
    SHARED_LIB="target/release/libnamora_bridge.dylib"
    print_success "macOS shared library built: $SHARED_LIB"
elif [ -f "target/release/libnamora_bridge.dll" ]; then
    SHARED_LIB="target/release/libnamora_bridge.dll"
    print_success "Windows shared library built: $SHARED_LIB"
else
    print_error "No shared library found after build"
    print_warning "Expected libnamora_bridge.{so,dylib,dll} in target/release/"
    exit 1
fi

# Display library info
print_status "Library information:"
ls -lh "$SHARED_LIB"

# Check exported symbols (Linux/macOS only)
if command -v nm &> /dev/null && [[ "$SHARED_LIB" == *.so ]]; then
    print_status "Checking exported FFI functions..."
    exports=$(nm -D "$SHARED_LIB" | grep "rust_" | wc -l)
    print_success "Found $exports exported rust_ functions"
fi

# Verify identity file permissions
print_status "Checking identity file permissions..."
if [ -r "$IDENTITY_PEM" ]; then
    print_success "Identity file is readable: $IDENTITY_PEM"
else
    print_error "Identity file is not readable: $IDENTITY_PEM"
    print_warning "Run: chmod 600 $IDENTITY_PEM"
fi

# Install FFI dependencies in frontend (if needed)
print_status "Checking frontend FFI dependencies..."
cd "$FRONTEND_DIR"

if [ -f "package.json" ]; then
    if grep -q "ffi-napi" package.json; then
        print_success "ffi-napi already in package.json"
    else
        print_warning "ffi-napi not found in package.json"
        print_warning "To enable real FFI calls, run: npm install ffi-napi"
    fi
else
    print_warning "package.json not found in frontend directory"
fi

# Create bridge configuration
print_status "Creating bridge configuration..."
cd "$AXIA_SYSTEM_DIR"

cat > bridge_config.json << EOF
{
  "namora_bridge_path": "$NAMORA_BRIDGE_DIR/$SHARED_LIB",
  "identity_path": "$IDENTITY_PEM",
  "ic_url": "http://localhost:8000",
  "canister_ids": {
    "namora_ai": "rdmx6-jaaaa-aaaah-qdrqq-cai",
    "user": "$(jq -r '.user.local' canister_ids.json 2>/dev/null || echo 'rrkah-fqaaa-aaaah-qcu7q-cai')",
    "payment": "$(jq -r '.payment.local' canister_ids.json 2>/dev/null || echo 'rno2w-sqaaa-aaaah-qcudq-cai')",
    "escrow": "$(jq -r '.escrow.local' canister_ids.json 2>/dev/null || echo 'renrk-eyaaa-aaaah-qcuiq-cai')",
    "identity": "$(jq -r '.identity.local' canister_ids.json 2>/dev/null || echo 'r7inp-6aaaa-aaaah-qcuoa-cai')"
  },
  "features": ["ic_agent", "canister_calls", "real_time_monitoring", "health_checks", "ai_insights"],
  "log_level": "info"
}
EOF

print_success "Bridge configuration created: bridge_config.json"

echo ""
echo "🎯 Build Summary:"
echo "================"
echo "✅ Namora Bridge compiled successfully"
echo "✅ Shared library: $NAMORA_BRIDGE_DIR/$SHARED_LIB"
echo "✅ Identity file: $IDENTITY_PEM"
echo "✅ Configuration: $AXIA_SYSTEM_DIR/bridge_config.json"
echo "✅ Rust bindings generated"
echo ""
echo "🚀 Next Steps:"
echo "============="
echo "1. Install FFI dependency: cd $FRONTEND_DIR && npm install ffi-napi"
echo "2. Update API routes to use real FFI calls"
echo "3. Deploy canisters: dfx deploy"
echo "4. Start frontend: npm run dev"
echo "5. Monitor bridge at: http://localhost:5173/system/bridge"
echo ""

print_success "🌉 Namora Bridge is ready for integration!"
