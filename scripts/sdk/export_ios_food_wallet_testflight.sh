#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCODEBUILD="${XCODEBUILD:-$DEVELOPER_DIR/usr/bin/xcodebuild}"
ARCHIVE_PATH="${GRAIN_IOS_ARCHIVE_PATH:-$ROOT_DIR/artifacts/ios-food-wallet/MealMark.xcarchive}"
EXPORT_PATH="${GRAIN_IOS_EXPORT_PATH:-$ROOT_DIR/artifacts/ios-food-wallet/testflight-export}"
TEAM_ID="${GRAIN_IOS_DISTRIBUTION_TEAM:-}"
DESTINATION="${GRAIN_IOS_EXPORT_DESTINATION:-export}"
export DEVELOPER_DIR

usage() {
  cat <<'EOF'
Usage: scripts/sdk/export_ios_food_wallet_testflight.sh

Export or upload a checked MealMark archive with App Store Connect export
options. The default destination is a local .ipa export; set
GRAIN_IOS_EXPORT_DESTINATION=upload for App Store Connect upload.

Required:
  GRAIN_IOS_DISTRIBUTION_TEAM

Optional:
  GRAIN_IOS_ARCHIVE_PATH
  GRAIN_IOS_EXPORT_PATH
  GRAIN_IOS_EXPORT_DESTINATION=export|upload
  APP_STORE_CONNECT_KEY_PATH
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$TEAM_ID" ]]; then
  echo "IOS_FOOD_WALLET_EXPORT_ERR_TEAM: set GRAIN_IOS_DISTRIBUTION_TEAM" >&2
  exit 1
fi

case "$DESTINATION" in
  export|upload)
    ;;
  *)
    echo "IOS_FOOD_WALLET_EXPORT_ERR_DESTINATION: use export or upload" >&2
    exit 1
    ;;
esac

if [[ ! -x "$XCODEBUILD" ]]; then
  echo "IOS_FOOD_WALLET_EXPORT_ERR_XCODEBUILD: xcodebuild not found at $XCODEBUILD" >&2
  exit 1
fi

cd "$ROOT_DIR"
python3 tools/ci/check_ios_food_wallet_testflight_archive.py "$ARCHIVE_PATH"

mkdir -p "$EXPORT_PATH"
OPTIONS_PLIST="$(mktemp "${TMPDIR:-/tmp}/mealmark-export-options.XXXXXX.plist")"
trap 'rm -f "$OPTIONS_PLIST"' EXIT

cat > "$OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>$DESTINATION</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

auth_args=()
if [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" || -n "${APP_STORE_CONNECT_KEY_ID:-}" || -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  if [[ -z "${APP_STORE_CONNECT_KEY_PATH:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
    echo "IOS_FOOD_WALLET_EXPORT_ERR_ASC_KEY: set key path, key id, and issuer id together" >&2
    exit 1
  fi
  auth_args=(
    -authenticationKeyPath "$APP_STORE_CONNECT_KEY_PATH"
    -authenticationKeyID "$APP_STORE_CONNECT_KEY_ID"
    -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
  )
fi

"$XCODEBUILD" -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$OPTIONS_PLIST" \
  -allowProvisioningUpdates \
  "${auth_args[@]}"

echo "IOS_FOOD_WALLET_TESTFLIGHT_EXPORT: PASS destination=$DESTINATION path=$EXPORT_PATH"
