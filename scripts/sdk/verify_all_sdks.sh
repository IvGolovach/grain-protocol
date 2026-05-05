#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

OUT_DIR="artifacts/sdk-verify-all"
STRICT=0

usage() {
  cat <<'EOF'
Usage: scripts/sdk/verify_all_sdks.sh [options]

Checks generated SDK lanes through the repo's public workflow surfaces.

Options:
  --out-dir <path>  Write an ignored summary log to this directory
  --strict          Fail when an optional platform prerequisite is unavailable
  -h, --help        Show this help

Default mode runs mandatory SDK checks and any platform smoke build whose
local prerequisites are available. Strict mode is intended for release machines
and CI lanes that have Swift, Java, Node/npm, Cargo, and wasm32-wasip1 ready.
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

wasm_target_installed() {
  have_cmd rustup && rustup target list --installed 2>/dev/null | grep -qx 'wasm32-wasip1'
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

if have_cmd swift; then
  run_check "Swift client package" scripts/sdk/check_swift_package.sh
else
  skip_or_fail "SDK_VERIFY_ERR_SWIFT_MISSING" "swift command not found"
fi

if have_cmd java; then
  run_check "Kotlin client package" env SDK_KOTLIN_GRADLE_OFFLINE=1 scripts/sdk/check_kotlin_package.sh
else
  skip_or_fail "SDK_VERIFY_ERR_JAVA_MISSING" "java command not found"
fi

if have_cmd npm; then
  run_check "WASM wrapper static check" npm --prefix sdk/wasm run check
else
  skip_or_fail "SDK_VERIFY_ERR_NPM_MISSING" "npm command not found"
fi

if wasm_target_installed; then
  run_check "WASM client package" scripts/sdk/check_wasm_package.sh
else
  skip_or_fail "SDK_VERIFY_ERR_WASM_TARGET_MISSING" "rust target wasm32-wasip1 is not installed"
fi

if have_cmd swift && have_cmd java && have_cmd npm; then
  run_check "reference scanner examples" scripts/sdk/check_scanner_examples.sh
else
  skip_or_fail "SDK_VERIFY_ERR_SCANNER_PREREQ_MISSING" "scanner example check requires swift, java, and npm"
fi

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_VERIFY_ERR_DIRTY_WORKTREE: SDK verification changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

log "sdk verify all: PASS"
log "summary: $LOG"
