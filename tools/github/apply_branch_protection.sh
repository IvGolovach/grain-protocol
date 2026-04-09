#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <owner/repo>" >&2
  exit 1
fi

REPO="$1"
PROTECTION_PROFILE="${PROTECTION_PROFILE:-autonomous}"
RULESET_NAME="${RULESET_NAME:-main protection}"

case "$PROTECTION_PROFILE" in
  autonomous)
    REQUIRED_APPROVING_REVIEW_COUNT=0
    REQUIRE_CODE_OWNER_REVIEWS=false
    ;;
  reviewed)
    REQUIRED_APPROVING_REVIEW_COUNT=1
    REQUIRE_CODE_OWNER_REVIEWS=true
    ;;
  *)
    echo "unknown PROTECTION_PROFILE: $PROTECTION_PROFILE (expected: autonomous|reviewed)" >&2
    exit 2
    ;;
esac

mapfile -t existing_ruleset_ids < <(
  GH_PAGER=cat gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "repos/${REPO}/rulesets" \
    --jq ".[] | select(.name == \"${RULESET_NAME}\" and .target == \"branch\") | .id"
)

if [[ "${#existing_ruleset_ids[@]}" -gt 1 ]]; then
  echo "multiple branch rulesets named '${RULESET_NAME}' found for ${REPO}" >&2
  exit 3
fi

existing_ruleset_id="${existing_ruleset_ids[0]:-}"

payload_file="$(mktemp)"
cat >"${payload_file}" <<JSON
{
  "name": "${RULESET_NAME}",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["~DEFAULT_BRANCH"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": ${REQUIRED_APPROVING_REVIEW_COUNT},
        "dismiss_stale_reviews_on_push": true,
        "required_reviewers": [],
        "require_code_owner_review": ${REQUIRE_CODE_OWNER_REVIEWS},
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["merge", "squash", "rebase"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          {"context": "python-tooling"},
          {"context": "rust-core"},
          {"context": "evidence-bundle"},
          {"context": "capid-csprng-audit"}
        ]
      }
    }
  ]
}
JSON

if [[ -n "${existing_ruleset_id}" ]]; then
  gh api \
    -X PUT \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "repos/${REPO}/rulesets/${existing_ruleset_id}" \
    --input "${payload_file}" >/dev/null
else
  gh api \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2026-03-10" \
    "repos/${REPO}/rulesets" \
    --input "${payload_file}" >/dev/null
fi

rm -f "${payload_file}"
echo "Ruleset applied for ${REPO}: ${RULESET_NAME} (${PROTECTION_PROFILE})"
