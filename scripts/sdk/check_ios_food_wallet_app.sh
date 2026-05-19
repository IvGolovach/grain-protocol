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
  local pattern='GrainClientFFI|grain_client_core|uniffi\.grain_client_core|dagcbor|dag_cbor|qrdecode|qr_decode|rawQrPayload|raw[_-]?qr[_-]?payload'
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
  local raw_photo_api_pattern='UIImageJPEGRepresentation|UIImagePNGRepresentation|UIImageWriteToSavedPhotosAlbum|PHPhotoLibrary'
  python3 tools/ci/find_regex_match.py --ignore-case "$raw_photo_api_pattern" \
    "$APP_DIR/Sources/FoodWalletCore" \
    "$APP_DIR/Sources/FoodWalletApp" \
    "$APP_DIR/Sources/FoodWalletAppIntents" >/dev/null && return 0
  local storage_status=$?
  if [[ "$storage_status" -ne 1 ]]; then
    return "$storage_status"
  fi

  local raw_material_pattern='jpegData|pngData|imageBytes|photoBytes|rawPhoto|base64EncodedString|TransientMealPhotoPayload|CapturedMealPhoto|rawQrPayload|raw[_-]?qr[_-]?payload|qr[_-]?(payload|string)|snapshotB64|snapshot[_-]?b64|syncBundle|sync[_-]?bundle|identityBundle|identity[_-]?bundle|trustBundle|trust[_-]?bundle|trustPubB64|trust[_-]?pub[_-]?b64|privateKeyB64|private[_-]?key[_-]?b64|secretKeyB64|secret[_-]?key[_-]?b64|coseB64|cose[_-]?b64'
  local write_pattern='writeToFile|\.write\s*\(|FileManager\.default\.(createFile|copyItem|moveItem)|UserDefaults\.standard\.(set|data)|NSKeyedArchiver'
  local retained_raw_material_pattern="($write_pattern)[^\n]*($raw_material_pattern)|($raw_material_pattern)[^\n]*($write_pattern)"
  python3 tools/ci/find_regex_match.py --ignore-case "$retained_raw_material_pattern" \
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

has_raw_photo_logging() {
  local pattern='(print|debugPrint|NSLog|os_log|Logger\.[A-Za-z]+)\s*\([^)]*(jpegData|pngData|imageBytes|photoBytes|rawPhoto|base64EncodedString|TransientMealPhotoPayload)'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" \
    "$APP_DIR/Sources/FoodWalletCore" \
    "$APP_DIR/Sources/FoodWalletApp" \
    "$APP_DIR/Sources/FoodWalletAppIntents" >/dev/null
}

if has_raw_photo_logging; then
  echo "SDK_IOS_FOOD_WALLET_ERR_RAW_PHOTO_LOGGING: app must not log raw photo material" >&2
  exit 1
else
  PHOTO_LOG_STATUS=$?
  if [[ "$PHOTO_LOG_STATUS" -ne 1 ]]; then
    exit "$PHOTO_LOG_STATUS"
  fi
fi

has_direct_provider_usage() {
  local pattern='api\.openai\.com|OPENAI_API_KEY|sk-proj-|sk-[A-Za-z0-9_-]{20,}|USDA_API_KEY|FOODDATA_CENTRAL|FDC_API_KEY|api\.nal\.usda\.gov|api\.data\.gov'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" \
    "$APP_DIR/Sources/FoodWalletCore" \
    "$APP_DIR/Sources/FoodWalletApp" \
    "$APP_DIR/Sources/FoodWalletAppIntents" \
    "$APP_DIR/AppStore/Info.plist" >/dev/null
}

if has_direct_provider_usage; then
  echo "SDK_IOS_FOOD_WALLET_ERR_DIRECT_PROVIDER_USAGE: iOS app must use a backend broker, not embedded OpenAI/USDA keys or direct provider calls" >&2
  exit 1
else
  PROVIDER_STATUS=$?
  if [[ "$PROVIDER_STATUS" -ne 1 ]]; then
    exit "$PROVIDER_STATUS"
  fi
fi

scripts/sdk/check_food_analysis_broker.sh

swift build --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift"
swift run --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift" FoodWalletCoreTests
swift run --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift" FoodWalletSmoke

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_IOS_FOOD_WALLET_ERR_DIRTY_WORKTREE: check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "iOS MealMark app check: PASS"
