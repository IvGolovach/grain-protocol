#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

APP_DIR="examples/android-reference-app"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-android-reference-app.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -d "$APP_DIR" ]]; then
  echo "SDK_ANDROID_APP_ERR_MISSING: examples/android-reference-app is required" >&2
  exit 1
fi

RUST_TARGET=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  HOST_ARCH="$(uname -m)"
  JVM_ARCH="$(java -XshowSettings:properties -version 2>&1 | awk -F= '/os.arch/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')"
  if [[ "$HOST_ARCH" == "arm64" && "$JVM_ARCH" == "x86_64" ]]; then
    RUST_TARGET="x86_64-apple-darwin"
  fi
fi

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

has_raw_protocol_api() {
  local pattern='GrainClientFFI|uniffi\.grain_client_core|grain_run_vector\b|runvector\b|qrdecode\b|qr_decode(_gr1)?\b|coseverify\b|cose_verify\b|dagcbor\b|dag_cbor\b|dagcbor_validate\b|protocolrunner\b|executeoperation\b|execute_operation\b'
  python3 tools/ci/find_regex_match.py \
    --ignore-case "$pattern" \
    "$APP_DIR/src" \
    "$APP_DIR/README.md" \
    >/dev/null
}

if has_raw_protocol_api; then
  echo "SDK_ANDROID_APP_ERR_RAW_PROTOCOL_API: Android reference app must use public SDK/example modules only" >&2
  exit 1
else
  RAW_API_STATUS=$?
  if [[ "$RAW_API_STATUS" -ne 1 ]]; then
    exit "$RAW_API_STATUS"
  fi
fi

has_hidden_trust_lookup() {
  local pattern='OkHttp\b|HttpURLConnection\b|HttpsURLConnection\b|java\.net|Retrofit\b|Ktor\b|HttpClient\b|Socket\b|SSLSocket\b|X509TrustManager\b|TrustManagerFactory\b|AndroidCAStore|fetch\(|XMLHttpRequest|WebSocket|defaultTrust|fallbackTrust|autoDiscover|wellKnown|TOFU|allowAnyIssuer|allowAllIssuers'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" "$APP_DIR" >/dev/null
}

if has_hidden_trust_lookup; then
  echo "SDK_ANDROID_APP_ERR_HIDDEN_TRUST_LOOKUP: Android reference app must use injected local trust without fallback discovery" >&2
  exit 1
else
  TRUST_LOOKUP_STATUS=$?
  if [[ "$TRUST_LOOKUP_STATUS" -ne 1 ]]; then
    exit "$TRUST_LOOKUP_STATUS"
  fi
fi

has_secret_logging() {
  local sensitive='snapshotB64|snapshot_b64|bundleB64|bundle_b64|identityBundle|identity_bundle|syncBundle|sync_bundle|syncSecret|sync_secret_b64|envelopeB64|envelope_b64|coseB64|cose_b64|trustPubB64|trust_pub_b64|trustMaterial|trust_material'
  local pattern="(print|println|Log\\.[a-z]+|Timber\\.[a-z]+|Logger\\.[a-z]+)\\s*\\([^)]*(${sensitive})"
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" "$APP_DIR" >/dev/null
}

if has_secret_logging; then
  echo "SDK_ANDROID_APP_ERR_SECRET_LOGGING: Android reference app must not log snapshot, bundle, or trust material" >&2
  exit 1
else
  SECRET_LOGGING_STATUS=$?
  if [[ "$SECRET_LOGGING_STATUS" -ne 1 ]]; then
    exit "$SECRET_LOGGING_STATUS"
  fi
fi

if [[ -n "$RUST_TARGET" ]]; then
  if ! command -v rustup >/dev/null 2>&1; then
    echo "SDK_ANDROID_APP_ERR_RUSTUP_REQUIRED: rustup is required to build the JVM-matching Rust target" >&2
    exit 1
  fi
  RUSTUP_TOOLCHAIN="$(rustup show active-toolchain | awk '{print $1}')"
  rustup run "$RUSTUP_TOOLCHAIN" cargo build \
    --manifest-path core/rust/Cargo.toml \
    -p grain-client-core \
    --target "$RUST_TARGET"
  RUST_DEBUG_LIBRARY="core/rust/target/$RUST_TARGET/debug/libgrain_client_core.dylib"
else
  cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
  case "$(uname -s)" in
    Darwin) RUST_DEBUG_LIBRARY="core/rust/target/debug/libgrain_client_core.dylib" ;;
    Linux) RUST_DEBUG_LIBRARY="core/rust/target/debug/libgrain_client_core.so" ;;
    MINGW*|MSYS*|CYGWIN*) RUST_DEBUG_LIBRARY="core/rust/target/debug/grain_client_core.dll" ;;
    *) RUST_DEBUG_LIBRARY="" ;;
  esac
fi

GRADLE_ARGS=()
if [[ "${SDK_KOTLIN_GRADLE_OFFLINE:-0}" == "1" ]]; then
  GRADLE_ARGS+=(--offline)
fi

GRADLE_CMD=(
  sdk/kotlin/gradlew
  -p "$APP_DIR"
  --project-cache-dir "$TMP_DIR/gradle-cache"
  --no-daemon
  -Dgrain.kotlin.buildDir="$TMP_DIR/android-reference-build"
)
if [[ -n "$RUST_DEBUG_LIBRARY" ]]; then
  GRADLE_CMD+=("-Dgrain.kotlin.rustDebugLibrary=$ROOT/$RUST_DEBUG_LIBRARY")
fi
if [[ ${#GRADLE_ARGS[@]} -gt 0 ]]; then
  GRADLE_CMD+=("${GRADLE_ARGS[@]}")
fi
GRADLE_CMD+=(check)

"${GRADLE_CMD[@]}"
rm -rf "$APP_DIR/.gradle"

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_ANDROID_APP_ERR_DIRTY_WORKTREE: Android reference app check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "Android reference app check: PASS"
