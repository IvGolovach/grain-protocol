#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

CLIENT_NAME="${CLIENT_NAME:-external-client}"
CLIENT_OWNER="${CLIENT_OWNER:-external-team}"
COMMIT="${GRAIN_COMMIT:-$(git rev-parse HEAD)}"
OUT_DIR="${OUT_DIR:-artifacts/external-client-certification}"
REPORT="$OUT_DIR/${CLIENT_NAME}.json"
LOG_DIR="$OUT_DIR/logs"

mkdir -p "$LOG_DIR"

json_quote() {
  python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

run_check() {
  local name="$1"
  shift
  local log_file="logs/${name}.txt"
  if "$@" >"$OUT_DIR/$log_file" 2>&1; then
    printf '"%s": {"status": "pass", "command": %s, "output": %s}' \
      "$name" \
      "$(json_quote "$*")" \
      "$(json_quote "$log_file")"
  else
    printf '"%s": {"status": "fail", "command": %s, "output": %s}' \
      "$name" \
      "$(json_quote "$*")" \
      "$(json_quote "$log_file")"
    return 1
  fi
}

tmp_checks="$(mktemp)"
status=0
{
  run_check workflow_fixtures python3 tools/ci/check_client_workflow_fixtures.py || status=1
  printf ',\n'
  run_check no_network python3 tools/ci/check_sdk_no_network.py || status=1
  printf ',\n'
  run_check trust_provider python3 tools/ci/check_sdk_trust_provider_boundary.py || status=1
  printf ',\n'
  run_check secret_logging python3 tools/ci/check_sdk_secret_logging.py || status=1
  printf ',\n'
  run_check api_compatibility python3 tools/ci/check_public_sdk_api.py || status=1
  printf ',\n'
  run_check template_smoke scripts/sdk/check_starter_templates.sh || status=1
  printf ',\n'
  run_check no_secret_telemetry python3 tools/ci/check_no_secret_telemetry.py || status=1
  printf ',\n'
  run_check trust_governance python3 tools/ci/check_trust_bundle_governance.py || status=1
} > "$tmp_checks"

python3 - "$REPORT" "$CLIENT_NAME" "$CLIENT_OWNER" "$COMMIT" "$tmp_checks" <<'PY'
import json
import sys
from pathlib import Path

report_path, client_name, owner, commit, checks_path = sys.argv[1:]
checks = json.loads("{" + Path(checks_path).read_text(encoding="utf-8") + "}")
report = {
    "schema": "grain.external_client.certification.v1",
    "client": {
        "name": client_name,
        "owner": owner,
        "grain_commit": commit,
    },
    "checks": checks,
    "artifacts": {
        "source_handoff": f"artifacts/sdk-release/{commit}",
        "report_path": report_path,
    },
    "residual_gaps": [],
}
Path(report_path).write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
rm -f "$tmp_checks"

python3 tools/ci/check_external_client_certification.py --report "$REPORT"
exit "$status"
