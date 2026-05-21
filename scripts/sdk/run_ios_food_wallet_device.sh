#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/apps/ios-food-wallet"
PROJECT_PATH="$APP_DIR/FoodWallet.xcodeproj"
DERIVED_DATA="${GRAIN_IOS_DERIVED_DATA:-$ROOT_DIR/artifacts/ios-food-wallet-device}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCRUN="${XCRUN:-/usr/bin/xcrun}"
BUNDLE_ID="${GRAIN_IOS_BUNDLE_ID:-dev.grain.foodwallet}"
BROKER_URL="${GRAIN_FOOD_ANALYSIS_BROKER_URL:-}"
BROKER_TOKEN="${GRAIN_FOOD_BROKER_DEV_TOKEN:-${FOOD_BROKER_DEV_TOKEN:-}}"
export DEVELOPER_DIR

if [ ! -d "$DEVELOPER_DIR" ]; then
  echo "Xcode developer dir not found: $DEVELOPER_DIR" >&2
  exit 1
fi

if [ ! -x "$XCRUN" ]; then
  echo "xcrun not found: $XCRUN" >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required to generate $PROJECT_PATH" >&2
  exit 1
fi

detect_team_id_from_profiles() {
  python3 - "$1" \
    "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
    "$HOME/Library/MobileDevice/Provisioning Profiles" <<'PY'
import plistlib
import subprocess
import sys
from pathlib import Path

bundle_id = sys.argv[1]

for profile_dir in sys.argv[2:]:
    root = Path(profile_dir)
    if not root.exists():
        continue

    for profile in root.glob("*.mobileprovision"):
        decoded = subprocess.run(
            ["/usr/bin/security", "cms", "-D", "-i", str(profile)],
            capture_output=True,
            check=False,
        )
        if decoded.returncode != 0:
            continue

        try:
            payload = plistlib.loads(decoded.stdout)
        except Exception:
            continue

        entitlements = payload.get("Entitlements", {})
        app_id = entitlements.get("application-identifier", "")
        _, _, app_id_suffix = app_id.partition(".")
        suffix_matches = (
            app_id_suffix == bundle_id
            or app_id_suffix == "*"
            or (app_id_suffix.endswith("*") and bundle_id.startswith(app_id_suffix[:-1]))
        )
        if not suffix_matches:
            continue

        teams = payload.get("TeamIdentifier") or payload.get("ApplicationIdentifierPrefix") or []
        if teams:
            print(teams[0])
            raise SystemExit(0)
PY
}

detect_team_id() {
  local profile_team_id
  profile_team_id="$(detect_team_id_from_profiles "$BUNDLE_ID")"
  if [ -n "$profile_team_id" ]; then
    echo "$profile_team_id"
    return
  fi

  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*Apple Development:.*(\([A-Z0-9][A-Z0-9]*\)).*/\1/p' \
    | head -n 1
}

detect_device_id() {
  local json_path
  json_path="$(mktemp)"
  "$XCRUN" devicectl list devices --json-output "$json_path" --quiet >/dev/null
  python3 - "$json_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)

for device in payload.get("result", {}).get("devices", []):
    hardware = device.get("hardwareProperties", {})
    properties = device.get("deviceProperties", {})
    connection = device.get("connectionProperties", {})
    if (
        hardware.get("platform") == "iOS"
        and hardware.get("deviceType") == "iPhone"
        and connection.get("tunnelState") == "connected"
        and properties.get("developerModeStatus") == "enabled"
    ):
        print(device["identifier"])
        break
PY
  rm -f "$json_path"
}

TEAM_ID="${GRAIN_IOS_DEVELOPMENT_TEAM:-$(detect_team_id)}"
if [ -z "${TEAM_ID:-}" ]; then
  echo "No Apple Development signing identity found. Set GRAIN_IOS_DEVELOPMENT_TEAM." >&2
  exit 1
fi

DEVICE_ID="${GRAIN_IOS_DEVICE_ID:-$(detect_device_id)}"
if [ -z "${DEVICE_ID:-}" ]; then
  echo "No connected developer-mode iPhone found. Set GRAIN_IOS_DEVICE_ID." >&2
  exit 1
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/FoodWallet.app"
SMOKE_LOG="$DERIVED_DATA/device-smoke.log"
LAUNCH_ENV="$(
  python3 - "$BROKER_URL" "$BROKER_TOKEN" <<'PY'
import json
import sys

env = {"LLVM_PROFILE_FILE": "/dev/null"}
broker_url = sys.argv[1]
if broker_url:
    env["GRAIN_FOOD_ANALYSIS_BROKER_URL"] = broker_url
broker_token = sys.argv[2] if len(sys.argv) > 2 else ""
if broker_token:
    env["GRAIN_FOOD_BROKER_DEV_TOKEN"] = broker_token
print(json.dumps(env, separators=(",", ":")))
PY
)"

echo "Using development team $TEAM_ID for bundle $BUNDLE_ID"
echo "Generating Xcode project at $PROJECT_PATH"
(cd "$APP_DIR" && xcodegen generate)

build_args=(
  -project "$PROJECT_PATH"
  -scheme FoodWallet
  -destination "id=$DEVICE_ID"
  -derivedDataPath "$DERIVED_DATA"
  -allowProvisioningUpdates
  DEVELOPMENT_TEAM="$TEAM_ID"
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
  GRAIN_FOOD_ANALYSIS_BROKER_URL="$BROKER_URL"
  GRAIN_FOOD_BROKER_DEV_TOKEN="$BROKER_TOKEN"
  build
)

if [ "${GRAIN_IOS_ALLOW_DEVICE_REGISTRATION:-0}" = "1" ]; then
  build_args=(-allowProvisioningDeviceRegistration "${build_args[@]}")
fi

echo "Building MealMark display app for device $DEVICE_ID"
"$DEVELOPER_DIR/usr/bin/xcodebuild" "${build_args[@]}"

if [ ! -d "$APP_PATH" ]; then
  echo "Expected app bundle not found: $APP_PATH" >&2
  exit 1
fi

echo "Installing $APP_PATH"
"$XCRUN" devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "Launching deterministic device smoke"
set +e
"$XCRUN" devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  --console \
  --environment-variables "$LAUNCH_ENV" \
  "$BUNDLE_ID" \
  --grain-device-smoke 2>&1 | tee "$SMOKE_LOG"
smoke_status=${PIPESTATUS[0]}
set -e

if [ "$smoke_status" -ne 0 ]; then
  echo "Device smoke launch failed; see $SMOKE_LOG" >&2
  exit "$smoke_status"
fi

if ! grep -q "GRAIN_IOS_FOOD_WALLET_DEVICE_SMOKE: PASS" "$SMOKE_LOG"; then
  echo "Device smoke did not print PASS; see $SMOKE_LOG" >&2
  exit 1
fi

echo "Launching MealMark normally"
"$XCRUN" devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  --environment-variables "$LAUNCH_ENV" \
  "$BUNDLE_ID"

echo "IOS_FOOD_WALLET_DEVICE_RUN: PASS device=$DEVICE_ID bundle=$BUNDLE_ID app=$APP_PATH"
