#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-starter-templates.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

owned_paths=(
  "scripts/sdk/check_starter_templates.sh"
  "templates/ios-starter"
  "templates/ios-food-wallet-starter"
  "templates/android-starter"
  "templates/android-food-wallet-starter"
  "templates/web-wasm-starter"
)

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all -- "${owned_paths[@]}")"

required_files=(
  "templates/ios-starter/README.md"
  "templates/ios-starter/Package.swift"
  "templates/ios-food-wallet-starter/README.md"
  "templates/android-starter/README.md"
  "templates/android-starter/build.gradle.kts"
  "templates/android-starter/settings.gradle.kts"
  "templates/android-food-wallet-starter/README.md"
  "templates/android-food-wallet-starter/build.gradle.kts"
  "templates/android-food-wallet-starter/settings.gradle.kts"
  "templates/android-food-wallet-starter/src/main/kotlin/dev/grain/templates/androidfoodwallet/AndroidFoodWalletStarter.kt"
  "templates/android-food-wallet-starter/src/test/kotlin/dev/grain/templates/androidfoodwallet/AndroidFoodWalletStarterSmoke.kt"
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

food_wallet_path_terms=(
  "food"
  "wallet"
  "estimate"
  "draft"
  "confirm"
  "safe summary"
  "raw photos"
)

for dir in templates/ios-food-wallet-starter templates/android-food-wallet-starter; do
  for term in "${food_wallet_path_terms[@]}"; do
    if ! python3 tools/ci/find_regex_match.py --ignore-case "$term" "$dir" >/dev/null; then
      echo "SDK_STARTER_ERR_FOOD_WALLET_TERM_MISSING: $dir requires '$term'" >&2
      exit 1
    fi
  done
done

for dir in templates/ios-starter templates/ios-food-wallet-starter templates/android-starter templates/android-food-wallet-starter templates/web-wasm-starter; do
  if python3 tools/ci/find_regex_match.py --ignore-case 'App Store|Play Store|PWA|Progressive Web App|publish(ed|ing)? to' "$dir" >/dev/null; then
    echo "SDK_STARTER_ERR_PUBLICATION_CLAIM: $dir must not claim store/PWA publication readiness" >&2
    exit 1
  fi
done

raw_api_pattern='GrainClientFFI|grain_client_core|uniffi\.grain_client_core|grain_run_vector\b|runvector\b|qrdecode\b|qr_decode(_gr1)?\b|coseverify\b|cose_verify\b|dagcbor\b|dag_cbor\b|dagcbor_validate\b|protocolrunner\b|executeoperation\b|execute_operation\b'
raw_api_scan_paths=(
  "templates/ios-starter/Sources/GrainIOSStarterCore"
  "templates/ios-starter/README.md"
  "templates/ios-food-wallet-starter/README.md"
  "templates/android-starter/src/main"
  "templates/android-starter/README.md"
  "templates/android-food-wallet-starter/src/main"
  "templates/android-food-wallet-starter/README.md"
  "templates/web-wasm-starter/src"
  "templates/web-wasm-starter/README.md"
)
for path in "${raw_api_scan_paths[@]}"; do
  if python3 tools/ci/find_regex_match.py --ignore-case "$raw_api_pattern" "$path" >/dev/null; then
    echo "SDK_STARTER_ERR_RAW_PROTOCOL_API: $path must use public SDK/example APIs only" >&2
    exit 1
  fi
done

if command -v swift >/dev/null 2>&1; then
  swift package dump-package --package-path templates/ios-starter >/dev/null
  env DYLD_LIBRARY_PATH="$ROOT/core/rust/target/debug${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}" \
    swift run \
    --package-path templates/ios-starter \
    --scratch-path "$TMP_DIR/ios-starter-build" \
    GrainIOSStarterSmoke
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
  RUST_TARGET=""
  if [[ "$(uname -s)" == "Darwin" ]]; then
    HOST_ARCH="$(uname -m)"
    JVM_ARCH="$(java -XshowSettings:properties -version 2>&1 | awk -F= '/os.arch/ {gsub(/[[:space:]]/, "", $2); print $2; exit}')"
    if [[ "$HOST_ARCH" == "arm64" && "$JVM_ARCH" == "x86_64" ]]; then
      RUST_TARGET="x86_64-apple-darwin"
    fi
  fi

  if [[ -n "$RUST_TARGET" ]]; then
    if ! command -v rustup >/dev/null 2>&1; then
      echo "SDK_STARTER_ERR_RUSTUP_REQUIRED: rustup is required to build the JVM-matching Rust target" >&2
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

  GRADLE_CMD=(
    sdk/kotlin/gradlew
    -p templates/android-starter
    --project-cache-dir "$TMP_DIR/gradle-cache"
    --no-daemon
    -Dgrain.kotlin.buildDir="$TMP_DIR/android-starter-build"
  )
  if [[ -n "$RUST_DEBUG_LIBRARY" ]]; then
    GRADLE_CMD+=("-Dgrain.kotlin.rustDebugLibrary=$ROOT/$RUST_DEBUG_LIBRARY")
  fi
  GRADLE_CMD+=(check)
  "${GRADLE_CMD[@]}" >/dev/null

  FOOD_WALLET_GRADLE_CMD=(
    sdk/kotlin/gradlew
    -p templates/android-food-wallet-starter
    --project-cache-dir "$TMP_DIR/food-wallet-gradle-cache"
    --no-daemon
    -Dgrain.kotlin.buildDir="$TMP_DIR/android-food-wallet-starter-build"
    check
  )
  "${FOOD_WALLET_GRADLE_CMD[@]}" >/dev/null
  rm -rf templates/android-starter/.gradle templates/android-food-wallet-starter/.gradle
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
