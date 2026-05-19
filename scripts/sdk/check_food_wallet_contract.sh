#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

REPORT=""
EXPECTED_COMMIT=""
REQUIRE_CLEAN=0

usage() {
  cat <<'EOF'
Usage: scripts/sdk/check_food_wallet_contract.sh [options]

Checks the Food Wallet developer contract:
Food Profile fixture integrity, SDK safety policy, docs boundary language, and
optional local pilot report safety.

Options:
  --report <path>            Validate a local-food-pilot.json report
  --expected-commit <sha>    Require the report commit to match this SHA
  --require-clean            Require the report to come from a clean worktree
  -h, --help                 Show this help

The check is source-level validation. It does not require accounts, backends,
external credentials, camera devices, app-store packaging, or a specific AI
provider.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      REPORT="${2:-}"
      if [[ -z "$REPORT" ]]; then
        echo "SDK_FOOD_WALLET_ERR_ARG_MISSING: --report requires a path" >&2
        exit 2
      fi
      shift 2
      ;;
    --expected-commit)
      EXPECTED_COMMIT="${2:-}"
      if [[ -z "$EXPECTED_COMMIT" ]]; then
        echo "SDK_FOOD_WALLET_ERR_ARG_MISSING: --expected-commit requires a SHA" >&2
        exit 2
      fi
      shift 2
      ;;
    --require-clean)
      REQUIRE_CLEAN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "SDK_FOOD_WALLET_ERR_UNKNOWN_ARG: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

run_check() {
  local name="$1"
  shift
  printf '== %s ==\n' "$name"
  "$@"
}

run_check "Food Profile fixture contract" python3 tools/ci/check_food_profile.py
run_check "Food Wallet typed contract" python3 tools/ci/check_food_wallet_contract.py
run_check "SDK secret logging policy" python3 tools/ci/check_sdk_secret_logging.py
run_check "SDK trust-provider boundary" python3 tools/ci/check_sdk_trust_provider_boundary.py
run_check "device adapter contract" python3 tools/ci/check_device_adapter_contract.py

run_check "Food Wallet docs and safe-output policy" python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])

def fail(message: str) -> None:
    raise SystemExit(message)

def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)

food_doc = root / "docs/human/sdk/food-wallet.md"
start_doc = root / "docs/human/sdk/start-here.md"
overview_doc = root / "docs/human/sdk/overview.md"
examples_doc = root / "examples/README.md"
fixture_path = root / "examples/reference-fixtures/food-local-pilot.valid.v1.json"

for path in (food_doc, start_doc, overview_doc, examples_doc, fixture_path):
    require(path.exists(), f"SDK_FOOD_WALLET_ERR_MISSING_PATH: {path.relative_to(root)}")

food_text = food_doc.read_text(encoding="utf-8")
required_phrases = [
    "App owns camera, photo provider, and UI",
    "Grain owns contract, validation, confirm, and export primitives",
    "OpenAI is not required",
    "AI providers are replaceable adapters",
    "No account, backend, or App Store claim",
    "Raw photos stay app-private",
]
for phrase in required_phrases:
    require(phrase in food_text, f"SDK_FOOD_WALLET_ERR_DOC_BOUNDARY: {phrase}")

for path in (start_doc, overview_doc):
    text = path.read_text(encoding="utf-8")
    require("food-wallet.md" in text, f"SDK_FOOD_WALLET_ERR_ROUTE_MAP: {path.relative_to(root)}")

examples_text = examples_doc.read_text(encoding="utf-8")
require(
    "docs/human/sdk/food-wallet.md" in examples_text,
    "SDK_FOOD_WALLET_ERR_EXAMPLES_ROUTE_MAP",
)

fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
pilot = fixture.get("pilot")
require(isinstance(pilot, dict), "SDK_FOOD_WALLET_ERR_FIXTURE_PILOT")
require(pilot.get("scope") == "local-source-validation-only", "SDK_FOOD_WALLET_ERR_FIXTURE_SCOPE")
for flag in (
    "requires_external_apps",
    "requires_external_devices",
    "requires_external_credentials",
):
    require(pilot.get(flag) is False, f"SDK_FOOD_WALLET_ERR_FIXTURE_BOUNDARY: {flag}")
require("scanner_offer" in pilot, "SDK_FOOD_WALLET_ERR_FIXTURE_SCANNER_OFFER")
require("expected_reducer" in pilot, "SDK_FOOD_WALLET_ERR_FIXTURE_REDUCER")

safe_paths = [
    food_doc,
    start_doc,
    overview_doc,
]
raw_photo_re = re.compile(
    r"\b(raw[_ -]?photo|photo[_ -]?(bytes|b64|base64|blob|store|storage)|"
    r"image[_ -]?(bytes|b64|base64|blob|store|storage)|camera[_ -]?frame)\b",
    re.IGNORECASE,
)
allowed_text = {
    "Raw photos stay app-private",
    "raw photo storage is not a Grain SDK output",
    "Grain safe reports must not include raw",
    "without turning the SDK into a camera, photo store",
}
for path in safe_paths:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    for match in raw_photo_re.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        context = " ".join(lines[max(0, line - 2): min(len(lines), line + 1)])
        if any(allowed in context for allowed in allowed_text):
            continue
        fail(f"SDK_FOOD_WALLET_ERR_RAW_PHOTO_SAFE_OUTPUT: {path.relative_to(root)}:{line}")

print("Food Wallet contract policy: PASS")
PY

if [[ -n "$REPORT" ]]; then
  report_args=(--report "$REPORT")
  if [[ -n "$EXPECTED_COMMIT" ]]; then
    report_args+=(--expected-commit "$EXPECTED_COMMIT")
  fi
  if [[ "$REQUIRE_CLEAN" -eq 1 ]]; then
    report_args+=(--require-clean)
  fi
  run_check "local Food pilot safe report" python3 tools/ci/check_local_food_pilot_report.py "${report_args[@]}"
  run_check "Food Wallet report photo safety" python3 - "$REPORT" <<'PY'
import json
import re
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
report = json.loads(report_path.read_text(encoding="utf-8"))
forbidden = {
    "raw_photo",
    "rawPhoto",
    "photo_b64",
    "photoB64",
    "photo_bytes",
    "photoBytes",
    "image_b64",
    "imageB64",
    "image_bytes",
    "imageBytes",
    "camera_frame",
    "cameraFrame",
    "food_photo",
    "foodPhoto",
}
forbidden_value = re.compile(r"^(data:image/|/9j/|iVBOR|GR1:)", re.IGNORECASE)

def walk(value, path="$"):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in forbidden:
                raise SystemExit(f"SDK_FOOD_WALLET_REPORT_ERR_RAW_PHOTO_FIELD: {path}.{key}")
            walk(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk(child, f"{path}[{index}]")
    elif isinstance(value, str) and forbidden_value.search(value):
        if path not in {"$.artifacts.qr_string"}:
            raise SystemExit(f"SDK_FOOD_WALLET_REPORT_ERR_INLINE_RAW_OUTPUT: {path}")

walk(report)
print("Food Wallet report photo safety: PASS")
PY
fi

printf 'Food Wallet contract check: PASS\n'
