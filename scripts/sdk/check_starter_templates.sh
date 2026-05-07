#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

owned_paths=(
  "scripts/sdk/check_starter_templates.sh"
  "templates/ios-starter"
  "templates/android-starter"
  "templates/web-wasm-starter"
)

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all -- "${owned_paths[@]}")"

required_files=(
  "templates/ios-starter/README.md"
  "templates/ios-starter/Package.swift"
  "templates/android-starter/README.md"
  "templates/android-starter/build.gradle.kts"
  "templates/android-starter/settings.gradle.kts"
  "templates/web-wasm-starter/README.md"
  "templates/web-wasm-starter/package.json"
  "templates/web-wasm-starter/src/main.mjs"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "SDK_STARTER_ERR_MISSING_FILE: $file" >&2
    exit 1
  fi
done

required_path_terms=(
  "trust"
  "scan"
  "paste"
  "preview"
  "accept"
  "persist"
  "restore"
  "list"
  "export"
)

for dir in templates/ios-starter templates/android-starter templates/web-wasm-starter; do
  for term in "${required_path_terms[@]}"; do
    if ! python3 tools/ci/find_regex_match.py --ignore-case "$term" "$dir" >/dev/null; then
      echo "SDK_STARTER_ERR_PATH_TERM_MISSING: $dir requires '$term'" >&2
      exit 1
    fi
  done
done

for dir in templates/ios-starter templates/android-starter templates/web-wasm-starter; do
  if python3 tools/ci/find_regex_match.py --ignore-case 'App Store|Play Store|PWA|Progressive Web App|publish(ed|ing)? to' "$dir" >/dev/null; then
    echo "SDK_STARTER_ERR_PUBLICATION_CLAIM: $dir must not claim store/PWA publication readiness" >&2
    exit 1
  fi
done

raw_api_pattern='GrainClientFFI|grain_client_core|uniffi\.grain_client_core|grain_run_vector\b|runvector\b|qrdecode\b|qr_decode(_gr1)?\b|coseverify\b|cose_verify\b|dagcbor\b|dag_cbor\b|dagcbor_validate\b|protocolrunner\b|executeoperation\b|execute_operation\b'
for dir in templates/ios-starter templates/android-starter templates/web-wasm-starter; do
  if python3 tools/ci/find_regex_match.py --ignore-case "$raw_api_pattern" "$dir" >/dev/null; then
    echo "SDK_STARTER_ERR_RAW_PROTOCOL_API: $dir must use public SDK/example APIs only" >&2
    exit 1
  fi
done

if command -v swift >/dev/null 2>&1; then
  swift package dump-package --package-path templates/ios-starter >/dev/null
else
  echo "starter templates check: swift not found; skipped iOS package parse" >&2
fi

if command -v node >/dev/null 2>&1; then
  node --check templates/web-wasm-starter/src/main.mjs
  npm --prefix templates/web-wasm-starter run check
else
  echo "starter templates check: node not found; skipped web syntax check" >&2
fi

if command -v java >/dev/null 2>&1 && [[ -x sdk/kotlin/gradlew ]]; then
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-android-starter.XXXXXX")"
  trap 'rm -rf "$TMP_DIR"' EXIT
  sdk/kotlin/gradlew \
    -p templates/android-starter \
    --project-cache-dir "$TMP_DIR/gradle-cache" \
    --no-daemon \
    -Dgrain.kotlin.buildDir="$TMP_DIR/android-starter-build" \
    tasks >/dev/null
else
  echo "starter templates check: java/gradlew not found; skipped Android Gradle parse" >&2
fi

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all -- "${owned_paths[@]}")"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_STARTER_ERR_DIRTY_OWNED_PATHS: starter templates check changed owned paths" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "starter templates check: PASS"
