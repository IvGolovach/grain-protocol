#!/usr/bin/env bash
set -euo pipefail

ROOT="/work"
cd "$ROOT"

# GitHub Actions mounts the workspace with host ownership; mark mount as trusted for git helpers.
git config --global --add safe.directory "$ROOT"

OUT_DIR="${GRAIN_VERIFY_OUT_DIR:-$ROOT/artifacts/verify}"
COMMIT_SHA="${GRAIN_VERIFY_COMMIT_SHA:-$(git rev-parse HEAD)}"
ENABLE_FUZZ_SMOKE="${GRAIN_VERIFY_FUZZ_SMOKE:-0}"

mkdir -p "$OUT_DIR" "$OUT_DIR/evidence"

python3 tools/validate_vectors.py
python3 tools/check_llm_docs.py
python3 tools/check_spec_drift.py
python3 tools/ci/check_gitattributes_policy.py
python3 tools/ci/check_forbidden_tracked.py
python3 tools/ci/check_history_hygiene.py
python3 tools/ci/check_crlf_tracked.py
python3 tools/ci/check_codeowners_coverage.py
python3 tools/ci/check_dependabot_policy.py
python3 tools/ci/check_node_runtime_pin.py
python3 tools/ci/check_workflow_action_pinning.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 tools/ci/check_runner_contract_compat.py
python3 tools/ci/check_prohibition_coverage.py
python3 tools/ci/check_capid_csprng.py
python3 tools/ci/check_sdk_no_network.py

cargo build --manifest-path core/rust/Cargo.toml -p grain-runner

python3 tools/ci/run_runner_suite.py \
  --vectors-root conformance/vectors \
  --commit-sha "$COMMIT_SHA" \
  --out "$OUT_DIR/evidence/suite-run-rust.json" \
  --runner-cmd core/rust/target/debug/grain-runner run --strict --vector

npm ci --prefix core/ts/grain-ts-core
npm ci --prefix runner/typescript
if [[ -f core/ts/grain-sdk/package-lock.json ]]; then
  npm ci --prefix core/ts/grain-sdk
fi

npm --prefix runner/typescript run run:c01
npm --prefix runner/typescript run run:full
GRAIN_RUST_RUNNER_BIN=core/rust/target/debug/grain-runner npm --prefix runner/typescript run divergence:c01
GRAIN_RUST_RUNNER_BIN=core/rust/target/debug/grain-runner npm --prefix runner/typescript run divergence:full
npm --prefix runner/typescript run test:cborseq-contract
npm --prefix runner/typescript run test:properties
npm --prefix runner/typescript run test:integer-precision
npm --prefix core/ts/grain-sdk run run:protocol-suite
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk run test:ai-boundary

python3 tools/ci/run_runner_suite.py \
  --vectors-root conformance/vectors \
  --commit-sha "$COMMIT_SHA" \
  --out "$OUT_DIR/evidence/suite-run-ts.json" \
  --runner-cmd node runner/typescript/dist/src/cli.js run --strict --vector

cp runner/typescript/.divergence-c01.json "$OUT_DIR/evidence/divergence-c01.json"
cp runner/typescript/.divergence-full.json "$OUT_DIR/evidence/divergence-full.json"
cp runner/typescript/.properties-full.json "$OUT_DIR/evidence/property-tests.json"
cp runner/typescript/.c01-last-run.json "$OUT_DIR/evidence/ts-c01-summary.json"
cp runner/typescript/.full-last-run.json "$OUT_DIR/evidence/ts-full-summary.json"
cp artifacts/sdk-suite-summary.json "$OUT_DIR/evidence/sdk-suite-summary.json"

python3 tools/ci/generate_vector_manifest.py \
  --vectors-root conformance/vectors \
  --pattern '*.json' \
  --out "$OUT_DIR/evidence/vector-manifest.json"

python3 tools/ci/build_inputs_hashes.py --out "$OUT_DIR/evidence/inputs-hashes.json"
python3 tools/ci/audit_invariants.py \
  --out-json "$OUT_DIR/evidence/invariants-audit.json" \
  --out-md "$OUT_DIR/evidence/invariants-audit.md"

python3 tools/ci/build_interop_summary.py \
  --commit-sha "$COMMIT_SHA" \
  --out-dir "$OUT_DIR/evidence" \
  --suite-rust "$OUT_DIR/evidence/suite-run-rust.json" \
  --suite-ts "$OUT_DIR/evidence/suite-run-ts.json" \
  --div-c01 "$OUT_DIR/evidence/divergence-c01.json" \
  --div-full "$OUT_DIR/evidence/divergence-full.json" \
  --properties "$OUT_DIR/evidence/property-tests.json" \
  --invariants-audit "$OUT_DIR/evidence/invariants-audit.json"

if [[ "$ENABLE_FUZZ_SMOKE" == "1" ]]; then
  "$ROOT/scripts/fuzz-smoke" --out-dir "$OUT_DIR/fuzz-smoke"
  cp "$OUT_DIR/fuzz-smoke/stabilization-evidence.json" "$OUT_DIR/evidence/fuzz-smoke-results.json"
  python3 tools/ci/generate_vector_manifest.py \
    --vectors-root "$OUT_DIR/fuzz-smoke/corpus" \
    --pattern '*.json' \
    --out "$OUT_DIR/evidence/fuzz-corpus.manifest.json"
fi

python3 tools/ci/compute_evidence_sha.py \
  --base-dir "$OUT_DIR/evidence" \
  --out "$OUT_DIR/evidence/evidence_content.sha256" \
  --file divergence-c01.json \
  --file divergence-full.json \
  --file inputs-hashes.json \
  --file interop-evidence.json \
  --file interop-report.md \
  --file invariants-audit.json \
  --file property-tests.json \
  --file suite-run-rust.json \
  --file suite-run-ts.json \
  --file vector-manifest.json

OUT_DIR="$OUT_DIR" COMMIT_SHA="$COMMIT_SHA" python3 - <<'PY'
from __future__ import annotations
import json
import os
import platform
from datetime import datetime, timezone
from pathlib import Path

root = Path(os.environ["OUT_DIR"])
out = root / "evidence"
meta = {
    "commit_sha": os.environ["COMMIT_SHA"],
    "verdict": "PASS",
    "runtime": "container",
    "host": platform.platform(),
    "evidence_sha256_path": str(out / "evidence_content.sha256"),
    "summary_path": str(root / "summary.md"),
    "timestamp_utc": datetime.now(timezone.utc).isoformat(),
}
(out / "metadata.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
(root / "meta.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

summary = "\n".join(
    [
        "# Verification Pack Summary",
        "",
        "- Verdict: PASS",
        f"- Commit SHA: {meta['commit_sha']}",
        f"- Evidence SHA path: {meta['evidence_sha256_path']}",
        f"- Generated at (UTC): {meta['timestamp_utc']}",
        "",
        "Key checks:",
        "- Python policy checks: PASS",
        "- Rust strict suite: PASS",
        "- TypeScript strict suite: PASS",
        "- SDK suite + invariants + AI boundary: PASS",
        "- Interop summary: PASS",
        "",
    ]
)
(root / "summary.md").write_text(summary + "\n", encoding="utf-8")
PY

echo "container verify complete: $OUT_DIR/evidence/evidence_content.sha256"
