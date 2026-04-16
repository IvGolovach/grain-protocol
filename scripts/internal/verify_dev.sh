#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

OUT_DIR="artifacts/dev-verify"

usage() {
  cat <<'EOF'
Usage: ./scripts/verify [--out-dir <path>]

Fast developer verification on pinned local toolchains.

This path is intended for day-to-day work:
- no clean-tree requirement
- no container image build
- no evidence bundle generation

For release-grade evidence generation, use:
  ./scripts/certify
EOF
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

read_mise_tool_pin() {
  local key="$1"
  awk -F'"' -v key="$key" '$0 ~ "^[[:space:]]*" key " = " { print $2; exit }' "$ROOT/mise.toml"
}

developer_verify_toolchain_help() {
  if have_cmd mise; then
    printf "run: ./scripts/bootstrap"
  else
    printf "next step: install mise, then run ./scripts/bootstrap"
  fi
}

version_matches_prefix() {
  local actual="$1"
  local expected="$2"
  [[ "$actual" == "$expected" || "$actual" == "$expected".* ]]
}

PINNED_ENV_READY=0
VERIFY_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --_pinned-env-ready)
      PINNED_ENV_READY=1
      shift
      ;;
    --out-dir)
      OUT_DIR="$2"
      VERIFY_ARGS+=("$1" "$2")
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

ensure_pinned_env() {
  local pinned_node pinned_python pinned_rust
  pinned_node="$(tr -d '\n' < "$ROOT/.nvmrc" 2>/dev/null || printf 'missing')"
  pinned_python="$(read_mise_tool_pin python)"
  pinned_rust="$(read_mise_tool_pin rust)"

  if [[ "$PINNED_ENV_READY" == "1" ]]; then
    return 0
  fi

  if have_cmd mise; then
    exec mise exec -- "$ROOT/scripts/internal/verify_dev.sh" --_pinned-env-ready "${VERIFY_ARGS[@]}"
  fi

  local errors=()
  local python_version node_version cargo_version

  if ! have_cmd python3; then
    errors+=("python3: missing (expected ${pinned_python}.x)")
  else
    python_version="$(python3 --version 2>&1 | awk '{print $2}')"
    if ! version_matches_prefix "$python_version" "$pinned_python"; then
      errors+=("python3: $python_version (expected ${pinned_python}.x)")
    fi
  fi

  if ! have_cmd node; then
    errors+=("node: missing (expected v${pinned_node})")
  else
    node_version="$(node -v 2>/dev/null || true)"
    if [[ "$node_version" != "v${pinned_node}" ]]; then
      errors+=("node: ${node_version:-missing} (expected v${pinned_node})")
    fi
  fi

  if ! have_cmd npm; then
    errors+=("npm: missing")
  fi

  if ! have_cmd cargo; then
    errors+=("cargo: missing (expected ${pinned_rust})")
  else
    cargo_version="$(cargo -V 2>/dev/null | awk '{print $2}')"
    if [[ "$cargo_version" != "$pinned_rust" ]]; then
      errors+=("cargo: ${cargo_version:-missing} (expected ${pinned_rust})")
    fi
  fi

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo "DEV_VERIFY_ERR_PINNED_TOOLCHAIN: developer verify requires the repo's pinned local toolchain." >&2
    for error in "${errors[@]}"; do
      echo "- $error" >&2
    done
    echo "$(developer_verify_toolchain_help)" >&2
    exit 1
  fi
}

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

ensure_pinned_env

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
python3 tools/ci/check_toolchain_bootstrap.py
python3 tools/ci/check_workflow_action_pinning.py
python3 tools/ci/check_docs_links.py
python3 tools/ci/check_docs_flow.py
python3 tools/ci/check_maintainer_docs.py
python3 tools/ci/check_runner_contract_compat.py
python3 tools/ci/check_runner_shim_boundary.py
python3 tools/ci/check_prohibition_coverage.py
python3 tools/ci/check_capid_csprng.py
python3 tools/ci/check_sdk_no_network.py
python3 tools/ci/check_sdk_ai_boundary.py

cargo test --manifest-path core/rust/Cargo.toml --workspace
cargo build --manifest-path core/rust/Cargo.toml -p grain-runner

python3 tools/ci/check_quickstart_smoke.py \
  --runner-cmd core/rust/target/debug/grain-runner demo --strict

npm ci --prefix core/ts/grain-ts-core
npm ci --prefix runner/typescript
if [[ -f core/ts/grain-sdk/package-lock.json ]]; then
  npm ci --prefix core/ts/grain-sdk
fi
if [[ -f core/ts/grain-sdk-ai/package-lock.json ]]; then
  npm ci --prefix core/ts/grain-sdk-ai
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
npm --prefix core/ts/grain-sdk-ai run test:boundary

cp runner/typescript/.c01-last-run.json "$OUT_DIR_ABS/ts-c01-summary.json"
cp runner/typescript/.divergence-c01.json "$OUT_DIR_ABS/divergence-c01.json"
cp runner/typescript/.full-last-run.json "$OUT_DIR_ABS/ts-full-summary.json"
cp runner/typescript/.divergence-full.json "$OUT_DIR_ABS/divergence-full.json"
cp runner/typescript/.properties-full.json "$OUT_DIR_ABS/properties-full.json"
cp artifacts/sdk-suite-summary.json "$OUT_DIR_ABS/sdk-suite-summary.json"

echo "verify: PASS"
echo "mode: developer"
echo "artifacts: $OUT_DIR_ABS"
