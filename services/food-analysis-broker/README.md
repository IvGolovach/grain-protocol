# MealMark Food Analysis Broker

This service is the server-side boundary for MealMark photo analysis and food
lookup. It owns OpenAI and nutrition-provider credentials, enforces account or
development auth, and returns reviewable drafts only. Raw meal photos must never
be persisted or logged.

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
```

Then replace the placeholder D1 IDs in `wrangler.jsonc` and deploy:

```sh
npm --prefix services/food-analysis-broker run typecheck:worker
wrangler deploy --env staging
wrangler deploy --env production
```

Required production posture:

- `MEALMARK_AUTH_MODE=session`;
- `MEALMARK_SESSION_HMAC_SECRET` set as a Cloudflare secret;
- `OPENAI_API_KEY` set as a Cloudflare secret;
- `FOODDATA_CENTRAL_API_KEY` set as a Cloudflare secret;
- D1 migration `0001_account_entitlement.sql` applied before traffic;
- iOS app configured with an HTTPS broker URL, never a bundled dev token.

## Validation

```sh
npm --prefix services/food-analysis-broker test
npm --prefix services/food-analysis-broker run typecheck:worker
scripts/sdk/check_food_analysis_broker.sh
```
