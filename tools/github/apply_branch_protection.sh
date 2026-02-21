#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <owner/repo>" >&2
  exit 1
fi

REPO="$1"

gh api \
  -X PUT \
  -H "Accept: application/vnd.github+json" \
  "repos/${REPO}/branches/main/protection" \
  -f required_status_checks.strict=true \
  -f required_status_checks.contexts[]='python-tooling' \
  -f required_status_checks.contexts[]='rust-core' \
  -f required_status_checks.contexts[]='ts-c01' \
  -f required_status_checks.contexts[]='evidence-bundle' \
  -f enforce_admins=true \
  -f required_pull_request_reviews.dismiss_stale_reviews=true \
  -f required_pull_request_reviews.require_code_owner_reviews=true \
  -f required_pull_request_reviews.required_approving_review_count=1 \
  -f restrictions= \
  -f required_linear_history=true \
  -f allow_force_pushes=false \
  -f allow_deletions=false \
  -f block_creations=false \
  -f required_conversation_resolution=true

echo "Branch protection applied for ${REPO}:main"
