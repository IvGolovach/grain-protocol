#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BROKER_DIR="$ROOT/services/food-analysis-broker"
STAGING_URL="${MEALMARK_STAGING_BROKER_URL:-https://mealmark-food-analysis-broker-staging.ivan-f7b.workers.dev}"
REQUIRE_CLOUDFLARE=0
REQUIRE_STOREKIT_SECRETS=0

usage() {
  cat <<'EOF'
Usage: scripts/sdk/check_food_analysis_broker_staging.sh [options]

Smoke-check the MealMark staging broker without printing session tokens.

Options:
  --require-cloudflare        Also inspect Wrangler secret/migration state
  --require-storekit-secrets  Fail if App Store Server API secrets are missing
  -h, --help                  Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-cloudflare)
      REQUIRE_CLOUDFLARE=1
      shift
      ;;
    --require-storekit-secrets)
      REQUIRE_STOREKIT_SECRETS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "MEALMARK_STAGING_ERR_UNKNOWN_ARG: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mealmark-staging.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

post_json() {
  local path="$1"
  local body="$2"
  local output="$3"
  curl -sS -o "$output" -w '%{http_code}' \
    -X POST "$STAGING_URL$path" \
    -H 'content-type: application/json' \
    --data "$body"
}

get_json() {
  local path="$1"
  local output="$2"
  shift 2
  curl -sS -o "$output" -w '%{http_code}' "$@" "$STAGING_URL$path"
}

require_status() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  local body_path="$4"
  if [[ "$actual" != "$expected" ]]; then
    echo "MEALMARK_STAGING_ERR_${label}: expected HTTP $expected, got $actual" >&2
    sed -n '1,40p' "$body_path" >&2
    exit 1
  fi
}

require_json_expr() {
  local body_path="$1"
  local label="$2"
  local expr="$3"
  python3 - "$body_path" "$label" "$expr" <<'PY'
import json
import sys

path, label, expr = sys.argv[1:4]
with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

ok = False
if expr == "ok":
    ok = payload.get("ok") is True
elif expr == "has_results":
    ok = payload.get("ok") is True and bool(payload.get("results"))
elif expr == "has_session":
    ok = payload.get("ok") is True and bool(payload.get("session", {}).get("access_token"))
elif expr == "deleted":
    ok = payload.get("ok") is True

if not ok:
    raise SystemExit(f"MEALMARK_STAGING_ERR_{label}: unexpected JSON shape")
PY
}

extract_token() {
  python3 - "$1" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    payload = json.load(handle)
print(payload["session"]["access_token"])
PY
}

if [[ "$REQUIRE_CLOUDFLARE" == "1" ]]; then
  (
    cd "$BROKER_DIR"
    npm exec -- wrangler d1 migrations list MEALMARK_DB --env staging --remote >/dev/null
    secret_json="$(npm exec -- wrangler secret list --env staging)"
    python3 - "$REQUIRE_STOREKIT_SECRETS" "$secret_json" <<'PY'
import json
import sys

require_storekit = sys.argv[1] == "1"
payload = json.loads(sys.argv[2])
names = {entry.get("name") for entry in payload if isinstance(entry, dict)}
required = {
    "OPENAI_API_KEY",
    "FOODDATA_CENTRAL_API_KEY",
    "MEALMARK_SESSION_HMAC_SECRET",
}
if require_storekit:
    required.update({
        "APP_STORE_BUNDLE_ID",
        "APP_STORE_CONNECT_ISSUER_ID",
        "APP_STORE_CONNECT_KEY_ID",
        "APP_STORE_CONNECT_PRIVATE_KEY_P8",
    })
missing = sorted(required - names)
if missing:
    raise SystemExit("MEALMARK_STAGING_ERR_MISSING_SECRETS: " + ", ".join(missing))
PY
  )
fi

health_body="$TMP_DIR/health.json"
health_status="$(get_json /v1/health "$health_body")"
require_status "$health_status" 200 HEALTH "$health_body"
require_json_expr "$health_body" HEALTH ok

search_body="$TMP_DIR/search.json"
search_status="$(post_json /v1/food/search '{"query":"almond butter","limit":3}' "$search_body")"
require_status "$search_status" 200 SEARCH "$search_body"
require_json_expr "$search_body" SEARCH has_results

unauth_body="$TMP_DIR/unauth.json"
unauth_status="$(post_json /v1/food/analyze-photo '{}' "$unauth_body")"
require_status "$unauth_status" 401 PHOTO_REQUIRES_AUTH "$unauth_body"

bootstrap_body="$TMP_DIR/bootstrap.json"
fingerprint="codex-testflight-preflight-$(date +%s)"
bootstrap_status="$(post_json /v1/auth/bootstrap "{\"app_bundle_id\":\"dev.grain.foodwallet\",\"app_version\":\"0.1.0\",\"build_number\":\"preflight\",\"device_fingerprint\":\"$fingerprint\"}" "$bootstrap_body")"
require_status "$bootstrap_status" 200 BOOTSTRAP "$bootstrap_body"
require_json_expr "$bootstrap_body" BOOTSTRAP has_session
token="$(extract_token "$bootstrap_body")"

account_body="$TMP_DIR/account.json"
account_status="$(get_json /v1/account/me "$account_body" -H "authorization: Bearer $token")"
require_status "$account_status" 200 ACCOUNT_ME "$account_body"
require_json_expr "$account_body" ACCOUNT_ME ok

delete_body="$TMP_DIR/delete.json"
delete_status="$(curl -sS -o "$delete_body" -w '%{http_code}' \
  -X POST "$STAGING_URL/v1/account/delete" \
  -H "authorization: Bearer $token")"
require_status "$delete_status" 200 ACCOUNT_DELETE "$delete_body"
require_json_expr "$delete_body" ACCOUNT_DELETE deleted

echo "MealMark staging broker smoke: PASS url=$STAGING_URL"
