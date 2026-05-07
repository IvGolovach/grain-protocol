#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
OUT_DIR="artifacts/sdk-registry-dry-runs/$COMMIT_SHA"

usage() {
  cat <<'EOF'
Usage: scripts/sdk/check_registry_dry_runs.sh [options]

Runs non-publishing SDK distribution dry-runs and writes metadata under
artifacts/sdk-registry-dry-runs/<commit>/.

Options:
  --out-dir <path>  Output directory inside the repository
  -h, --help        Show this help

This command never uses registry credentials and never publishes to npm,
Maven Central, App Store Connect, Play Store, or any package registry.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "REGISTRY_DRY_RUN_ERR_UNKNOWN_ARG: $1" >&2
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
      echo "REGISTRY_DRY_RUN_ERR_OUT_DIR_OUTSIDE_REPO: out-dir must be inside repository root" >&2
      exit 1
      ;;
  esac
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

json_quote() {
  python3 -c 'import json, sys; print(json.dumps(sys.argv[1]))' "$1"
}

run_or_mark() {
  local output="$1"
  shift
  "$@" >"$OUT_DIR_ABS/$output" 2>&1
}

OUT_DIR_ABS="$(resolve_out_dir "$OUT_DIR")"
mkdir -p "$OUT_DIR_ABS"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/grain-registry-dry-runs.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

SWIFTPM_STATUS="unsupported_prereq"
SWIFTPM_REASON="swift command not found"
SWIFTPM_OUTPUT="swiftpm-package-describe.json"
if have_cmd swift; then
  swift package --package-path sdk/swift describe --type json >"$OUT_DIR_ABS/$SWIFTPM_OUTPUT"
  SWIFTPM_STATUS="pass"
  SWIFTPM_REASON=""
else
  printf '%s\n' "$SWIFTPM_REASON" >"$OUT_DIR_ABS/$SWIFTPM_OUTPUT"
fi

MAVEN_STATUS="unsupported_prereq"
MAVEN_REASON="java command or Kotlin Gradle wrapper not available"
MAVEN_OUTPUT="maven-local-publish-dry-run.txt"
if have_cmd java && [[ -x sdk/kotlin/gradlew ]]; then
  if run_or_mark "$MAVEN_OUTPUT" \
    sdk/kotlin/gradlew \
      -p sdk/kotlin \
      --project-cache-dir "$TMP_DIR/kotlin-project-cache" \
      --no-daemon \
      -Dgrain.kotlin.buildDir="$TMP_DIR/kotlin-build" \
      publishToMavenLocal \
      --dry-run; then
    MAVEN_STATUS="pass"
    MAVEN_REASON=""
  elif grep -q "Task 'publishToMavenLocal' not found" "$OUT_DIR_ABS/$MAVEN_OUTPUT"; then
    MAVEN_STATUS="unsupported_channel"
    MAVEN_REASON="Kotlin package has no publishToMavenLocal Gradle task"
  else
    echo "REGISTRY_DRY_RUN_ERR_MAVEN_LOCAL_DRY_RUN_FAILED" >&2
    cat "$OUT_DIR_ABS/$MAVEN_OUTPUT" >&2
    exit 1
  fi
else
  printf '%s\n' "$MAVEN_REASON" >"$OUT_DIR_ABS/$MAVEN_OUTPUT"
fi

NPM_STATUS="unsupported_prereq"
NPM_REASON="npm command not found"
NPM_OUTPUT="npm-pack-dry-run.json"
if have_cmd npm; then
  (cd sdk/wasm && npm pack --dry-run --json) >"$OUT_DIR_ABS/$NPM_OUTPUT"
  NPM_STATUS="pass"
  NPM_REASON=""
else
  printf '%s\n' "$NPM_REASON" >"$OUT_DIR_ABS/$NPM_OUTPUT"
fi

METADATA="$OUT_DIR_ABS/registry-dry-runs.json"
{
  printf '{\n'
  printf '  "schema": "grain.sdk.registry_dry_run.v1",\n'
  printf '  "commit": %s,\n' "$(json_quote "$COMMIT_SHA")"
  if [[ -n "$BEFORE_STATUS" ]]; then
    printf '  "dirty": true,\n'
  else
    printf '  "dirty": false,\n'
  fi
  printf '  "credentials": "not_required",\n'
  printf '  "channels": [\n'
  printf '    {\n'
  printf '      "name": "swiftpm",\n'
  printf '      "ecosystem": "swiftpm",\n'
  printf '      "mode": "dry-run-only",\n'
  printf '      "publication": "none",\n'
  printf '      "store_publication": "none",\n'
  printf '      "credentials": "not_required",\n'
  printf '      "status": %s,\n' "$(json_quote "$SWIFTPM_STATUS")"
  if [[ -n "$SWIFTPM_REASON" ]]; then
    printf '      "reason": %s,\n' "$(json_quote "$SWIFTPM_REASON")"
  fi
  printf '      "command": ["swift", "package", "--package-path", "sdk/swift", "describe", "--type", "json"],\n'
  printf '      "output": %s\n' "$(json_quote "$SWIFTPM_OUTPUT")"
  printf '    },\n'
  printf '    {\n'
  printf '      "name": "maven-local",\n'
  printf '      "ecosystem": "maven-local",\n'
  printf '      "mode": "dry-run-only",\n'
  printf '      "publication": "local-dry-run",\n'
  printf '      "store_publication": "none",\n'
  printf '      "credentials": "not_required",\n'
  printf '      "status": %s,\n' "$(json_quote "$MAVEN_STATUS")"
  if [[ -n "$MAVEN_REASON" ]]; then
    printf '      "reason": %s,\n' "$(json_quote "$MAVEN_REASON")"
  fi
  printf '      "command": ["sdk/kotlin/gradlew", "-p", "sdk/kotlin", "publishToMavenLocal", "--dry-run"],\n'
  printf '      "output": %s\n' "$(json_quote "$MAVEN_OUTPUT")"
  printf '    },\n'
  printf '    {\n'
  printf '      "name": "npm-pack",\n'
  printf '      "ecosystem": "npm-pack",\n'
  printf '      "mode": "dry-run-only",\n'
  printf '      "publication": "pack-only",\n'
  printf '      "store_publication": "none",\n'
  printf '      "credentials": "not_required",\n'
  printf '      "status": %s,\n' "$(json_quote "$NPM_STATUS")"
  if [[ -n "$NPM_REASON" ]]; then
    printf '      "reason": %s,\n' "$(json_quote "$NPM_REASON")"
  fi
  printf '      "command": ["npm", "pack", "--dry-run", "--json"],\n'
  printf '      "output": %s\n' "$(json_quote "$NPM_OUTPUT")"
  printf '    }\n'
  printf '  ]\n'
  printf '}\n'
} >"$METADATA"

python3 tools/ci/check_registry_dry_run_metadata.py \
  --metadata "$METADATA" \
  --expected-commit "$COMMIT_SHA"

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "REGISTRY_DRY_RUN_ERR_DIRTY_WORKTREE_CHANGED: registry dry-run changed non-ignored git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

printf 'registry dry-runs: PASS\n'
printf 'metadata: %s\n' "$METADATA"
