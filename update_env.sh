#!/bin/bash

# Path to the .env file
ENV_FILE=".env"

# Clear the existing .env file and add a header
echo "# Automatically generated .env file for backend canisters" > $ENV_FILE
echo "DFX_VERSION='$(dfx --version)'" >> $ENV_FILE
echo "DFX_NETWORK='local'" >> $ENV_FILE

# Array of all canisters
declare -a canisters=("AxiaSystem_backend" "AxiaSystem_frontend" "admin" "asset" "asset_registry" "escrow" "governance" "identity" "nft" "payment" "payment_monitoring" "payout" "split_payment" "subscriptions" "token" "treasury" "user" "wallet")

# Loop through each canister and update the .env file
for canister in "${canisters[@]}"
do
  canister_id=$(dfx canister id $canister 2>/dev/null)
  if [ -n "$canister_id" ]; then
    echo "CANISTER_ID_${canister^^}='${canister_id}'" >> $ENV_FILE
  else
    echo "WARNING: Could not fetch canister ID for $canister" >&2
  fi
done

echo "Environment variables updated in $ENV_FILE"


