#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT_DIR="artifacts/interop"
COMMIT_SHA="$(git rev-parse HEAD)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --commit-sha)
      COMMIT_SHA="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "$OUT_DIR"

python3 tools/validate_vectors.py
python3 tools/check_llm_docs.py
python3 tools/check_spec_drift.py
python3 tools/ci/check_gitattributes_policy.py
python3 tools/ci/check_forbidden_tracked.py
python3 tools/ci/check_crlf_tracked.py
python3 tools/ci/check_codeowners_coverage.py
python3 tools/ci/check_dependabot_policy.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 -m py_compile tools/*.py tools/ci/*.py

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required for divergence checks and rust fallback execution." >&2
  exit 2
fi

npm ci --prefix runner/typescript >/dev/null

RUST_SUITE_OUT="$OUT_DIR/suite-run-rust.json"
if command -v cargo >/dev/null 2>&1; then
  if cargo build --manifest-path core/rust/Cargo.toml -p grain-runner >/dev/null; then
    python3 tools/ci/run_runner_suite.py \
      --vectors-root conformance/vectors \
      --commit-sha "$COMMIT_SHA" \
      --out "$RUST_SUITE_OUT" \
      --runner-cmd core/rust/target/debug/grain-runner run --strict --vector
  else
    echo "local cargo build failed; falling back to docker rust runner." >&2
    TMP_RUST_SUMMARY="artifacts/.tmp-suite-run-rust.json"
    mkdir -p artifacts
    docker run --rm \
      -v "$ROOT":/work \
      -w /work \
      rust:1.86 \
      bash -lc 'set -euo pipefail; export PATH=/usr/local/cargo/bin:$PATH; cargo build --manifest-path core/rust/Cargo.toml -p grain-runner >/dev/null; python3 tools/ci/run_runner_suite.py --vectors-root conformance/vectors --commit-sha "$1" --out /work/'"$TMP_RUST_SUMMARY"' --runner-cmd core/rust/target/debug/grain-runner run --strict --vector' -- "$COMMIT_SHA"
    cp "$TMP_RUST_SUMMARY" "$RUST_SUITE_OUT"
    rm -f "$TMP_RUST_SUMMARY"
  fi
else
  TMP_RUST_SUMMARY="artifacts/.tmp-suite-run-rust.json"
  mkdir -p artifacts
  docker run --rm \
    -v "$ROOT":/work \
    -w /work \
    rust:1.86 \
    bash -lc 'set -euo pipefail; export PATH=/usr/local/cargo/bin:$PATH; cargo build --manifest-path core/rust/Cargo.toml -p grain-runner >/dev/null; python3 tools/ci/run_runner_suite.py --vectors-root conformance/vectors --commit-sha "$1" --out /work/'"$TMP_RUST_SUMMARY"' --runner-cmd core/rust/target/debug/grain-runner run --strict --vector' -- "$COMMIT_SHA"
  cp "$TMP_RUST_SUMMARY" "$RUST_SUITE_OUT"
  rm -f "$TMP_RUST_SUMMARY"
fi

python3 tools/ci/run_runner_suite.py \
  --vectors-root conformance/vectors \
  --commit-sha "$COMMIT_SHA" \
  --out "$OUT_DIR/suite-run-ts.json" \
  --runner-cmd node --experimental-strip-types runner/typescript/src/cli.ts run --strict --vector

NODE_NO_WARNINGS=1 node --experimental-strip-types runner/typescript/scripts/run-c01.ts >/dev/null
NODE_NO_WARNINGS=1 node --experimental-strip-types runner/typescript/scripts/run-full.ts >/dev/null
NODE_NO_WARNINGS=1 node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts >/dev/null
NODE_NO_WARNINGS=1 node --experimental-strip-types runner/typescript/scripts/divergence-full.ts >/dev/null
NODE_NO_WARNINGS=1 node --experimental-strip-types runner/typescript/scripts/properties-full.ts >/dev/null

cp runner/typescript/.divergence-c01.json "$OUT_DIR/divergence-c01.json"
cp runner/typescript/.divergence-full.json "$OUT_DIR/divergence-full.json"
cp runner/typescript/.properties-full.json "$OUT_DIR/property-tests.json"

python3 tools/ci/generate_vector_manifest.py \
  --vectors-root conformance/vectors \
  --pattern '*.json' \
  --out "$OUT_DIR/vector-manifest.json"

python3 tools/ci/build_inputs_hashes.py --out "$OUT_DIR/inputs-hashes.json"
python3 tools/ci/audit_invariants.py --out-json "$OUT_DIR/invariants-audit.json" --out-md "$OUT_DIR/invariants-audit.md"

python3 tools/ci/build_interop_summary.py \
  --commit-sha "$COMMIT_SHA" \
  --out-dir "$OUT_DIR" \
  --suite-rust "$OUT_DIR/suite-run-rust.json" \
  --suite-ts "$OUT_DIR/suite-run-ts.json" \
  --div-c01 "$OUT_DIR/divergence-c01.json" \
  --div-full "$OUT_DIR/divergence-full.json" \
  --properties "$OUT_DIR/property-tests.json" \
  --invariants-audit "$OUT_DIR/invariants-audit.json"

python3 tools/ci/compute_evidence_sha.py \
  --base-dir "$OUT_DIR" \
  --out "$OUT_DIR/evidence.sha256" \
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

echo "Interop certification bundle ready: $OUT_DIR"
