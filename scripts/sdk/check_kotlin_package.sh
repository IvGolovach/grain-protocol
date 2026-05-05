#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-kotlin-check.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ "$(uname -s)" == "Darwin" ]]; then
  HOST_ARCH="$(uname -m)"
  JVM_ARCH="$(java -XshowSettings:properties -version 2>&1 | awk -F= '/os.arch/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')"
  if [[ "$HOST_ARCH" == "arm64" && "$JVM_ARCH" == "x86_64" ]]; then
    echo "SDK_KOTLIN_ERR_JVM_ARCH_MISMATCH: arm64 Rust dylib requires an arm64 JVM; set JAVA_HOME to an arm64 JDK" >&2
    exit 1
  fi
fi

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
GENERATED_PATHS=(
  "sdk/kotlin/src/main/kotlin/uniffi/grain_client_core/grain_client_core.kt"
)
BEFORE_GENERATED="$(git hash-object "${GENERATED_PATHS[@]}")"

scripts/sdk/sync_kotlin_bindings.sh
AFTER_GENERATED="$(git hash-object "${GENERATED_PATHS[@]}")"
if [[ "$AFTER_GENERATED" != "$BEFORE_GENERATED" ]]; then
  echo "SDK_KOTLIN_ERR_GENERATED_DRIFT: run scripts/sdk/sync_kotlin_bindings.sh and commit the result" >&2
  exit 1
fi

has_raw_protocol_api() {
  local pattern='qrDecode|coseVerify|dagCbor|runVector|protocolRunner'
  python3 tools/ci/find_regex_match.py "$pattern" sdk/kotlin/src/main/kotlin/dev/grain >/dev/null
}

if has_raw_protocol_api; then
  echo "SDK_KOTLIN_ERR_RAW_PROTOCOL_API: Kotlin public wrapper must expose workflow APIs only" >&2
  exit 1
else
  RAW_API_STATUS=$?
  if [[ "$RAW_API_STATUS" -ne 1 ]]; then
    exit "$RAW_API_STATUS"
  fi
fi

has_secret_logging() {
  local pattern='(println|print|Log\.[a-z]+|Timber\.[a-z]+|Logger\.[a-z]+)\s*\([^)]*(snapshotB64|bundleB64|trustPubB64)'
  python3 tools/ci/find_regex_match.py --ignore-case "$pattern" sdk/kotlin/src/main/kotlin/dev/grain >/dev/null
}

if has_secret_logging; then
  echo "SDK_KOTLIN_ERR_SECRET_LOGGING: Kotlin SDK must not log snapshot, bundle, or trust material" >&2
  exit 1
else
  SECRET_LOGGING_STATUS=$?
  if [[ "$SECRET_LOGGING_STATUS" -ne 1 ]]; then
    exit "$SECRET_LOGGING_STATUS"
  fi
fi

cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core

GRADLE_ARGS=()
if [[ "${SDK_KOTLIN_GRADLE_OFFLINE:-0}" == "1" ]]; then
  GRADLE_ARGS+=(--offline)
fi

GRADLE_CMD=(
  sdk/kotlin/gradlew
  -p sdk/kotlin
  --project-cache-dir "$TMP_DIR/project-cache"
  --no-daemon
  -Dgrain.kotlin.buildDir="$TMP_DIR/build"
)
if [[ ${#GRADLE_ARGS[@]} -gt 0 ]]; then
  GRADLE_CMD+=("${GRADLE_ARGS[@]}")
fi
GRADLE_CMD+=(check)

"${GRADLE_CMD[@]}"

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_KOTLIN_ERR_DIRTY_WORKTREE: Kotlin package check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "kotlin package check: PASS"
