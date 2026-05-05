#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

ensure_wasm_target_ready() {
  if command -v rustup >/dev/null 2>&1; then
    rustup target add wasm32-wasip1
  fi

  local libdir
  libdir="$(rustc --print target-libdir --target wasm32-wasip1 2>/dev/null)" || {
    echo "SDK_WASM_ERR_TARGET_MISSING: active rustc cannot resolve wasm32-wasip1 target libdir" >&2
    return 1
  }
  if ! compgen -G "$libdir/libcore-*.rlib" >/dev/null; then
    echo "SDK_WASM_ERR_TARGET_MISSING: active rustc cannot find wasm32-wasip1 libcore at $libdir" >&2
    echo "rustc: $(command -v rustc)" >&2
    echo "cargo: $(command -v cargo)" >&2
    return 1
  fi
}

has_raw_protocol_api() {
  local pattern='grain_run_vector\b|runvector\b|qrdecode\b|qr_decode(_gr1)?\b|coseverify\b|cose_verify\b|dagcbor\b|dag_cbor\b|dagcbor_validate\b|protocolrunner\b|executeoperation\b|execute_operation\b'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" sdk/wasm/src >/dev/null
}

npm --prefix sdk/wasm run check
npm --prefix sdk/wasm run test:browser-adapters

if has_raw_protocol_api; then
  echo "SDK_WASM_ERR_RAW_PROTOCOL_API: WASM public wrapper must expose workflow APIs only" >&2
  exit 1
else
  RAW_API_STATUS=$?
  if [[ "$RAW_API_STATUS" -ne 1 ]]; then
    exit "$RAW_API_STATUS"
  fi
fi

if [[ "${SDK_WASM_TARGET_READY:-0}" != "1" ]]; then
  ensure_wasm_target_ready
fi
cargo check --manifest-path core/rust/Cargo.toml -p grain-client-wasm
cargo build --manifest-path core/rust/Cargo.toml -p grain-client-wasm --target wasm32-wasip1 --release

npm --prefix sdk/wasm run test:fixtures

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_WASM_ERR_DIRTY_WORKTREE: WASM package check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "wasm package check: PASS"
