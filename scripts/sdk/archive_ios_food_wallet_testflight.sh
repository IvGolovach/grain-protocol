#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/apps/ios-food-wallet"
PROJECT_PATH="$APP_DIR/FoodWallet.xcodeproj"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCODEBUILD="${XCODEBUILD:-$DEVELOPER_DIR/usr/bin/xcodebuild}"
BUNDLE_ID="${GRAIN_IOS_BUNDLE_ID:-dev.grain.foodwallet}"
TEAM_ID="${GRAIN_IOS_DISTRIBUTION_TEAM:-}"
PROVISIONING_PROFILE_SPECIFIER="${GRAIN_IOS_PROVISIONING_PROFILE_SPECIFIER:-}"
PROVISIONING_PROFILE_UUID="${GRAIN_IOS_PROVISIONING_PROFILE_UUID:-}"
CODE_SIGN_IDENTITY="${GRAIN_IOS_CODE_SIGN_IDENTITY:-Apple Distribution}"
DEFAULT_BROKER_URL="https://mealmark-food-analysis-broker-staging.ivan-f7b.workers.dev"
BROKER_URL="${GRAIN_FOOD_ANALYSIS_BROKER_URL:-$DEFAULT_BROKER_URL}"
ARCHIVE_PATH="${GRAIN_IOS_ARCHIVE_PATH:-$ROOT_DIR/artifacts/ios-food-wallet/MealMark.xcarchive}"
DERIVED_DATA="${GRAIN_IOS_DERIVED_DATA:-$ROOT_DIR/artifacts/ios-food-wallet-archive-derived}"
BUILD_NUMBER="${GRAIN_IOS_BUILD_NUMBER:-}"
SKIP_LOCAL_VALIDATION="${GRAIN_IOS_SKIP_LOCAL_VALIDATION:-0}"
SKIP_STAGING_BROKER_CHECK="${GRAIN_IOS_SKIP_STAGING_BROKER_CHECK:-0}"
export DEVELOPER_DIR

usage() {
  cat <<'EOF'
Usage: scripts/sdk/archive_ios_food_wallet_testflight.sh

Build a Release .xcarchive suitable for TestFlight upload, then inspect it for
the safety properties that matter before App Store Connect processing.

Required:
  GRAIN_IOS_DISTRIBUTION_TEAM   Apple Developer Team ID used for distribution signing

Optional:
  GRAIN_FOOD_ANALYSIS_BROKER_URL  Public HTTPS MealMark broker URL
  GRAIN_IOS_BUILD_NUMBER          Override CURRENT_PROJECT_VERSION for this upload
  GRAIN_IOS_PROVISIONING_PROFILE_SPECIFIER
                                  Installed App Store provisioning profile name,
                                  for example "MealMark App Store"
  GRAIN_IOS_PROVISIONING_PROFILE_UUID
                                  Installed App Store provisioning profile UUID
  GRAIN_IOS_CODE_SIGN_IDENTITY    Signing identity for manual profile archives
                                  (default: Apple Distribution)
  GRAIN_IOS_ARCHIVE_PATH          Output .xcarchive path
  GRAIN_IOS_DERIVED_DATA          DerivedData path
  GRAIN_IOS_SKIP_LOCAL_VALIDATION Set to 1 to skip the heavy app check
  GRAIN_IOS_SKIP_STAGING_BROKER_CHECK
                                  Set to 1 to skip staging broker smoke
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$TEAM_ID" ]]; then
  echo "IOS_FOOD_WALLET_ARCHIVE_ERR_TEAM: set GRAIN_IOS_DISTRIBUTION_TEAM" >&2
  exit 1
fi

if [[ -n "$PROVISIONING_PROFILE_SPECIFIER" && -n "$PROVISIONING_PROFILE_UUID" ]]; then
  echo "IOS_FOOD_WALLET_ARCHIVE_ERR_PROFILE: set only one of GRAIN_IOS_PROVISIONING_PROFILE_SPECIFIER or GRAIN_IOS_PROVISIONING_PROFILE_UUID" >&2
  exit 1
fi

if [[ -n "${GRAIN_FOOD_BROKER_DEV_TOKEN:-${FOOD_BROKER_DEV_TOKEN:-}}" ]]; then
  echo "IOS_FOOD_WALLET_ARCHIVE_ERR_DEV_TOKEN: do not pass broker dev tokens into TestFlight archives" >&2
  exit 1
fi

case "$BROKER_URL" in
  https://*)
    ;;
  "")
    echo "IOS_FOOD_WALLET_ARCHIVE_ERR_BROKER_URL: broker URL is empty; set a public HTTPS broker URL" >&2
    exit 1
    ;;
  *)
    echo "IOS_FOOD_WALLET_ARCHIVE_ERR_BROKER_URL: TestFlight broker URL must be https, got $BROKER_URL" >&2
    exit 1
    ;;
esac

if [[ ! -x "$XCODEBUILD" ]]; then
  echo "IOS_FOOD_WALLET_ARCHIVE_ERR_XCODEBUILD: xcodebuild not found at $XCODEBUILD" >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "IOS_FOOD_WALLET_ARCHIVE_ERR_XCODEGEN: xcodegen is required" >&2
  exit 1
fi

cd "$ROOT_DIR"

python3 tools/ci/check_ios_food_wallet_app_store.py
if [[ "$SKIP_STAGING_BROKER_CHECK" != "1" ]]; then
  scripts/sdk/check_food_analysis_broker_staging.sh --require-cloudflare
fi
if [[ "$SKIP_LOCAL_VALIDATION" != "1" ]]; then
  scripts/sdk/check_ios_food_wallet_app.sh
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$DERIVED_DATA"

echo "Generating Xcode project at $PROJECT_PATH"
(cd "$APP_DIR" && xcodegen generate)

automatic_signing_args=()
manual_signing_args=()
if [[ -n "$PROVISIONING_PROFILE_SPECIFIER" || -n "$PROVISIONING_PROFILE_UUID" ]]; then
  manual_signing_args=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"
  )
  if [[ -n "$PROVISIONING_PROFILE_SPECIFIER" ]]; then
    manual_signing_args+=(PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_SPECIFIER")
  else
    manual_signing_args+=(PROVISIONING_PROFILE="$PROVISIONING_PROFILE_UUID")
  fi
else
  automatic_signing_args=(-allowProvisioningUpdates)
fi

archive_args=(
  -project "$PROJECT_PATH"
  -scheme FoodWallet
  -configuration Release
  -destination "generic/platform=iOS"
  -archivePath "$ARCHIVE_PATH"
  -derivedDataPath "$DERIVED_DATA"
  "${automatic_signing_args[@]}"
  DEVELOPMENT_TEAM="$TEAM_ID"
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
  GRAIN_FOOD_ANALYSIS_BROKER_URL="$BROKER_URL"
  GRAIN_FOOD_BROKER_DEV_TOKEN=""
  "${manual_signing_args[@]}"
  archive
)

if [[ -n "$BUILD_NUMBER" ]]; then
  archive_args=(CURRENT_PROJECT_VERSION="$BUILD_NUMBER" "${archive_args[@]}")
fi

echo "Archiving MealMark for TestFlight"
"$XCODEBUILD" "${archive_args[@]}"

python3 tools/ci/check_ios_food_wallet_testflight_archive.py "$ARCHIVE_PATH" \
  --expected-bundle-id "$BUNDLE_ID"

echo "IOS_FOOD_WALLET_TESTFLIGHT_ARCHIVE: PASS archive=$ARCHIVE_PATH"
