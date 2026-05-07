#!/usr/bin/env bash
set -euo pipefail
export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
OUT_DIR="artifacts/sdk-release/$COMMIT_SHA"
RUN_VERIFY=1
ALLOW_DIRTY=0
DIRTY_STATUS=""
VERIFIED_BY=""

usage() {
  cat <<'EOF'
Usage: scripts/sdk/package_client_sdks.sh [options]

Builds local SDK release artifacts under artifacts/sdk-release/<commit>/.

Options:
  --out-dir <path>  Output directory inside the repository
  --skip-verify     Do not run scripts/sdk/verify_all_sdks.sh --strict first
  --verified-by <id> Record an upstream strict SDK gate when used with --skip-verify
  --allow-dirty     Permit packaging from a dirty worktree
  -h, --help        Show this help

Default mode requires a clean worktree and strict SDK verification before
packaging. Output under artifacts/ is ignored and must not be committed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --skip-verify)
      RUN_VERIFY=0
      shift
      ;;
    --verified-by)
      if [[ $# -lt 2 ]]; then
        echo "SDK_PACKAGE_ERR_ARG_MISSING: --verified-by requires a value" >&2
        exit 2
      fi
      VERIFIED_BY="$2"
      shift 2
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "SDK_PACKAGE_ERR_UNKNOWN_ARG: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$VERIFIED_BY" && "$RUN_VERIFY" -eq 1 ]]; then
  echo "SDK_PACKAGE_ERR_VERIFIED_BY_WITHOUT_SKIP: --verified-by requires --skip-verify" >&2
  exit 2
fi

resolve_out_dir() {
  local raw="$1"
  local candidate
  if [[ "$raw" = /* ]]; then
    candidate="$raw"
  else
    candidate="$ROOT/${raw#./}"
  fi

  local resolved
  resolved="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$candidate")"
  case "$resolved" in
    "$ROOT"|"$ROOT"/*)
      printf '%s\n' "$resolved"
      ;;
    *)
      echo "SDK_PACKAGE_ERR_OUT_DIR_OUTSIDE_REPO: out-dir must be inside repository root" >&2
      exit 1
      ;;
  esac
}

OUT_DIR_ABS="$(resolve_out_dir "$OUT_DIR")"

DIRTY_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$ALLOW_DIRTY" -ne 1 && -n "$DIRTY_STATUS" ]]; then
  echo "SDK_PACKAGE_ERR_DIRTY_TREE: commit or discard local changes before packaging" >&2
  exit 1
fi

mkdir -p "$OUT_DIR_ABS"

if [[ "$RUN_VERIFY" -eq 1 ]]; then
  scripts/sdk/verify_all_sdks.sh --strict --out-dir "$OUT_DIR_ABS/verify"
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/grain-sdk-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

scripts/sdk/generate_client_bindings.sh --out-dir "$STAGING/generated-bindings" --language all

tar_gz() {
  local artifact="$1"
  shift
  tar --exclude '._*' --exclude '.DS_Store' -czf "$OUT_DIR_ABS/$artifact" "$@"
}

assert_archive_clean() {
  local artifact="$1"
  if tar -tzf "$OUT_DIR_ABS/$artifact" | grep -E '(^|/)(node_modules|dist|build|\.build|\.gradle|\.kotlin|target|pkg)/|\.wasm$' >/dev/null; then
    echo "SDK_PACKAGE_ERR_FORBIDDEN_ARCHIVE_ENTRY: $artifact contains build/cache output" >&2
    tar -tzf "$OUT_DIR_ABS/$artifact" | grep -E '(^|/)(node_modules|dist|build|\.build|\.gradle|\.kotlin|target|pkg)/|\.wasm$' >&2 || true
    exit 1
  fi
}

tar_gz "grain-generated-bindings-$COMMIT_SHA.tar.gz" -C "$STAGING" generated-bindings
tar_gz "grain-swift-client-$COMMIT_SHA.tar.gz" \
  --exclude 'sdk/swift/.build' \
  -C "$ROOT" \
  sdk/swift
tar_gz "grain-kotlin-client-$COMMIT_SHA.tar.gz" \
  --exclude 'sdk/kotlin/.gradle' \
  --exclude 'sdk/kotlin/.kotlin' \
  --exclude 'sdk/kotlin/build' \
  -C "$ROOT" \
  sdk/kotlin
tar_gz "grain-wasm-client-$COMMIT_SHA.tar.gz" \
  --exclude 'sdk/wasm/node_modules' \
  --exclude 'sdk/wasm/dist' \
  --exclude 'sdk/wasm/pkg' \
  --exclude 'sdk/wasm/*.wasm' \
  --exclude 'core/rust/grain-client-wasm/target' \
  -C "$ROOT" \
  sdk/wasm \
  core/rust/grain-client-wasm
tar_gz "grain-sdk-workflow-contract-$COMMIT_SHA.tar.gz" \
  -C "$ROOT" \
  sdk/api \
  sdk/custody \
  sdk/workflows \
  sdk/trust \
  sdk/generated \
  docs/human/sdk/version-matrix.md \
  docs/human/sdk/security-review.md \
  docs/human/sdk/release-train.md \
  docs/llm/SDK_GENERATED_VERIFICATION.md
tar_gz "grain-starter-templates-$COMMIT_SHA.tar.gz" \
  --exclude 'templates/ios-starter/.build' \
  --exclude 'templates/android-starter/.gradle' \
  --exclude 'templates/android-starter/.kotlin' \
  --exclude 'templates/android-starter/build' \
  --exclude 'templates/web-wasm-starter/node_modules' \
  --exclude 'templates/web-wasm-starter/dist' \
  --exclude 'examples/ios-scanner/.build' \
  --exclude 'examples/android-scanner/.gradle' \
  --exclude 'examples/android-scanner/.kotlin' \
  --exclude 'examples/android-scanner/build' \
  --exclude 'examples/wasm-scanner/node_modules' \
  --exclude 'examples/wasm-scanner/dist' \
  -C "$ROOT" \
  templates \
  examples/ios-scanner \
  examples/android-scanner \
  examples/wasm-scanner \
  scripts/sdk/check_starter_templates.sh \
  docs/human/sdk/start-here.md \
  docs/human/sdk/scan-quickstart.md

while IFS= read -r artifact_path; do
  assert_archive_clean "$(basename "$artifact_path")"
done < <(find "$OUT_DIR_ABS" -maxdepth 1 -type f -name '*.tar.gz' | sort)

MANIFEST="$OUT_DIR_ABS/manifest.json"
SUMS="$OUT_DIR_ABS/SHA256SUMS"
if [[ -n "$DIRTY_STATUS" ]]; then
  DIRTY_FLAG="true"
else
  DIRTY_FLAG="false"
fi

if [[ "$RUN_VERIFY" -eq 1 ]]; then
  VERIFICATION_MODE="strict"
  VERIFICATION_SOURCE="package_client_sdks.sh"
elif [[ -n "$VERIFIED_BY" ]]; then
  VERIFICATION_MODE="strict-upstream"
  VERIFICATION_SOURCE="$VERIFIED_BY"
else
  VERIFICATION_MODE="skipped"
  VERIFICATION_SOURCE="--skip-verify"
fi

python3 tools/ci/build_sdk_release_metadata.py \
  --out-dir "$OUT_DIR_ABS" \
  --commit "$COMMIT_SHA" \
  --dirty "$DIRTY_FLAG" \
  --verification-mode "$VERIFICATION_MODE" \
  --verification-source "$VERIFICATION_SOURCE"

check_args=(
  --out-dir "$OUT_DIR_ABS"
  --expected-commit "$COMMIT_SHA"
)
if [[ "$DIRTY_FLAG" == "false" ]]; then
  check_args+=(--require-clean)
fi
if [[ "$VERIFICATION_MODE" != "skipped" ]]; then
  check_args+=(--require-strict)
fi
python3 tools/ci/check_sdk_release_package.py "${check_args[@]}"

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$DIRTY_STATUS" ]]; then
  echo "SDK_PACKAGE_ERR_DIRTY_WORKTREE_CHANGED: packaging changed non-ignored git status" >&2
  diff <(printf '%s\n' "$DIRTY_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

printf 'sdk package: PASS\n'
printf 'artifacts: %s\n' "$OUT_DIR_ABS"
printf 'manifest: %s\n' "$MANIFEST"
printf 'sha256sums: %s\n' "$SUMS"
printf 'sbom: %s\n' "$OUT_DIR_ABS/sbom.spdx.json"
