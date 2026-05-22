#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

OUT_DIR="artifacts/sdk-verify-all"
STRICT=0

usage() {
  cat <<'EOF'
Usage: scripts/sdk/verify_all_sdks.sh [options]

Checks generated SDK lanes through the repo's public workflow surfaces:
public API policy, device adapter contract, reference apps, starter templates,
local registry dry-runs, and external-client certification.

Options:
  --out-dir <path>  Write an ignored summary log to this directory
  --strict          Fail when an optional platform prerequisite is unavailable
  -h, --help        Show this help

Default mode runs mandatory SDK checks and any platform smoke build whose
local prerequisites are available. Strict mode is intended for release machines
and CI lanes that have Swift, Java, Node/npm, Cargo, and wasm32-wasip1 ready.

Set SDK_KOTLIN_GRADLE_OFFLINE=1 after warming Gradle caches to force the
Kotlin and Android scanner checks to resolve dependencies offline.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
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
      echo "SDK_VERIFY_ERR_UNKNOWN_ARG: $1" >&2
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
      echo "SDK_VERIFY_ERR_OUT_DIR_OUTSIDE_REPO: out-dir must be inside repository root" >&2
      exit 1
      ;;
  esac
}

OUT_DIR_ABS="$(resolve_out_dir "$OUT_DIR")"

mkdir -p "$OUT_DIR_ABS"
LOG="$OUT_DIR_ABS/summary.log"
# Summary logs are per run; use a distinct --out-dir to preserve prior output.
: > "$LOG"

log() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_check() {
  local name="$1"
  shift
  log "== $name =="
  "$@" 2>&1 | tee -a "$LOG"
}

skip_or_fail() {
  local code="$1"
  local message="$2"
  if [[ "$STRICT" -eq 1 ]]; then
    echo "$code: $message" >&2
    exit 1
  fi
  log "SKIP $code: $message"
}

ensure_wasm_target_ready() {
  if have_cmd rustup; then
    rustup target add wasm32-wasip1
  fi

  local libdir
  libdir="$(rustc --print target-libdir --target wasm32-wasip1 2>/dev/null)" || {
    echo "active rustc cannot resolve wasm32-wasip1 target libdir" >&2
    return 1
  }
  if ! compgen -G "$libdir/libcore-*.rlib" >/dev/null; then
    echo "active rustc cannot find wasm32-wasip1 libcore at $libdir" >&2
    echo "rustc: $(command -v rustc)" >&2
    echo "cargo: $(command -v cargo)" >&2
    return 1
  fi
  echo "wasm32-wasip1 target libdir: $libdir"
}

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

run_check "rust client workflow tests" \
  cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
run_check "client workflow fixture lint" \
  python3 tools/ci/check_client_workflow_fixtures.py
run_check "generated binding harness" \
  scripts/sdk/check_generated_bindings.sh
run_check "SDK docs and no-network checks" \
  python3 tools/check_llm_docs.py
run_check "SDK spec drift check" \
  python3 tools/check_spec_drift.py
run_check "SDK no-network policy" \
  python3 tools/ci/check_sdk_no_network.py
run_check "SDK trust-provider boundary policy" \
  python3 tools/ci/check_sdk_trust_provider_boundary.py
run_check "SDK secret logging policy" \
  python3 tools/ci/check_sdk_secret_logging.py
run_check "public SDK API snapshot" \
  python3 tools/ci/check_public_sdk_api.py
run_check "device adapter contract" \
  python3 tools/ci/check_device_adapter_contract.py
run_check "safe diagnostic telemetry policy" \
  python3 tools/ci/check_no_secret_telemetry.py
run_check "trust bundle governance policy" \
  python3 tools/ci/check_trust_bundle_governance.py
run_check "release train docs policy" \
  python3 tools/ci/check_release_train_docs.py
run_check "Food Wallet contract policy" \
  scripts/sdk/check_food_wallet_contract.sh

if have_cmd node && have_cmd npm; then
  run_check "TypeScript Food Wallet SDK smoke" \
    npm --prefix core/ts/grain-sdk run test:food-wallet
  run_check "TypeScript Food Wallet AI boundary smoke" \
    npm --prefix core/ts/grain-sdk-ai run test:food-boundary
else
  skip_or_fail "SDK_VERIFY_ERR_TS_FOOD_WALLET_PREREQ_MISSING" "node and npm are required for TypeScript Food Wallet checks"
fi

if have_cmd cargo && have_cmd rustc && have_cmd npm; then
  if run_check "WASM target ready" ensure_wasm_target_ready; then
    run_check "WASM client package" env SDK_WASM_TARGET_READY=1 scripts/sdk/check_wasm_package.sh
  else
    skip_or_fail "SDK_VERIFY_ERR_WASM_TARGET_MISSING" "active rustc cannot see wasm32-wasip1 libcore; ensure the pinned rustup cargo/rustc are first on PATH"
  fi
else
  skip_or_fail "SDK_VERIFY_ERR_WASM_PREREQ_MISSING" "cargo, rustc, and npm are required for WASM package check"
fi

if have_cmd node && have_cmd npm && have_cmd cargo && have_cmd rustc; then
  run_check "Food Wallet local pilot" scripts/sdk/run_food_wallet_pilot.sh --out-dir "$OUT_DIR_ABS/food-wallet-pilot"
else
  skip_or_fail "SDK_VERIFY_ERR_FOOD_WALLET_PILOT_PREREQ_MISSING" "node, npm, cargo, and rustc are required for Food Wallet local pilot"
fi

if have_cmd swift; then
  run_check "Swift client package" scripts/sdk/check_swift_package.sh
  run_check "Swift Food Wallet smoke" scripts/sdk/check_swift_food_wallet.sh --policy-only
else
  skip_or_fail "SDK_VERIFY_ERR_SWIFT_MISSING" "swift command not found"
fi

if have_cmd java && have_cmd cargo && have_cmd rustc; then
  run_check "Kotlin client package" scripts/sdk/check_kotlin_package.sh
  run_check "Kotlin Food Wallet smoke" scripts/sdk/check_kotlin_food_wallet.sh --policy-only
else
  skip_or_fail "SDK_VERIFY_ERR_KOTLIN_PREREQ_MISSING" "java, cargo, and rustc are required for Kotlin package check"
fi

if have_cmd swift && have_cmd java && have_cmd npm && have_cmd cargo && have_cmd rustc; then
  run_check "reference scanner examples" scripts/sdk/check_scanner_examples.sh
  run_check "starter templates" scripts/sdk/check_starter_templates.sh
else
  skip_or_fail "SDK_VERIFY_ERR_SCANNER_PREREQ_MISSING" "scanner example and starter template checks require swift, java, npm, cargo, and rustc"
fi

run_check "local registry dry-runs" \
  scripts/sdk/check_registry_dry_runs.sh --out-dir "$OUT_DIR_ABS/registry-dry-runs"
run_check "external client certification" \
  env \
    CLIENT_NAME=grain-local-reference-apps \
    CLIENT_OWNER=grain-maintainers \
    OUT_DIR="$OUT_DIR_ABS/external-client-certification" \
    scripts/sdk/certify_external_client.sh

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_VERIFY_ERR_DIRTY_WORKTREE: SDK verification changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

log "sdk verify all: PASS"
log "summary: $LOG"
