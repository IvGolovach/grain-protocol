#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

npm --prefix sdk/wasm run check

if rg -n -i 'grain_run_vector|runvector|qrdecode|qr_decode(_gr1)?|coseverify|cose_verify|dagcbor|dag_cbor|dagcbor_validate|protocolrunner|executeoperation|execute_operation' sdk/wasm/src >/dev/null; then
  echo "SDK_WASM_ERR_RAW_PROTOCOL_API: WASM public wrapper must expose workflow APIs only" >&2
  exit 1
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
