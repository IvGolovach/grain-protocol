#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

COMMIT_SHA="$(git rev-parse HEAD)"
OUT_DIR="artifacts/sdk-release/$COMMIT_SHA"
LAYOUT_ONLY=1
PACKAGE_ARGS=()
TMP_CONSUMER_PARENT=""

cleanup() {
  if [[ -n "$TMP_CONSUMER_PARENT" ]]; then
    rm -rf "$TMP_CONSUMER_PARENT"
  fi
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: scripts/sdk/release_dry_run.sh [options]

Builds source SDK release artifacts, validates the manifest/SBOM/checksums,
extracts them into an external-consumer layout, checks the compatibility matrix,
and runs registry dry-run metadata checks. Nothing is published.

Options:
  --out-dir <path>          Output directory inside the repository
  --strict-consumer-smoke   Build/smoke local platform starters when prerequisites exist
  --skip-verify            Pass through to package_client_sdks.sh
  --verified-by <id>        Pass through to package_client_sdks.sh
  --allow-dirty            Pass through to package_client_sdks.sh
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    --strict-consumer-smoke)
      LAYOUT_ONLY=0
      shift
      ;;
    --skip-verify|--allow-dirty)
      PACKAGE_ARGS+=("$1")
      shift
      ;;
    --verified-by)
      if [[ $# -lt 2 ]]; then
        echo "SDK_RELEASE_DRY_RUN_ERR_ARG_MISSING: --verified-by requires a value" >&2
        exit 2
      fi
      PACKAGE_ARGS+=("$1" "$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "SDK_RELEASE_DRY_RUN_ERR_UNKNOWN_ARG: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

scripts/sdk/package_client_sdks.sh --out-dir "$OUT_DIR" "${PACKAGE_ARGS[@]}"

check_args=(--out-dir "$OUT_DIR" --expected-commit "$COMMIT_SHA")
if [[ -z "$(git status --porcelain=v1 --untracked-files=all)" ]]; then
  check_args+=(--require-clean)
fi

python3 tools/ci/check_sdk_release_package.py "${check_args[@]}"
python3 tools/ci/check_external_sdk_handoff.py "${check_args[@]}"

TMP_CONSUMER_PARENT="$(mktemp -d "${TMPDIR:-/tmp}/grain-release-dry-run-consumer.XXXXXX")"
TMP_CONSUMER_ROOT="$TMP_CONSUMER_PARENT/consumer"
python3 tools/ci/check_external_consumer_templates.py \
  --out-dir "$OUT_DIR" \
  --expected-commit "$COMMIT_SHA" \
  --consumer-root "$TMP_CONSUMER_ROOT"

consumer_args=(--out-dir "$OUT_DIR" --expected-commit "$COMMIT_SHA")
if [[ "$LAYOUT_ONLY" == "1" ]]; then
  consumer_args+=(--layout-only)
else
  consumer_args+=(--strict)
fi
python3 tools/ci/check_external_release_consumer_smoke.py "${consumer_args[@]}"

python3 tools/ci/check_sdk_compatibility_matrix.py --manifest "$OUT_DIR/manifest.json"
python3 tools/ci/check_npm_release_dry_run.py \
  --vendor-root "$TMP_CONSUMER_ROOT/vendor/grain-sdk" \
  --fixture "$TMP_CONSUMER_ROOT/vendor/grain-sdk/fixtures/external-consumers/npm-sdk" \
  --out-dir "$OUT_DIR/npm-release-dry-run" \
  --build \
  --consumer-smoke
python3 tools/ci/check_public_sdk_api.py
scripts/sdk/check_registry_dry_runs.sh

printf 'sdk release dry-run: PASS\n'
printf 'artifacts: %s\n' "$ROOT/${OUT_DIR#./}"
