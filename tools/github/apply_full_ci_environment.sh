#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <owner/repo> [reviewer-login]" >&2
  exit 1
fi

REPO="$1"
REVIEWER_LOGIN="${2:-${REPO%%/*}}"
ENVIRONMENT_NAME="${FULL_CI_ENVIRONMENT:-full-ci}"
export GH_TOKEN="${GH_TOKEN:-$(gh auth token)}"

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2026-03-10" \
  "repos/${REPO}/actions/permissions/fork-pr-contributor-approval" \
  -f approval_policy=all_external_contributors >/dev/null

reviewer_id="$(gh api "users/${REVIEWER_LOGIN}" --jq '.id')"
if [[ -z "${reviewer_id}" || "${reviewer_id}" == "null" ]]; then
  echo "FULL_CI_ENV_APPLY_ERR_REVIEWER: unable to resolve ${REVIEWER_LOGIN}" >&2
  exit 2
fi

jq -n \
  --argjson reviewer_id "${reviewer_id}" \
  '{
    wait_timer: 0,
    prevent_self_review: false,
    reviewers: [{type: "User", id: $reviewer_id}],
    deployment_branch_policy: null
  }' | gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "repos/${REPO}/environments/${ENVIRONMENT_NAME}" \
    --input - >/dev/null

python3 tools/ci/check_full_ci_environment.py \
  --repo "${REPO}" \
  --environment "${ENVIRONMENT_NAME}" \
  --expected-reviewer "${REVIEWER_LOGIN}" \
  --check-owner-only-settings

echo "Full CI settings applied for ${REPO}: ${ENVIRONMENT_NAME} (${REVIEWER_LOGIN})"
