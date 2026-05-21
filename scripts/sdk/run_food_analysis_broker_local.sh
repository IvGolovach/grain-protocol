#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

keychain_secret() {
  local service="$1"
  security find-generic-password -s "$service" -w 2>/dev/null || true
}

export HOST="${HOST:-127.0.0.1}"
export PORT="${PORT:-8788}"
export FOOD_SEARCH_LIVE="${FOOD_SEARCH_LIVE:-1}"
export FOOD_SEARCH_TIMEOUT_MS="${FOOD_SEARCH_TIMEOUT_MS:-7000}"
export OPEN_FOOD_FACTS_USER_AGENT="${OPEN_FOOD_FACTS_USER_AGENT:-MealMark/0.1 (https://github.com/IvGolovach/grain-protocol)}"

if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  OPENAI_API_KEY="$(keychain_secret dev.grain.foodwallet.openai_api_key)"
  if [[ -n "$OPENAI_API_KEY" ]]; then
    export OPENAI_API_KEY
  fi
fi

if [[ -z "${FDC_API_KEY:-}" ]]; then
  FDC_API_KEY="$(keychain_secret dev.grain.foodwallet.usda_fdc_api_key)"
  if [[ -n "$FDC_API_KEY" ]]; then
    export FDC_API_KEY
  fi
fi

if [[ "$HOST" != "127.0.0.1" && "$HOST" != "localhost" && "$HOST" != "::1" ]]; then
  if [[ "${ALLOW_LAN_BROKER:-0}" != "1" ]]; then
    echo "Refusing to bind broker to $HOST without ALLOW_LAN_BROKER=1" >&2
    exit 2
  fi
  if [[ -z "${FOOD_BROKER_DEV_TOKEN:-}" ]]; then
    echo "LAN broker mode requires FOOD_BROKER_DEV_TOKEN for bearer-token protection" >&2
    exit 2
  fi
fi

echo "Starting MealMark food broker on http://${HOST}:${PORT}"
echo "Open Food Facts: enabled"
echo "OpenAI analysis key: $(if [[ -n "${OPENAI_API_KEY:-}" ]]; then echo configured; else echo not-configured; fi)"
echo "USDA FDC key: $(if [[ -n "${FDC_API_KEY:-}" ]]; then echo configured; else echo not-configured; fi)"
echo "Broker bearer token: $(if [[ -n "${FOOD_BROKER_DEV_TOKEN:-}" ]]; then echo configured; else echo not-configured; fi)"

exec npm --prefix "$ROOT/services/food-analysis-broker" start
