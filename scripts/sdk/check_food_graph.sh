#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$ROOT"

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"

npm --prefix core/ts/grain-sdk-ai run test:food-graph
python3 tools/ci/check_sdk_no_network.py
python3 tools/ci/check_sdk_ai_boundary.py
swift run --package-path sdk/swift GrainFoodGraphSmoke

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_FOOD_GRAPH_ERR_DIRTY_WORKTREE: Food Graph check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

printf 'Food Graph check: PASS\n'
