#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

usage() {
  cat <<'EOF'
Usage: scripts/sdk/check_swift_food_wallet.sh [options]

Runs the Swift Food Wallet smoke:
Food Wallet contract policy, Swift SDK package smoke, and Swift source scans
that keep raw photos out of SDK-owned outputs.

Options:
  --policy-only    Skip the Swift package smoke; useful after it already ran
  -h, --help       Show this help
EOF
}

POLICY_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --policy-only)
      POLICY_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "SDK_SWIFT_FOOD_WALLET_ERR_UNKNOWN_ARG: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

scripts/sdk/check_food_wallet_contract.sh
if [[ "$POLICY_ONLY" -eq 0 ]]; then
  scripts/sdk/check_swift_package.sh
fi

python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
client = root / "sdk/swift/Sources/GrainClient/GrainClient.swift"
text = client.read_text(encoding="utf-8")
for token in (
    "GrainScanHandoffSource",
    "case camera",
    "GrainScanHandoff",
    "qrString",
    "trustAnchorID",
    "scanPreview",
    "scanAccept",
    "exportStoreSnapshot",
):
    if token not in text:
        raise SystemExit(f"SDK_SWIFT_FOOD_WALLET_ERR_MISSING_SURFACE: {token}")

raw_photo_re = re.compile(
    r"\b(UIImage|CGImage|CIImage|AVCapturePhoto|PHAsset|jpegData|pngData|"
    r"rawPhoto|foodPhoto|photoBytes|imageBytes|cameraFrame)\b"
)
for path in (root / "sdk/swift/Sources").rglob("*.swift"):
    source = path.read_text(encoding="utf-8")
    match = raw_photo_re.search(source)
    if match:
        line = source.count("\n", 0, match.start()) + 1
        raise SystemExit(f"SDK_SWIFT_FOOD_WALLET_ERR_RAW_PHOTO_STORAGE: {path.relative_to(root)}:{line}")

print("Swift Food Wallet policy: PASS")
PY

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_SWIFT_FOOD_WALLET_ERR_DIRTY_WORKTREE: Swift Food Wallet check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

printf 'Swift Food Wallet check: PASS\n'
