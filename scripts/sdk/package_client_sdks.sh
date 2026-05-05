#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
OUT_DIR="artifacts/sdk-release/$COMMIT_SHA"
RUN_VERIFY=1
ALLOW_DIRTY=0
DIRTY_STATUS=""

usage() {
  cat <<'EOF'
Usage: scripts/sdk/package_client_sdks.sh [options]

Builds local SDK release artifacts under artifacts/sdk-release/<commit>/.

Options:
  --out-dir <path>  Output directory inside the repository
  --skip-verify     Do not run scripts/sdk/verify_all_sdks.sh --strict first
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
  tar -czf "$OUT_DIR_ABS/$artifact" "$@"
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
  sdk/workflows \
  sdk/generated \
  docs/human/sdk/version-matrix.md \
  docs/llm/SDK_GENERATED_VERIFICATION.md

while IFS= read -r artifact_path; do
  assert_archive_clean "$(basename "$artifact_path")"
done < <(find "$OUT_DIR_ABS" -maxdepth 1 -type f -name '*.tar.gz' | sort)

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "SDK_PACKAGE_ERR_SHA256_TOOL_MISSING: expected shasum or sha256sum" >&2
    exit 1
  fi
}

MANIFEST="$OUT_DIR_ABS/manifest.json"
SUMS="$OUT_DIR_ABS/SHA256SUMS"
: > "$SUMS"
{
  printf '{\n'
  printf '  "commit": "%s",\n' "$COMMIT_SHA"
  printf '  "created_at": "%s",\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  if [[ -n "$DIRTY_STATUS" ]]; then
    printf '  "dirty": true,\n'
  else
    printf '  "dirty": false,\n'
  fi
  if [[ "$RUN_VERIFY" -eq 1 ]]; then
    printf '  "verification": "strict",\n'
  else
    printf '  "verification": "skipped",\n'
  fi
  printf '  "workflow_contract": "client_workflow_v1",\n'
  printf '  "artifacts": [\n'
  first=1
  while IFS= read -r artifact; do
    [[ -n "$artifact" ]] || continue
    if [[ "$first" -eq 0 ]]; then
      printf ',\n'
    fi
    first=0
    checksum="$(sha256_file "$OUT_DIR_ABS/$artifact")"
    size="$(wc -c < "$OUT_DIR_ABS/$artifact" | tr -d '[:space:]')"
    printf '%s  %s\n' "$checksum" "$artifact" >> "$SUMS"
    printf '    {"file": "%s", "sha256": "%s", "bytes": %s}' "$artifact" "$checksum" "$size"
  done < <(find "$OUT_DIR_ABS" -maxdepth 1 -type f -name '*.tar.gz' -exec basename {} \; | sort)
  printf '\n  ]\n'
  printf '}\n'
} > "$MANIFEST"

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
