#!/usr/bin/env bash
set -euo pipefail

# Deploys the RegisterNameCrossChainExecutor on POLYGON (values are baked into the .s.sol's _config()).
#
# Runs both steps in one go:
#   1. Dry-run: simulates the deployment and echoes every parameter for review.
#   2. If you confirm, broadcasts the deployment and verifies the contract on Polygonscan.
#
# Usage:
#   ./script/deploy-register-name-executor.sh --ledger --mnemonic-derivation-paths "m/44'/60'/4'/0/0"
#   ./script/deploy-register-name-executor.sh --account dev
#
# Reads ETHERSCAN_API_KEY (and optionally POLYGON_RPC_URL) from the repo .env.
# All arguments are passed through to `forge script` (wallet flags, --sender, etc.).

cd "$(dirname "$0")/.."

# Load the repo .env (ETHERSCAN_API_KEY lives there).
if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

: "${ETHERSCAN_API_KEY:?Set ETHERSCAN_API_KEY in the repo .env (an Etherscan V2 key works for all chains)}"

RPC_URL="${POLYGON_RPC_URL:-https://rpc.decentraland.org/polygon}"
FORGE_SCRIPT="script/DeployRegisterNameCrossChainExecutor.s.sol"

echo "==> Step 1/2: dry-run (simulation only, no transactions)"
forge script "$FORGE_SCRIPT" --rpc-url "$RPC_URL" "$@"

echo ""
read -r -p "==> Step 2/2: broadcast this deployment and verify it on Polygonscan? (y/N) " answer || answer=""
if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    echo "Aborted. Nothing was broadcast."
    exit 1
fi

forge script "$FORGE_SCRIPT" \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --verify \
    --etherscan-api-key "$ETHERSCAN_API_KEY" \
    "$@"
