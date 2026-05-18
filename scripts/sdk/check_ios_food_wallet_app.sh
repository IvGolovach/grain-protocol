#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

APP_DIR="apps/ios-food-wallet"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-ios-food-wallet.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -d "$APP_DIR" ]]; then
  echo "SDK_IOS_FOOD_WALLET_ERR_MISSING: apps/ios-food-wallet is required" >&2
  exit 1
fi

python3 tools/ci/check_ios_food_wallet_app_store.py

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

has_raw_protocol_api() {
  local pattern='GrainClientFFI|grain_client_core|uniffi\.grain_client_core|dagcbor|dag_cbor|qrdecode|qr_decode|snapshotB64|trustPubB64|privateKeyB64|secretKeyB64'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" \
    "$APP_DIR/Sources/FoodWalletCore" \
    "$APP_DIR/Sources/FoodWalletApp" \
    "$APP_DIR/Sources/FoodWalletAppIntents" >/dev/null
}

if has_raw_protocol_api; then
  echo "SDK_IOS_FOOD_WALLET_ERR_RAW_PROTOCOL_API: app must use Food Wallet app-facing surfaces only" >&2
  exit 1
else
  RAW_API_STATUS=$?
  if [[ "$RAW_API_STATUS" -ne 1 ]]; then
    exit "$RAW_API_STATUS"
  fi
fi

has_raw_photo_retention() {
  local pattern='UIImageJPEGRepresentation|UIImagePNGRepresentation|writeToFile|FileManager\.default\.createFile|NSLog|os_log'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" \
    "$APP_DIR/Sources/FoodWalletCore" \
    "$APP_DIR/Sources/FoodWalletApp" \
    "$APP_DIR/Sources/FoodWalletAppIntents" >/dev/null
}

if has_raw_photo_retention; then
  echo "SDK_IOS_FOOD_WALLET_ERR_RAW_PHOTO_RETENTION: app must not store or log raw photo material" >&2
  exit 1
else
  PHOTO_STATUS=$?
  if [[ "$PHOTO_STATUS" -ne 1 ]]; then
    exit "$PHOTO_STATUS"
  fi
fi

swift build --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift"
swift run --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift" FoodWalletCoreTests
swift run --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift" FoodWalletSmoke

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_IOS_FOOD_WALLET_ERR_DIRTY_WORKTREE: check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "iOS Food Wallet app check: PASS"
