#!/bin/bash

# Set the correct path to your Rust bridge bindings directory
BINDINGS_DIR="/home/woodrowlove/AxiaSystem-Rust-Bridge/src/bindings"
DECLARATIONS_DIR="/home/woodrowlove/AxiaSystem/src/declarations"

# Ensure the bindings directory exists
mkdir -p "$BINDINGS_DIR"

# Generate Rust bindings for all canisters
didc bind -t rs "$DECLARATIONS_DIR/AxiaSystem_backend/AxiaSystem_backend.did" > "$BINDINGS_DIR/AxiaSystem_backend.rs"
didc bind -t rs "$DECLARATIONS_DIR/token/token.did" > "$BINDINGS_DIR/token.rs"
didc bind -t rs "$DECLARATIONS_DIR/user/user.did" > "$BINDINGS_DIR/user.rs"
didc bind -t rs "$DECLARATIONS_DIR/wallet/wallet.did" > "$BINDINGS_DIR/wallet.rs"
didc bind -t rs "$DECLARATIONS_DIR/payment/payment.did" > "$BINDINGS_DIR/payment.rs"
didc bind -t rs "$DECLARATIONS_DIR/payment_monitoring/payment_monitoring.did" > "$BINDINGS_DIR/payment_monitoring.rs"
didc bind -t rs "$DECLARATIONS_DIR/escrow/escrow.did" > "$BINDINGS_DIR/escrow.rs"
didc bind -t rs "$DECLARATIONS_DIR/payout/payout.did" > "$BINDINGS_DIR/payout.rs"
didc bind -t rs "$DECLARATIONS_DIR/nft/nft.did" > "$BINDINGS_DIR/nft.rs"
didc bind -t rs "$DECLARATIONS_DIR/subscriptions/subscriptions.did" > "$BINDINGS_DIR/subscriptions.rs"
didc bind -t rs "$DECLARATIONS_DIR/asset_registry/asset_registry.did" > "$BINDINGS_DIR/asset_registry.rs"
didc bind -t rs "$DECLARATIONS_DIR/split_payment/split_payment.did" > "$BINDINGS_DIR/split_payment.rs"
didc bind -t rs "$DECLARATIONS_DIR/asset/asset.did" > "$BINDINGS_DIR/asset.rs"
didc bind -t rs "$DECLARATIONS_DIR/identity/identity.did" > "$BINDINGS_DIR/identity.rs"
didc bind -t rs "$DECLARATIONS_DIR/admin/admin.did" > "$BINDINGS_DIR/admin.rs"
didc bind -t rs "$DECLARATIONS_DIR/treasury/treasury.did" > "$BINDINGS_DIR/treasury.rs"
didc bind -t rs "$DECLARATIONS_DIR/governance/governance.did" > "$BINDINGS_DIR/governance.rs"

echo "✅ Rust bindings updated successfully with Debug trait!"


# AxiaVote Canisters
didc bind -t rs "/home/woodrowlove/axiavote/.dfx/local/canisters/election/election.did" > "$BINDINGS_DIR/election.rs"
didc bind -t rs "/home/woodrowlove/axiavote/.dfx/local/canisters/vote/vote.did" > "$BINDINGS_DIR/vote.rs"

# AxiaSocial Canister
didc bind -t rs "/home/woodrowlove/axia_social/src/declarations/social_credit/social_credit.did" > "$BINDINGS_DIR/social_credit.rs"