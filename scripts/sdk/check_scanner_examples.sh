#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-scanner-examples.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -s)" == "Darwin" ]]; then
  HOST_ARCH="$(uname -m)"
  JVM_ARCH="$(java -XshowSettings:properties -version 2>&1 | awk -F= '/os.arch/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')"
  if [[ "$HOST_ARCH" == "arm64" && "$JVM_ARCH" == "x86_64" ]]; then
    echo "SDK_SCANNER_ERR_JVM_ARCH_MISMATCH: arm64 Rust dylib requires an arm64 JVM; set JAVA_HOME to an arm64 JDK" >&2
    exit 1
  fi
fi

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

if rg -n -i 'grain_run_vector|runvector|qrdecode\b|qr_decode(_gr1)?\b|coseverify|cose_verify|dagcbor|dag_cbor|dagcbor_validate|protocolrunner|executeoperation|execute_operation|uniffi\.grain_client_core' examples >/dev/null; then
  echo "SDK_SCANNER_ERR_RAW_PROTOCOL_API: scanner examples must use public workflow SDK APIs only" >&2
  exit 1
fi

cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift run --package-path examples/ios-scanner --scratch-path "$TMP_DIR/swift" GrainIOSScannerSmoke

GRADLE_ARGS=()
if [[ "${SDK_KOTLIN_GRADLE_OFFLINE:-0}" == "1" ]]; then
  GRADLE_ARGS+=(--offline)
fi

sdk/kotlin/gradlew \
  -p examples/android-scanner \
  --project-cache-dir "$TMP_DIR/gradle-cache" \
  --no-daemon \
  -Dgrain.kotlin.buildDir="$TMP_DIR/android-build" \
  "${GRADLE_ARGS[@]}" \
  check
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
