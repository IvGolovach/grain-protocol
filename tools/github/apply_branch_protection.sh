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
  --input <(
    cat <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["python-tooling", "rust-core", "ts-c01", "ts-full", "evidence-bundle"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON
  )

echo "Branch protection applied for ${REPO}:main"
