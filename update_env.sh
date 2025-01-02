#!/bin/bash

# Path to the .env file
ENV_FILE=".env"

# Clear the existing .env file and add a header
echo "# Automatically generated .env file for backend canisters" > $ENV_FILE
echo "DFX_VERSION='$(dfx --version)'" >> $ENV_FILE
echo "DFX_NETWORK='local'" >> $ENV_FILE

# Loop through all backend canisters defined in dfx.json
for canister in $(dfx canister list | awk '{print $1}')
do
  canister_id=$(dfx canister id $canister)
  echo "CANISTER_ID_${canister^^}='${canister_id}'" >> $ENV_FILE
done

echo "Environment variables updated in $ENV_FILE"