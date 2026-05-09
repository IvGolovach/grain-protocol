#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
OUT_DIR="artifacts/sdk-local-scanner-flow/$COMMIT_SHA"
STRICT=0
PAYLOAD_B64=""

usage() {
  cat <<'EOF'
Usage: scripts/sdk/run_local_scanner_flow.sh [options]

Runs the local scanner developer flow:
SDK doctor, issuer QR generation, local trust bundle creation, and scanner
example smokes. The command writes artifacts under artifacts/sdk-local-scanner-flow/<commit>/.

Options:
  --out-dir <path>      Output directory inside the repository
  --payload-b64 <b64>   Optional strict DAG-CBOR payload for grain-issuer-kit
  --strict              Fail when platform scanner prerequisites are missing
  -h, --help            Show this help

This is local source validation. It does not publish to registries, app stores,
TestFlight, Play Console, or hardware fleets, and it does not require external
credentials or paid developer accounts.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      if [[ -z "$OUT_DIR" ]]; then
        echo "SDK_LOCAL_FLOW_ERR_ARG_MISSING: --out-dir requires a path" >&2
        exit 2
      fi
      shift 2
      ;;
    --payload-b64)
      PAYLOAD_B64="${2:-}"
      if [[ -z "$PAYLOAD_B64" ]]; then
        echo "SDK_LOCAL_FLOW_ERR_ARG_MISSING: --payload-b64 requires a value" >&2
        exit 2
      fi
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "SDK_LOCAL_FLOW_ERR_UNKNOWN_ARG: $1" >&2
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
      echo "SDK_LOCAL_FLOW_ERR_OUT_DIR_OUTSIDE_REPO: out-dir must be inside repository root" >&2
      exit 1
      ;;
  esac
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

append_check() {
  local name="$1"
  local status="$2"
  local command_text="$3"
  local output="$4"
  local reason="${5:-}"
  local platforms="${6:-}"
  python3 - "$CHECKS_JSONL" "$name" "$status" "$command_text" "$output" "$reason" "$platforms" <<'PY'
import json
import sys
from pathlib import Path

path, name, status, command, output, reason, platforms = sys.argv[1:]
record = {
    "name": name,
    "status": status,
    "command": command,
    "output": output,
}
if reason:
    record["reason"] = reason
if platforms:
    record["platforms"] = platforms.split(",")
with Path(path).open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, sort_keys=True) + "\n")
PY
}

run_check() {
  local name="$1"
  shift
  local log_file="logs/${name}.txt"
  if "$@" >"$OUT_DIR_ABS/$log_file" 2>&1; then
    append_check "$name" "pass" "$*" "$log_file"
  else
    append_check "$name" "fail" "$*" "$log_file"
    status=1
  fi
}

write_final_report() {
  local mode="auto"
  if [[ "$STRICT" -eq 1 ]]; then
    mode="strict"
  fi

  local dirty_flag="false"
  if [[ -n "$BEFORE_STATUS" ]]; then
    dirty_flag="true"
  fi

  python3 - "$REPORT" "$COMMIT_SHA" "$dirty_flag" "$mode" "$CHECKS_JSONL" <<'PY'
import json
import sys
from pathlib import Path

report_path, commit, dirty, mode, checks_path = sys.argv[1:]
checks = {}
for line in Path(checks_path).read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    item = json.loads(line)
    name = item.pop("name")
    checks[name] = item

residual_gaps = []
scanner = checks.get("scanner_examples", {})
if scanner.get("status") == "unsupported_prereq":
    residual_gaps.append(scanner.get("reason", "scanner platform prerequisites were unavailable"))

report = {
    "schema": "grain.sdk.local_scanner_flow.v1",
    "commit": commit,
    "dirty": dirty == "true",
    "mode": mode,
    "publication_boundary": "local-source-validation-only",
    "external_credentials": "not_required",
    "paid_developer_accounts": "not_required",
    "registry_publication": "not_included",
    "app_store_publication": "not_included",
    "play_console_publication": "not_included",
    "flow": [
        "sdk_doctor",
        "issuer_qr",
        "local_trust_bundle",
        "scanner_examples",
    ],
    "artifacts": {
        "issuer_output": "issuer-output.json",
        "qr_string": "qr-string.txt",
        "trust_bundle": "local-trust-bundle.json",
        "logs": "logs",
    },
    "checks": checks,
    "safe_report": {
        "raw_qr_string": "not_included",
        "raw_trust_material": "not_included",
        "raw_snapshot_material": "not_included",
        "raw_sync_material": "not_included",
    },
    "residual_gaps": residual_gaps,
}
Path(report_path).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

  local check_args=(
    --report "$REPORT"
    --expected-commit "$COMMIT_SHA"
  )
  if [[ "$STRICT" -eq 1 ]]; then
    check_args+=(--require-strict)
  fi
  if ! python3 tools/ci/check_local_scanner_flow_report.py "${check_args[@]}" >"$OUT_DIR_ABS/logs/report_validation.txt" 2>&1; then
    status=1
  fi
}

OUT_DIR_ABS="$(resolve_out_dir "$OUT_DIR")"
mkdir -p "$OUT_DIR_ABS/logs"
CHECKS_JSONL="$OUT_DIR_ABS/logs/checks.jsonl"
REPORT="$OUT_DIR_ABS/local-scanner-flow.json"
: > "$CHECKS_JSONL"

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
status=0

run_check "sdk_doctor" scripts/sdk/doctor

ISSUER_CMD=(
  cargo run
  --manifest-path core/rust/Cargo.toml
  -p grain-issuer-kit
  --
  --pretty
)
ISSUER_CMD_DISPLAY="cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty"
if [[ -n "$PAYLOAD_B64" ]]; then
  ISSUER_CMD+=(--payload-b64 "$PAYLOAD_B64")
  ISSUER_CMD_DISPLAY="cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --payload-b64 <redacted> --pretty"
fi

if "${ISSUER_CMD[@]}" >"$OUT_DIR_ABS/issuer-output.json" 2>"$OUT_DIR_ABS/logs/issuer_qr.txt"; then
  append_check "issuer_qr" "pass" "$ISSUER_CMD_DISPLAY" "logs/issuer_qr.txt"
else
  append_check "issuer_qr" "fail" "$ISSUER_CMD_DISPLAY" "logs/issuer_qr.txt"
  status=1
fi

if [[ "$status" -eq 0 ]]; then
  if python3 - "$OUT_DIR_ABS/issuer-output.json" "$OUT_DIR_ABS/qr-string.txt" "$OUT_DIR_ABS/local-trust-bundle.json" >"$OUT_DIR_ABS/logs/local_trust_bundle.txt" 2>&1 <<'PY'
import base64
import json
import sys
from pathlib import Path

issuer_output, qr_path, trust_path = map(Path, sys.argv[1:])
issued = json.loads(issuer_output.read_text(encoding="utf-8"))
qr_string = issued.get("qr_string")
trust_pub_b64 = issued.get("trust_pub_b64")
if not isinstance(qr_string, str) or not qr_string.startswith("GR1:"):
    raise SystemExit("SDK_LOCAL_FLOW_ERR_QR_STRING")
if not isinstance(trust_pub_b64, str) or not trust_pub_b64.strip():
    raise SystemExit("SDK_LOCAL_FLOW_ERR_TRUST_PUB")
try:
    decoded = base64.b64decode(trust_pub_b64, validate=True)
except ValueError as exc:
    raise SystemExit("SDK_LOCAL_FLOW_ERR_TRUST_PUB") from exc
if not decoded:
    raise SystemExit("SDK_LOCAL_FLOW_ERR_TRUST_PUB")

qr_path.write_text(qr_string + "\n", encoding="utf-8")
trust_path.write_text(
    json.dumps(
        {
            "bundle_v": 1,
            "anchors": [
                {
                    "id": "publisher:primary",
                    "trust_pub_b64": trust_pub_b64,
                }
            ],
        },
        indent=2,
        sort_keys=True,
    )
    + "\n",
    encoding="utf-8",
)
print("local trust bundle: PASS")
PY
  then
    append_check "local_trust_bundle" "pass" "python3 <inline local trust bundle writer>" "logs/local_trust_bundle.txt"
  else
    append_check "local_trust_bundle" "fail" "python3 <inline local trust bundle writer>" "logs/local_trust_bundle.txt"
    status=1
  fi
else
  append_check "local_trust_bundle" "fail" "python3 <inline local trust bundle writer>" "logs/local_trust_bundle.txt" "issuer QR generation failed"
fi

SCANNER_PLATFORMS="ios-scanner,ios-reference-app,android-scanner,android-reference-app,wasm-scanner"
if have_cmd swift && have_cmd java && have_cmd npm && have_cmd cargo && have_cmd rustc; then
  run_check "scanner_examples" scripts/sdk/check_scanner_examples.sh
  python3 - "$CHECKS_JSONL" "$SCANNER_PLATFORMS" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
platforms = sys.argv[2].split(",")
items = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
for item in items:
    if item.get("name") == "scanner_examples":
        item["platforms"] = platforms
path.write_text("\n".join(json.dumps(item, sort_keys=True) for item in items) + "\n", encoding="utf-8")
PY
else
  reason="scanner example checks require swift, java, npm, cargo, and rustc"
  append_check "scanner_examples" "unsupported_prereq" "scripts/sdk/check_scanner_examples.sh" "logs/scanner_examples.txt" "$reason" "$SCANNER_PLATFORMS"
  printf '%s\n' "$reason" >"$OUT_DIR_ABS/logs/scanner_examples.txt"
  if [[ "$STRICT" -eq 1 ]]; then
    status=1
  fi
fi

write_final_report

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_LOCAL_FLOW_ERR_DIRTY_WORKTREE_CHANGED: local scanner flow changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

if [[ "$status" -eq 0 ]]; then
  printf 'local scanner flow: PASS\n'
else
  printf 'local scanner flow: FAIL\n' >&2
fi
printf 'artifacts: %s\n' "$OUT_DIR_ABS"
printf 'report: %s\n' "$REPORT"
exit "$status"
