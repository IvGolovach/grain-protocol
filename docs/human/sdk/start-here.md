# SDK Start Here

If you are building an app on Grain, start here. Keep the first version small and let the SDK handle the strict protocol work for you.

## Your first pass

1. Read [Minimal app example](./minimal-app-example.md).
2. Run the ready-made demo if you want a quick confidence check.
3. On a fresh checkout, install `core/ts/grain-ts-core`
   and `core/ts/grain-sdk` before the first SDK build.
4. If you build manually, use the SDK build. It will build the shared
   TypeScript core first.

```bash
npm ci --prefix core/ts/grain-ts-core
npm ci --prefix core/ts/grain-sdk
npm --prefix core/ts/grain-sdk run demo:e2e
```

Expected output includes stable fields like:

- `strict: true`
- `appended_event_id`
- `reducer_pass`
- `proof_sha256`

## What to do first in code

1. Create a root identity.
2. Append one event.
3. Reduce the event list into a deterministic result.
4. Only then add device keys, private sync, manifests, or AI helpers.

For that first event, `payload_cid` can be a stable application identifier for the payload.
If you later persist the payload as its own canonical Grain object, switch to using that real CID.

If you need device lifecycle changes, use `identity.addDeviceKey()` and `identity.revokeDeviceKey()`. These APIs keep the SDK's local authorization view and the ledger in sync.
If you are adapting another domain into Grain, read `docs/human/domain-adapters.md` after the first success.
If you are also changing the strict TS runner itself, then install `runner/typescript` too.

## What the SDK handles for you

- strict-by-default execution
- rejected unauthorized appends
- safe `cap_id` generation
- rejected `cap_id` overwrite or corruption
- private payload helpers
- manifest helpers for private graph lookups
- AI candidates that stay suggestions until you accept them

## Want the full map?

- `core/ts/grain-sdk/src`
- `docs/human/sdk/architecture.md`
- `docs/human/sdk/errors.md`
- `docs/human/sdk/impossible-misuse.md`
- `docs/human/sdk/cross-lang-bridge.md`
- `docs/human/sdk/ai-boundary.md`
- `docs/human/sdk/ai-ingestion.md`
