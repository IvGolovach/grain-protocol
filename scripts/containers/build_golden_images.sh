#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

REGISTRY="${1:-${GOLDEN_IMAGE_REGISTRY:-}}"
VERSION_TAG="${2:-stable}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

if [[ -z "$REGISTRY" ]]; then
  if [[ -n "${GITHUB_REPOSITORY_OWNER:-}" ]]; then
    REGISTRY="ghcr.io/${GITHUB_REPOSITORY_OWNER}"
  else
    echo "usage: $0 <registry> [version-tag]" >&2
    echo "set GOLDEN_IMAGE_REGISTRY or pass ghcr.io/<owner> explicitly" >&2
    exit 1
  fi
fi

docker buildx build \
  --platform "$PLATFORMS" \
  --file docker/grain-runner.Dockerfile \
  --tag "${REGISTRY}/grain-runner:${VERSION_TAG}" \
  --push \
  .

docker buildx build \
  --platform "$PLATFORMS" \
  --file docker/grain-certify.Dockerfile \
  --tag "${REGISTRY}/grain-certify:${VERSION_TAG}" \
  --push \
  .

echo "golden images published:"
echo "- ${REGISTRY}/grain-runner:${VERSION_TAG}"
echo "- ${REGISTRY}/grain-certify:${VERSION_TAG}"
