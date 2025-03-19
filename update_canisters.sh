#!/bin/bash

echo "Updating canister IDs..."

# Get the latest canister IDs from `dfx.json`
for CANISTER in AxiaSystem_backend admin2 asset asset_registry escrow governance identity nft payment payment_monitoring payout split_payment subscriptions token treasury user wallet
do
    ID=$(dfx canister id $CANISTER)
    echo "$CANISTER=$ID"
    
    # Update .env file
    echo "$CANISTER=$ID" >> .env
done

echo "✅ Canister IDs updated successfully!"
