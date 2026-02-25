#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

REGISTRY="${1:-ghcr.io/${GITHUB_REPOSITORY_OWNER:-ivgolovach}}"
VERSION_TAG="${2:-stable}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
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
