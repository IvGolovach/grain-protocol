# MealMark Food Analysis Broker

This service is the server-side boundary for MealMark photo analysis and food
lookup. It owns OpenAI and nutrition-provider credentials, enforces auth for
photo analysis, and returns reviewable drafts only. Food search can be exposed
as anonymous read-only traffic when `MEALMARK_ALLOW_ANONYMOUS_FOOD_SEARCH=1`.
Raw meal photos must never be persisted or logged.

## Local Node Adapter

```sh
FOOD_ANALYSIS_MOCK=1 \
FOOD_SEARCH_LIVE=0 \
FOOD_SEARCH_FIXTURES=1 \
npm --prefix services/food-analysis-broker start
```

For a real local iPhone run, set provider secrets in an ignored environment
file or shell, then pass only the broker URL to the app. Do not embed provider
secrets in the iOS bundle.

## Cloudflare Worker Lane

The production target is a Cloudflare Worker using the same `fetch` handler as
the local Node adapter.

Use `--env staging` or `--env production` for every remote command. The
top-level Wrangler worker name is intentionally a non-production dev target so a
bare `wrangler deploy` cannot overwrite production.

One-time Cloudflare setup:

```sh
wrangler d1 create mealmark-staging
wrangler d1 create mealmark-production
wrangler d1 migrations apply mealmark-staging --local=false
wrangler d1 migrations apply mealmark-production --local=false
wrangler secret put OPENAI_API_KEY --env staging
wrangler secret put OPENAI_API_KEY --env production
wrangler secret put FOODDATA_CENTRAL_API_KEY --env staging
wrangler secret put FOODDATA_CENTRAL_API_KEY --env production
wrangler secret put MEALMARK_SESSION_HMAC_SECRET --env staging
wrangler secret put MEALMARK_SESSION_HMAC_SECRET --env production
wrangler secret put APP_STORE_BUNDLE_ID --env staging
wrangler secret put APP_STORE_BUNDLE_ID --env production
wrangler secret put APP_STORE_CONNECT_ISSUER_ID --env staging
wrangler secret put APP_STORE_CONNECT_ISSUER_ID --env production
wrangler secret put APP_STORE_CONNECT_KEY_ID --env staging
wrangler secret put APP_STORE_CONNECT_KEY_ID --env production
wrangler secret put APP_STORE_CONNECT_PRIVATE_KEY_P8 --env staging
wrangler secret put APP_STORE_CONNECT_PRIVATE_KEY_P8 --env production
```

After the D1 IDs in `wrangler.jsonc` point at the intended account databases,
deploy staging through the repo-owned script:

```sh
npm --prefix services/food-analysis-broker run typecheck:worker
scripts/sdk/deploy_food_analysis_broker_staging.sh
npm --prefix services/food-analysis-broker run cf:migrate:production
npm --prefix services/food-analysis-broker run cf:deploy:production
```

Required production posture:

- `MEALMARK_AUTH_MODE=session`;
- `MEALMARK_ALLOW_ANONYMOUS_FOOD_SEARCH=1` if pre-account ingredient lookup
  should work in the app;
- keep `FOOD_SEARCH_ALLOW_USDA_BARCODE_FALLBACK` unset unless the deployment
  deliberately accepts USDA branded UPC fallback risk. MealMark production
  barcode search should prefer Open Food Facts product records and ask for a
  label/manual review when no authoritative barcode product is available;
- `OPEN_FOOD_FACTS_BASE_URL=https://world.openfoodfacts.net` for Cloudflare
  Worker deployments. This host has the same product API shape and avoids
  Worker-to-`world.openfoodfacts.org` TLS failures observed in staging;
- `MEALMARK_SESSION_HMAC_SECRET` set as a Cloudflare secret;
- `OPENAI_API_KEY` set as a Cloudflare secret;
- `FOODDATA_CENTRAL_API_KEY` set as a Cloudflare secret;
- `APP_STORE_SERVER_ENVIRONMENT=Sandbox` for TestFlight/staging and
  `Production` for App Store production entitlement verification;
- App Store Server API secrets set before enabling visible paid products;
- D1 migrations applied before traffic;
- iOS app configured with an HTTPS broker URL, never a bundled dev token.

## Validation

```sh
npm --prefix services/food-analysis-broker test
npm --prefix services/food-analysis-broker run typecheck:worker
scripts/sdk/check_food_analysis_broker.sh
scripts/sdk/check_food_analysis_broker_staging.sh --require-cloudflare
```
