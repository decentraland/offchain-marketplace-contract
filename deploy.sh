#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# One-shot deployer for the marketplace stacks.
#
# Usage:
#   ./deploy.sh <Stack> [broadcast]
#
#   ./deploy.sh DeployAmoyStack             # DRY-RUN: simulate + show the "are you sure?" banner
#   ./deploy.sh DeployAmoyStack broadcast   # actually deploy (+ verify)
#
# <Stack> is any of: DeployEthereumStack | DeploySepoliaStack | DeployPolygonStack | DeployAmoyStack
# (".s.sol" and the "script/" prefix are optional, so "DeployAmoyStack.s.sol" also works).
#
# This fills in everything that never changes (rpc url, chain, verify, explorer key, signer),
# choosing them per network from the stack name. Secrets/URLs live in .env — never hardcode them here.
#
# Expected in .env (gitignored):
#   SEPOLIA_RPC_URL=...   AMOY_RPC_URL=...   ETHEREUM_RPC_URL=...   POLYGON_RPC_URL=...
#   ETHERSCAN_API_KEY=...            # single Etherscan v2 key works for all four chains
#   # optional:
#   SENDER=0xYourDeployerAddress     # makes the dry-run banner show the real signer/owner
#
# How you sign (precedence: PRIVATE_KEY > LEDGER > keystore):
#   private key : PRIVATE_KEY=0x...        # the script adds --private-key
#   ledger      : LEDGER=true              # and set SENDER=0xYourLedgerAddress
#   keystore    : leave both unset -> "--account ${KEYSTORE_ACCOUNT:-deployer}"
#                 (import once: cast wallet import deployer --interactive)
# ---------------------------------------------------------------------------

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# Load .env (RPC urls, ETHERSCAN_API_KEY, SENDER, SIGNER_ARGS). .env is gitignored.
if [[ -f .env ]]; then set -a; source ./.env; set +a; fi

# Signer selection. Precedence: PRIVATE_KEY > LEDGER > keystore (KEYSTORE_ACCOUNT, default "deployer").
#   PRIVATE_KEY=0x...     -> --private-key
#   LEDGER=true           -> --ledger   (also set SENDER=0x... to pick the address)
#   otherwise             -> --account "${KEYSTORE_ACCOUNT:-deployer}"
if [[ -n "${PRIVATE_KEY:-}" ]]; then
  SIGNER=(--private-key "$PRIVATE_KEY")
elif [[ "${LEDGER:-}" == "true" ]]; then
  SIGNER=(--ledger)
  [[ -z "${SENDER:-}" ]] && echo "warning: LEDGER=true but SENDER is unset; set SENDER=0x... to pick the ledger address" >&2
else
  SIGNER=(--account "${KEYSTORE_ACCOUNT:-deployer}")
fi

STACK_INPUT="${1:-}"
MODE="${2:-dry}"

if [[ -z "$STACK_INPUT" ]]; then
  echo "usage: ./deploy.sh <Stack> [broadcast]   e.g. ./deploy.sh DeployAmoyStack broadcast" >&2
  exit 1
fi

# Normalize: accept "DeployAmoyStack", "DeployAmoyStack.s.sol" or "script/DeployAmoyStack.s.sol".
BASE="$(basename "$STACK_INPUT")"; BASE="${BASE%.s.sol}"; BASE="${BASE%.sol}"
SCRIPT_PATH="script/${BASE}.s.sol"
[[ -f "$SCRIPT_PATH" ]] || { echo "no such stack: $SCRIPT_PATH" >&2; exit 1; }

# Map stack -> network (rpc url comes from .env; chain drives the right verifier).
case "$BASE" in
  DeployEthereumStack) RPC_URL="${ETHEREUM_RPC_URL:-}"; CHAIN="mainnet" ;;
  DeploySepoliaStack)  RPC_URL="${SEPOLIA_RPC_URL:-}";  CHAIN="sepolia" ;;
  DeployPolygonStack)  RPC_URL="${POLYGON_RPC_URL:-}";  CHAIN="polygon" ;;
  DeployAmoyStack)     RPC_URL="${AMOY_RPC_URL:-}";     CHAIN="amoy" ;;
  *) echo "unknown stack '$BASE' (expected Deploy{Ethereum,Sepolia,Polygon,Amoy}Stack)" >&2; exit 1 ;;
esac

[[ -n "$RPC_URL" ]] || { echo "missing RPC url in .env for $BASE (set ETHEREUM_RPC_URL / SEPOLIA_RPC_URL / POLYGON_RPC_URL / AMOY_RPC_URL)" >&2; exit 1; }

CMD=(forge script "$SCRIPT_PATH" --rpc-url "$RPC_URL" --chain "$CHAIN")

if [[ "$MODE" == "broadcast" ]]; then
  CMD+=(--broadcast "${SIGNER[@]}")
  # Ledger needs an explicit --sender; --private-key and --account derive it themselves
  # (passing a mismatching --sender would make forge revert), so only forward it for ledger.
  if [[ "${LEDGER:-}" == "true" && -n "${SENDER:-}" ]]; then CMD+=(--sender "$SENDER"); fi
  [[ -n "${ETHERSCAN_API_KEY:-}" ]] && CMD+=(--verify --etherscan-api-key "$ETHERSCAN_API_KEY")
  echo ">> BROADCASTING $BASE to $CHAIN"
else
  # In a dry-run no signer is used, so --sender is what makes the "are you sure?" banner
  # (and the auto-wire owner check) reflect your real deployer address.
  [[ -n "${SENDER:-}" ]] && CMD+=(--sender "$SENDER")
  echo ">> DRY-RUN $BASE on $CHAIN (no broadcast)."
  echo "   Review the banner below, then run:  ./deploy.sh $BASE broadcast"
fi

# Echo the command, but never print secrets (private key, explorer API key).
DISPLAY_CMD="${CMD[*]}"
[[ -n "${PRIVATE_KEY:-}" ]] && DISPLAY_CMD="${DISPLAY_CMD//$PRIVATE_KEY/<redacted>}"
[[ -n "${ETHERSCAN_API_KEY:-}" ]] && DISPLAY_CMD="${DISPLAY_CMD//$ETHERSCAN_API_KEY/<redacted>}"
echo "+ $DISPLAY_CMD"
"${CMD[@]}"
