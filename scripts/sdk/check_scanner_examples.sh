#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-scanner-examples.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

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
  local pattern='grain_run_vector\b|runvector\b|qrdecode\b|qr_decode(_gr1)?\b|coseverify\b|cose_verify\b|dagcbor\b|dag_cbor\b|dagcbor_validate\b|protocolrunner\b|executeoperation\b|execute_operation\b|uniffi\.grain_client_core'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" examples >/dev/null
}

if has_raw_protocol_api; then
  echo "SDK_SCANNER_ERR_RAW_PROTOCOL_API: scanner examples must use public workflow SDK APIs only" >&2
  exit 1
else
  RAW_API_STATUS=$?
  if [[ "$RAW_API_STATUS" -ne 1 ]]; then
    exit "$RAW_API_STATUS"
  fi
fi

has_hidden_trust_lookup() {
  local pattern='URLSession\b|OkHttp\b|HttpURLConnection\b|HttpsURLConnection\b|java\.net|Retrofit\b|Ktor\b|HttpClient\b|Socket\b|SSLSocket\b|X509TrustManager\b|TrustManagerFactory\b|AndroidCAStore|fetch\(|XMLHttpRequest|WebSocket|node:http|node:https|axios|undici|defaultTrust|fallbackTrust|autoDiscover|wellKnown|TOFU|allowAnyIssuer|allowAllIssuers|SecTrustEvaluate'
  python3 tools/ci/find_regex_match.py \
    --ignore-case "$pattern" \
    examples/ios-scanner \
    examples/ios-reference-app \
    examples/android-scanner \
    examples/android-reference-app \
    examples/wasm-scanner/src/scanner-shell.mjs \
    examples/wasm-scanner/src/camera-adapter.mjs \
    sdk/wasm/src/browser-storage.mjs \
    >/dev/null
}

if has_hidden_trust_lookup; then
  echo "SDK_SCANNER_ERR_HIDDEN_TRUST_LOOKUP: scanner examples must use injected trust providers without fallback or network discovery" >&2
  exit 1
else
  TRUST_LOOKUP_STATUS=$?
  if [[ "$TRUST_LOOKUP_STATUS" -ne 1 ]]; then
    exit "$TRUST_LOOKUP_STATUS"
  fi
fi

has_secret_logging() {
  local sensitive='snapshotB64|snapshot_b64|bundleB64|bundle_b64|identityBundle|identity_bundle|syncBundle|sync_bundle|syncSecret|sync_secret_b64|envelopeB64|envelope_b64|coseB64|cose_b64|trustPubB64|trust_pub_b64|trustMaterial|trust_material'
  local pattern="(print|println|debugPrint|NSLog|os_log|Log\\.[a-z]+|Timber\\.[a-z]+|Logger\\.[a-z]+|console\\.[a-z]+)\\s*\\([^)]*(${sensitive})"
  python3 tools/ci/find_regex_match.py \
    --ignore-case "$pattern" \
    examples/ios-scanner \
    examples/ios-reference-app \
    examples/android-scanner \
    examples/android-reference-app \
    examples/wasm-scanner/src/scanner-shell.mjs \
    examples/wasm-scanner/src/camera-adapter.mjs \
    sdk/swift/Sources/GrainClientIOSAdapters \
    sdk/kotlin/src/main/kotlin/dev/grain/android \
    sdk/wasm/src/browser-storage.mjs \
    sdk/swift/README.md \
    sdk/kotlin/README.md \
    sdk/wasm/README.md \
    >/dev/null
}

if has_secret_logging; then
  echo "SDK_SCANNER_ERR_SECRET_LOGGING: scanner/platform adapter examples must not log snapshot, bundle, or trust material" >&2
  exit 1
else
  SECRET_LOGGING_STATUS=$?
  if [[ "$SECRET_LOGGING_STATUS" -ne 1 ]]; then
    exit "$SECRET_LOGGING_STATUS"
  fi
fi

if [[ -n "$RUST_TARGET" ]]; then
  if ! command -v rustup >/dev/null 2>&1; then
    echo "SDK_SCANNER_ERR_RUSTUP_REQUIRED: rustup is required to build the JVM-matching Rust target" >&2
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
swift run --package-path examples/ios-scanner --scratch-path "$TMP_DIR/swift" GrainIOSScannerSmoke
scripts/sdk/check_ios_reference_app.sh
scripts/sdk/check_android_reference_app.sh

GRADLE_ARGS=()
if [[ "${SDK_KOTLIN_GRADLE_OFFLINE:-0}" == "1" ]]; then
  GRADLE_ARGS+=(--offline)
fi

GRADLE_CMD=(
  sdk/kotlin/gradlew
  -p examples/android-scanner
  --project-cache-dir "$TMP_DIR/gradle-cache"
  --no-daemon
  -Dgrain.kotlin.buildDir="$TMP_DIR/android-build"
)
if [[ -n "$RUST_DEBUG_LIBRARY" ]]; then
  GRADLE_CMD+=("-Dgrain.kotlin.rustDebugLibrary=$ROOT/$RUST_DEBUG_LIBRARY")
fi
if [[ ${#GRADLE_ARGS[@]} -gt 0 ]]; then
  GRADLE_CMD+=("${GRADLE_ARGS[@]}")
fi
GRADLE_CMD+=(check)

"${GRADLE_CMD[@]}"
rm -rf examples/android-scanner/.gradle

npm --prefix examples/wasm-scanner run check
npm --prefix examples/wasm-scanner run test:smoke

LEFTOVER_JUNK="$(
  find examples \
    \( -name .build -o -name .gradle -o -name build -o -name dist -o -name node_modules -o -name '*.wasm' \) \
    -print -quit
)"
if [[ -n "$LEFTOVER_JUNK" ]]; then
  echo "SDK_SCANNER_ERR_GENERATED_JUNK: scanner example check left generated files at $LEFTOVER_JUNK" >&2
  exit 1
fi

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_SCANNER_ERR_DIRTY_WORKTREE: scanner example check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "scanner examples check: PASS"
