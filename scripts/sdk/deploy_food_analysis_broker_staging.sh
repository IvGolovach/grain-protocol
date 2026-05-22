#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BROKER_DIR="$ROOT/services/food-analysis-broker"

cd "$ROOT"

npm --prefix services/food-analysis-broker test
(
  cd "$BROKER_DIR"
  npm exec -- wrangler d1 migrations apply MEALMARK_DB --env staging --remote
  npm exec -- wrangler deploy --env staging
)

scripts/sdk/check_food_analysis_broker_staging.sh --require-cloudflare
