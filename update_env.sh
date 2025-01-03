#!/bin/bash

# Path to the .env file
ENV_FILE=".env"

# Clear the existing .env file and add a header
echo "# Automatically generated .env file for backend canisters" > $ENV_FILE
echo "DFX_VERSION='$(dfx --version)'" >> $ENV_FILE
echo "DFX_NETWORK='local'" >> $ENV_FILE

# Specify each canister by name and add its ID to the .env file
declare -a canisters=("AxiaSystem_backend" "AxiaSystem_frontend" "token" "user" "wallet" "payment" "payment_monitoring" "escrow" "payout" "nft" "subscriptions" "asset_registry" "split_payment" "asset")

for canister in "${canisters[@]}"
do
  canister_id=$(dfx canister id $canister)
  echo "CANISTER_ID_${canister^^}='${canister_id}'" >> $ENV_FILE
done

echo "Environment variables updated in $ENV_FILE"


