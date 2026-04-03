#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OUT_DIR="artifacts/dev-verify"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify [--out-dir <path>]

Fast developer verification on host toolchains.

This path is intended for day-to-day work:
- no clean-tree requirement
- no container image build
- no evidence bundle generation

For release-grade evidence generation, use:
  ./scripts/certify
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument for developer verify: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$OUT_DIR" = /* ]]; then
  if [[ "$OUT_DIR" != "$ROOT"/* ]]; then
    echo "DEV_VERIFY_ERR_OUT_DIR_OUTSIDE_REPO: out-dir must be inside repository root" >&2
    exit 1
  fi
  OUT_DIR_REL="${OUT_DIR#"$ROOT"/}"
else
  OUT_DIR_REL="${OUT_DIR#./}"
fi

OUT_DIR_ABS="$ROOT/$OUT_DIR_REL"
mkdir -p "$OUT_DIR_ABS"

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

cargo test --manifest-path core/rust/Cargo.toml --workspace
cargo build --manifest-path core/rust/Cargo.toml -p grain-runner

python3 tools/ci/check_quickstart_smoke.py \
  --runner-cmd core/rust/target/debug/grain-runner demo --strict

npm ci --prefix runner/typescript
if [[ -f core/ts/grain-sdk/package-lock.json ]]; then
  npm ci --prefix core/ts/grain-sdk
fi

npm --prefix runner/typescript run run:c01
GRAIN_RUST_RUNNER_BIN=core/rust/target/debug/grain-runner npm --prefix runner/typescript run divergence:c01
npm --prefix runner/typescript run run:full
GRAIN_RUST_RUNNER_BIN=core/rust/target/debug/grain-runner npm --prefix runner/typescript run divergence:full
npm --prefix runner/typescript run test:cborseq-contract
npm --prefix runner/typescript run test:properties
npm --prefix runner/typescript run test:integer-precision
npm --prefix core/ts/grain-sdk run run:protocol-suite
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk run test:ai-boundary

cp runner/typescript/.c01-last-run.json "$OUT_DIR_ABS/ts-c01-summary.json"
cp runner/typescript/.divergence-c01.json "$OUT_DIR_ABS/divergence-c01.json"
cp runner/typescript/.full-last-run.json "$OUT_DIR_ABS/ts-full-summary.json"
cp runner/typescript/.divergence-full.json "$OUT_DIR_ABS/divergence-full.json"
cp runner/typescript/.properties-full.json "$OUT_DIR_ABS/properties-full.json"
cp artifacts/sdk-suite-summary.json "$OUT_DIR_ABS/sdk-suite-summary.json"

echo "verify: PASS"
echo "mode: developer"
echo "artifacts: $OUT_DIR_ABS"
