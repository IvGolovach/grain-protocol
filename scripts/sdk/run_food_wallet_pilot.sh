#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
OUT_DIR="artifacts/sdk-food-wallet-pilot/$COMMIT_SHA"

usage() {
  cat <<'EOF'
Usage: scripts/sdk/run_food_wallet_pilot.sh [options]

Runs the Food Wallet local developer pilot:
Food Wallet contract policy, local Food pilot append/reduce proof, and safe
report validation.

Options:
  --out-dir <path>      Output directory inside the repository
  -h, --help            Show this help

This is local source validation. It does not require phones, cameras, external
apps, external credentials, accounts, backends, app stores, or a specific AI
provider.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      if [[ -z "$OUT_DIR" ]]; then
        echo "SDK_FOOD_WALLET_PILOT_ERR_ARG_MISSING: --out-dir requires a path" >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "SDK_FOOD_WALLET_PILOT_ERR_UNKNOWN_ARG: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

resolve_out_dir() {
  local raw="$1"
  local candidate
  if [[ "$raw" = /* ]]; then
    candidate="$raw"
  else
    candidate="$ROOT/${raw#./}"
  fi

  local resolved
  resolved="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$candidate")"
  case "$resolved" in
    "$ROOT"|"$ROOT"/*)
      printf '%s\n' "$resolved"
      ;;
    *)
      echo "SDK_FOOD_WALLET_PILOT_ERR_OUT_DIR_OUTSIDE_REPO: out-dir must be inside repository root" >&2
      exit 1
      ;;
  esac
}

OUT_DIR_ABS="$(resolve_out_dir "$OUT_DIR")"
PILOT_OUT_DIR="$OUT_DIR_ABS/local-food-pilot"
REPORT="$PILOT_OUT_DIR/local-food-pilot.json"
BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=normal)"

contract_args=(--expected-commit "$COMMIT_SHA")
if [[ -z "$BEFORE_STATUS" ]]; then
  contract_args+=(--require-clean)
fi

scripts/sdk/check_food_wallet_contract.sh
scripts/sdk/run_local_food_pilot.sh --out-dir "$PILOT_OUT_DIR"
scripts/sdk/check_food_wallet_contract.sh --report "$REPORT" "${contract_args[@]}"

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=normal)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_FOOD_WALLET_PILOT_ERR_DIRTY_WORKTREE_CHANGED: Food Wallet pilot changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

printf 'Food Wallet pilot: PASS\n'
printf 'artifacts: %s\n' "$OUT_DIR_ABS"
printf 'report: %s\n' "$REPORT"
