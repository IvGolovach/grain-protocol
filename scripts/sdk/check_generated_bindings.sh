#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-sdk-bindings.XXXXXX")"
trap 'rm -rf "$OUT_DIR"' EXIT

scripts/sdk/generate_client_bindings.sh --out-dir "$OUT_DIR" --language all

if ! find "$OUT_DIR/swift" -type f -name '*.swift' | grep -q .; then
  echo "SDK_BINDGEN_ERR_SWIFT_MISSING: expected generated Swift files" >&2
  exit 1
fi

if ! find "$OUT_DIR/kotlin" -type f -name '*.kt' | grep -q .; then
  echo "SDK_BINDGEN_ERR_KOTLIN_MISSING: expected generated Kotlin files" >&2
  exit 1
fi

for expected in \
  grainScanPreview \
  grainScanAcceptPrepare \
  GrainClientMemoryStore \
  "scanAccept(request" \
  listAcceptedScans \
  createRootIdentity \
  addDeviceKey \
  clientLifecycle \
  createPairingEnvelope \
  acceptPairingEnvelope \
  importSyncBundle \
  exportStoreSnapshot \
  restoreStoreSnapshot \
  FfiScanPreviewRequest \
  FfiScanAcceptRequest \
  FfiIdentityResult \
  FfiDeviceResult \
  FfiPairingEnvelopeRequest \
  FfiSyncBundleRequest \
  FfiStoreSnapshotResult; do
  if ! grep -R "$expected" "$OUT_DIR" >/dev/null 2>&1; then
    echo "SDK_BINDGEN_ERR_PUBLIC_SYMBOL_MISSING: expected generated symbol $expected" >&2
    exit 1
  fi
done

for forbidden in qr_decode_gr1 cose_verify dagcbor_validate grain_runner; do
  if grep -R "$forbidden" \
    core/rust/grain-client-core/src/grain_client_core.udl \
    "$OUT_DIR" >/dev/null 2>&1; then
    echo "SDK_BINDGEN_ERR_RAW_PROTOCOL_EXPOSED: found $forbidden in generated bindings" >&2
    exit 1
  fi
done

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_BINDGEN_ERR_DIRTY_WORKTREE: generated binding check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "sdk generated binding check: PASS"
