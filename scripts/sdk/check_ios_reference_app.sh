#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

APP_DIR="examples/ios-reference-app"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-ios-reference-app.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -d "$APP_DIR" ]]; then
  echo "SDK_IOS_APP_ERR_MISSING: examples/ios-reference-app is required" >&2
  exit 1
fi

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

has_raw_protocol_api() {
  local pattern='GrainClientFFI|grain_client_core|uniffi\.grain_client_core|grain_run_vector\b|runvector\b|qrdecode\b|qr_decode(_gr1)?\b|coseverify\b|cose_verify\b|dagcbor\b|dag_cbor\b|dagcbor_validate\b|protocolrunner\b|executeoperation\b|execute_operation\b'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" "$APP_DIR" >/dev/null
}

if has_raw_protocol_api; then
  echo "SDK_IOS_APP_ERR_RAW_PROTOCOL_API: iOS reference app must use public SDK/example modules only" >&2
  exit 1
else
  RAW_API_STATUS=$?
  if [[ "$RAW_API_STATUS" -ne 1 ]]; then
    exit "$RAW_API_STATUS"
  fi
fi

has_hidden_trust_lookup() {
  local pattern='URLSession\b|fetch\(|XMLHttpRequest|WebSocket|Socket\b|SSLSocket\b|SecTrustEvaluate|X509TrustManager\b|TrustManagerFactory\b|defaultTrust|fallbackTrust|autoDiscover|wellKnown|TOFU|allowAnyIssuer|allowAllIssuers'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" "$APP_DIR" >/dev/null
}

if has_hidden_trust_lookup; then
  echo "SDK_IOS_APP_ERR_HIDDEN_TRUST_LOOKUP: iOS reference app must use injected local trust without fallback discovery" >&2
  exit 1
else
  TRUST_LOOKUP_STATUS=$?
  if [[ "$TRUST_LOOKUP_STATUS" -ne 1 ]]; then
    exit "$TRUST_LOOKUP_STATUS"
  fi
fi

has_secret_logging() {
  local sensitive='snapshotB64|snapshot_b64|bundleB64|bundle_b64|identityBundle|identity_bundle|syncBundle|sync_bundle|syncSecret|sync_secret_b64|envelopeB64|envelope_b64|coseB64|cose_b64|trustPubB64|trust_pub_b64|trustMaterial|trust_material'
  local pattern="(print|debugPrint|NSLog|os_log|Logger\\.[a-z]+)\\s*\\([^)]*(${sensitive})"
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" "$APP_DIR" >/dev/null
}

if has_secret_logging; then
  echo "SDK_IOS_APP_ERR_SECRET_LOGGING: iOS reference app must not log snapshot, bundle, or trust material" >&2
  exit 1
else
  SECRET_LOGGING_STATUS=$?
  if [[ "$SECRET_LOGGING_STATUS" -ne 1 ]]; then
    exit "$SECRET_LOGGING_STATUS"
  fi
fi

cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift build --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift"
swift run --package-path "$APP_DIR" --scratch-path "$TMP_DIR/swift" GrainIOSReferenceAppSmoke

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_IOS_APP_ERR_DIRTY_WORKTREE: iOS reference app check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "iOS reference app check: PASS"
