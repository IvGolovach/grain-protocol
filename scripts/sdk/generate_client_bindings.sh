#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v cargo >/dev/null 2>&1; then
  echo "SDK_BINDGEN_ERR_CARGO_MISSING: cargo is required" >&2
  exit 1
fi

OUT_DIR="artifacts/sdk/generated-bindings"
LANGUAGE="all"
PROFILE="debug"

usage() {
  cat <<'EOF'
Usage:
  scripts/sdk/generate_client_bindings.sh [--out-dir <path>] [--language swift|kotlin|all]

Generate UniFFI client bindings from the Rust client-core library into an
ignored or caller-provided output directory. This script must not write into the
tracked SDK package trees.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      if [[ $# -lt 2 ]]; then
        echo "SDK_BINDGEN_ERR_ARG_MISSING: --out-dir requires a value" >&2
        exit 2
      fi
      OUT_DIR="$2"
      shift 2
      ;;
    --language)
      if [[ $# -lt 2 ]]; then
        echo "SDK_BINDGEN_ERR_ARG_MISSING: --language requires a value" >&2
        exit 2
      fi
      LANGUAGE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$LANGUAGE" in
  swift|kotlin|all) ;;
  *)
    echo "SDK_BINDGEN_ERR_LANGUAGE: expected swift, kotlin, or all" >&2
    exit 2
    ;;
esac

if [[ "$OUT_DIR" != /* ]]; then
  OUT_DIR="$ROOT/${OUT_DIR#./}"
fi

case "$(uname -s)" in
  Darwin) LIB_NAME="libgrain_client_core.dylib" ;;
  Linux) LIB_NAME="libgrain_client_core.so" ;;
  MINGW*|MSYS*|CYGWIN*) LIB_NAME="grain_client_core.dll" ;;
  *)
    echo "SDK_BINDGEN_ERR_PLATFORM: unsupported host platform $(uname -s)" >&2
    exit 1
    ;;
esac

LIB_PATH="$ROOT/core/rust/target/$PROFILE/$LIB_NAME"

cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core

if [[ ! -f "$LIB_PATH" ]]; then
  echo "SDK_BINDGEN_ERR_LIBRARY_MISSING: expected $LIB_PATH" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

generate_language() {
  local language="$1"
  local language_out="$OUT_DIR/$language"
  rm -rf "$language_out"
  mkdir -p "$language_out"
  (
    cd core/rust
    cargo run -p uniffi-bindgen -- \
      generate \
      --library "$LIB_PATH" \
      --no-format \
      --language "$language" \
      --out-dir "$language_out"
  )
}

if [[ "$LANGUAGE" == "all" || "$LANGUAGE" == "swift" ]]; then
  generate_language swift
fi

if [[ "$LANGUAGE" == "all" || "$LANGUAGE" == "kotlin" ]]; then
  generate_language kotlin
fi

echo "sdk binding generation: PASS ($LANGUAGE -> $OUT_DIR)"
