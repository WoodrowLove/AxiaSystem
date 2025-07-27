#!/bin/bash
# 🌉 Namora Bridge Build and Integration Script

set -e

echo "🌉 Building Namora Bridge..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ]; then
    print_error "Cargo.toml not found. Please run this script from the bridge directory."
    exit 1
fi

# Check if rust is installed
if ! command -v cargo &> /dev/null; then
    print_error "Rust/Cargo not found. Please install Rust: https://rustup.rs/"
    exit 1
fi

print_status "Building Rust bridge..."

# Build the bridge
cargo build --release

if [ $? -eq 0 ]; then
    print_success "Bridge compiled successfully!"
else
    print_error "Bridge compilation failed!"
    exit 1
fi

# Check the output
if [ -f "target/release/libnamora_bridge.so" ]; then
    print_success "Linux shared library built: target/release/libnamora_bridge.so"
elif [ -f "target/release/libnamora_bridge.dylib" ]; then
    print_success "macOS shared library built: target/release/libnamora_bridge.dylib"
else
    print_warning "No shared library found, but build succeeded."
fi

# Show file info
print_status "Bridge library details:"
if [ -f "target/release/libnamora_bridge.so" ]; then
    ls -lh target/release/libnamora_bridge.so
elif [ -f "target/release/libnamora_bridge.dylib" ]; then
    ls -lh target/release/libnamora_bridge.dylib
fi

# Verify exports (Linux only)
if command -v nm &> /dev/null && [ -f "target/release/libnamora_bridge.so" ]; then
    print_status "Verifying FFI exports..."
    exports=$(nm -D target/release/libnamora_bridge.so | grep "rust_" | wc -l)
    print_success "Found $exports FFI functions exported"
fi

print_status "Available FFI functions:"
echo "  - rust_bridge_initialize()"
echo "  - rust_bridge_health()"
echo "  - rust_get_bridge_metadata()"
echo "  - rust_push_insight()"
echo "  - rust_get_recent_insights()"
echo "  - rust_get_system_health()"
echo "  - rust_create_user()"
echo "  - rust_ping_agent()"
echo "  - rust_log_last_n_calls()"
echo "  - rust_list_failed_calls()"

print_success "🌉 Namora Bridge build complete!"

# Instructions for integration
echo ""
print_status "Next steps for integration:"
echo "1. Copy the shared library to your frontend project"
echo "2. Install ffi-napi: npm install ffi-napi"
echo "3. Load the bridge in your API routes"
echo "4. Configure canister endpoints"
echo "5. Initialize with identity.pem"

# Example configuration
echo ""
print_status "Example configuration:"
cat << 'EOF'
{
  "network_url": "https://ic0.app",
  "identity_path": "./identity.pem", 
  "timeout_seconds": 30,
  "canister_endpoints": {
    "namora_ai": "rdmx6-jaaaa-aaaah-qdrqq-cai",
    "user": "xad5d-bh777-77774-qaaia-cai",
    "payment": "rno2w-sqaaa-aaaah-qdrra-cai"
  }
}
EOF
