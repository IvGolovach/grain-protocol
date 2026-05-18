#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
OUT_DIR="artifacts/sdk-local-food-pilot/$COMMIT_SHA"
FIXTURE_REL="examples/reference-fixtures/food-local-pilot.valid.v1.json"

usage() {
  cat <<'EOF'
Usage: scripts/sdk/run_local_food_pilot.sh [options]

Runs the local Food Profile pilot proof:
Food profile static validation, TypeScript SDK append/reduce over the local
pilot fixture, reference issuer QR generation, local trust bundle creation, and
report validation. The command writes artifacts under
artifacts/sdk-local-food-pilot/<commit>/.

Options:
  --out-dir <path>      Output directory inside the repository
  -h, --help            Show this help

This is local source validation. It does not require phones, cameras, external
apps, external credentials, paid developer accounts, registries, app stores, or
Play Console.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      if [[ -z "$OUT_DIR" ]]; then
        echo "SDK_LOCAL_FOOD_PILOT_ERR_ARG_MISSING: --out-dir requires a path" >&2
        exit 2
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "SDK_LOCAL_FOOD_PILOT_ERR_UNKNOWN_ARG: $1" >&2
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
      echo "SDK_LOCAL_FOOD_PILOT_ERR_OUT_DIR_OUTSIDE_REPO: out-dir must be inside repository root" >&2
      exit 1
      ;;
  esac
}

append_check() {
  local name="$1"
  local status="$2"
  local command_text="$3"
  local output="$4"
  python3 - "$CHECKS_JSONL" "$name" "$status" "$command_text" "$output" <<'PY'
import json
import sys
from pathlib import Path

path, name, status, command, output = sys.argv[1:]
record = {
    "name": name,
    "status": status,
    "command": command,
    "output": output,
}
with Path(path).open("a", encoding="utf-8") as handle:
    handle.write(json.dumps(record, sort_keys=True) + "\n")
PY
}

run_check() {
  local name="$1"
  shift
  local log_file="logs/${name}.txt"
  local cmd_display
  cmd_display="$(printf '%q ' "$@")"
  cmd_display="${cmd_display% }"
  if "$@" >"$OUT_DIR_ABS/$log_file" 2>&1; then
    append_check "$name" "pass" "$cmd_display" "$log_file"
  else
    append_check "$name" "fail" "$cmd_display" "$log_file"
    status=1
  fi
}

write_runner() {
  cat >"$RUNNER" <<'JS'
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [root, fixturePath, proofPath] = process.argv.slice(2);
const { GrainSdk } = await import(pathToFileURL(join(root, "core/ts/grain-sdk/dist/src/index.js")).href);
const fixture = JSON.parse(readFileSync(fixturePath, "utf8"));
const pilot = fixture.pilot;

if (fixture.fixture_id !== "food-local-pilot.valid.v1" || fixture.profile_id !== "food-v0.1") {
  throw new Error("local Food pilot fixture identity mismatch");
}
if (
  pilot.scope !== "local-source-validation-only" ||
  pilot.requires_external_apps !== false ||
  pilot.requires_external_devices !== false ||
  pilot.requires_external_credentials !== false
) {
  throw new Error("local Food pilot fixture boundary mismatch");
}

const sdk = new GrainSdk();
await sdk.identity.createRoot();
const appended = [];
for (const event of pilot.events) {
  const result = await sdk.events.append({
    t: event.t,
    payload_cid: event.payload_cid,
    body: { ...event.body }
  });
  appended.push(result.event_id);
}

const reduced = await sdk.events.reduce();
const expected = JSON.stringify(pilot.expected_reducer);
const actual = JSON.stringify(reduced.out);
if (!reduced.pass || reduced.diag.length !== 0 || actual !== expected) {
  throw new Error(`local Food pilot reduce mismatch: ${actual}`);
}

const proof = await sdk.evidence.generateProofBundle({
  suite_summary: {
    local_food_pilot: "pass",
    fixture_id: fixture.fixture_id,
    profile_id: fixture.profile_id
  }
});

writeFileSync(
  proofPath,
  JSON.stringify(
    {
      schema: "grain.sdk.local_food_pilot_proof.v1",
      fixture_id: fixture.fixture_id,
      profile_id: fixture.profile_id,
      event_count: appended.length,
      appended_event_ids: appended,
      reducer_pass: reduced.pass,
      reducer_diag: reduced.diag,
      reducer_out: reduced.out,
      proof_sha256: proof.sha256_hex
    },
    null,
    2
  ) + "\n"
);

console.log("local Food pilot SDK proof: PASS");
JS
}

write_report() {
  local dirty_flag="false"
  if [[ -n "$BEFORE_STATUS" ]]; then
    dirty_flag="true"
  fi

  if [[ ! -f "$SDK_PROOF" ]]; then
    status=1
    {
      echo "SDK_LOCAL_FOOD_PILOT_ERR_SDK_PROOF_MISSING: $SDK_PROOF"
      echo "The sdk_reduce step did not produce the expected proof artifact."
      if [[ -f "$OUT_DIR_ABS/logs/sdk_reduce.txt" ]]; then
        echo
        echo "== logs/sdk_reduce.txt =="
        cat "$OUT_DIR_ABS/logs/sdk_reduce.txt"
      fi
    } >"$OUT_DIR_ABS/logs/report_validation.txt"
    cat "$OUT_DIR_ABS/logs/report_validation.txt" >&2 || true
    return
  fi

  python3 - "$REPORT" "$COMMIT_SHA" "$dirty_flag" "$CHECKS_JSONL" "$SDK_PROOF" <<'PY'
import json
import sys
from pathlib import Path

report_path, commit, dirty, checks_path, proof_path = sys.argv[1:]
checks = {}
for line in Path(checks_path).read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    item = json.loads(line)
    name = item.pop("name")
    checks[name] = item

proof = json.loads(Path(proof_path).read_text(encoding="utf-8"))
report = {
    "schema": "grain.sdk.local_food_pilot.v1",
    "commit": commit,
    "dirty": dirty == "true",
    "publication_boundary": "local-source-validation-only",
    "external_apps": "not_required",
    "external_devices": "not_required",
    "external_credentials": "not_required",
    "registry_publication": "not_included",
    "app_store_publication": "not_included",
    "play_console_publication": "not_included",
    "flow": [
        "food_profile",
        "sdk_build",
        "sdk_reduce",
        "reference_issuer",
        "reference_issuer_verify",
        "local_trust_bundle",
    ],
    "artifacts": {
        "pilot_fixture": "food-local-pilot.valid.v1.json",
        "sdk_proof": "local-food-pilot-sdk-proof.json",
        "issuer_output": "issuer-output.json",
        "qr_string": "qr-string.txt",
        "trust_bundle": "local-trust-bundle.json",
        "logs": "logs",
    },
    "checks": checks,
    "reducer": {
        "expected": {
            "sum_mean": {"kcal": 620},
            "sum_var": {"kcal": 9},
        },
        "actual": proof["reducer_out"],
    },
    "safe_report": {
        "raw_qr_string": "not_included",
        "raw_trust_material": "not_included",
        "raw_snapshot_material": "not_included",
        "raw_sync_material": "not_included",
    },
    "residual_gaps": [],
}
Path(report_path).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

  local check_args=(
    --report "$REPORT"
    --expected-commit "$COMMIT_SHA"
  )
  if [[ -z "$BEFORE_STATUS" ]]; then
    check_args+=(--require-clean)
  fi
  if ! python3 tools/ci/check_local_food_pilot_report.py "${check_args[@]}" >"$OUT_DIR_ABS/logs/report_validation.txt" 2>&1; then
    status=1
  fi
}

OUT_DIR_ABS="$(resolve_out_dir "$OUT_DIR")"
mkdir -p "$OUT_DIR_ABS/logs"
CHECKS_JSONL="$OUT_DIR_ABS/logs/checks.jsonl"
REPORT="$OUT_DIR_ABS/local-food-pilot.json"
RUNNER="$OUT_DIR_ABS/logs/run-food-pilot.mjs"
SDK_PROOF="$OUT_DIR_ABS/local-food-pilot-sdk-proof.json"
: > "$CHECKS_JSONL"

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=normal)"
status=0

cp "$FIXTURE_REL" "$OUT_DIR_ABS/food-local-pilot.valid.v1.json"
write_runner

run_check "food_profile" python3 tools/ci/check_food_profile.py
run_check "sdk_build" npm --prefix core/ts/grain-sdk run build
if node "$RUNNER" "$ROOT" "$ROOT/$FIXTURE_REL" "$SDK_PROOF" >"$OUT_DIR_ABS/logs/sdk_reduce.txt" 2>&1; then
  append_check "sdk_reduce" "pass" "node <generated local food pilot runner>" "logs/sdk_reduce.txt"
else
  append_check "sdk_reduce" "fail" "node <generated local food pilot runner>" "logs/sdk_reduce.txt"
  cat "$OUT_DIR_ABS/logs/sdk_reduce.txt" >&2 || true
  status=1
fi

ISSUER_CMD=(
  cargo run
  --manifest-path core/rust/Cargo.toml
  -p grain-issuer-kit
  --
  --pretty
)
ISSUER_CMD_DISPLAY="cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty"
if "${ISSUER_CMD[@]}" >"$OUT_DIR_ABS/issuer-output.json" 2>"$OUT_DIR_ABS/logs/reference_issuer.txt"; then
  append_check "reference_issuer" "pass" "$ISSUER_CMD_DISPLAY" "logs/reference_issuer.txt"
else
  append_check "reference_issuer" "fail" "$ISSUER_CMD_DISPLAY" "logs/reference_issuer.txt"
  status=1
fi

run_check \
  "reference_issuer_verify" \
  cargo test \
  --manifest-path core/rust/Cargo.toml \
  -p grain-issuer-kit \
  generated_reference_qr_verifies_through_client_core

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
    raise SystemExit("SDK_LOCAL_FOOD_PILOT_ERR_QR_STRING")
if not isinstance(trust_pub_b64, str) or not trust_pub_b64.strip():
    raise SystemExit("SDK_LOCAL_FOOD_PILOT_ERR_TRUST_PUB")
try:
    decoded = base64.b64decode(trust_pub_b64, validate=True)
except ValueError as exc:
    raise SystemExit("SDK_LOCAL_FOOD_PILOT_ERR_TRUST_PUB") from exc
if not decoded:
    raise SystemExit("SDK_LOCAL_FOOD_PILOT_ERR_TRUST_PUB")

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
print("local Food pilot trust bundle: PASS")
PY
  then
    append_check "local_trust_bundle" "pass" "python3 <inline local trust bundle writer>" "logs/local_trust_bundle.txt"
  else
    append_check "local_trust_bundle" "fail" "python3 <inline local trust bundle writer>" "logs/local_trust_bundle.txt"
    status=1
  fi
else
  append_check "local_trust_bundle" "fail" "python3 <inline local trust bundle writer>" "logs/local_trust_bundle.txt"
fi

write_report

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=normal)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_LOCAL_FOOD_PILOT_ERR_DIRTY_WORKTREE_CHANGED: local Food pilot changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

if [[ "$status" -eq 0 ]]; then
  printf 'local Food pilot: PASS\n'
else
  printf 'local Food pilot: FAIL\n' >&2
fi
printf 'artifacts: %s\n' "$OUT_DIR_ABS"
printf 'report: %s\n' "$REPORT"
exit "$status"
