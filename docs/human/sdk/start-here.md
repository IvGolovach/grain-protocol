# SDK Start Here

If you are building an app on Grain, start here. Keep the first version small and let the SDK handle the strict protocol work for you.

## Your first pass

1. If you are building a camera-first iOS, Android, glasses, browser, or robot
   scanner client, read [Scanner app quickstart](./scan-quickstart.md).
2. If you are handing one SDK SHA to another developer, use
   [Source SDK handoff](./source-sdk-handoff.md).
3. If you want a thin starter shell, use `templates/ios-starter`,
   `templates/android-starter`, or `templates/web-wasm-starter`.
4. If you only want the smallest ledger app, read
   [Minimal app example](./minimal-app-example.md).
5. Run the ready-made demo if you want a quick confidence check.
6. On a fresh checkout, install `core/ts/grain-ts-core`
   and `core/ts/grain-sdk` before the first SDK build.
7. If you want the optional AI sidecar, install `core/ts/grain-sdk-ai` separately.
8. If you are building a camera-first iOS, Android, glasses, or robot client,
   read [Portable client SDK](./portable-client-sdk.md).
9. For scanner-shell reference code, start with `examples/ios-scanner`,
   `examples/ios-reference-app`, `examples/android-scanner`, or
   `examples/wasm-scanner`.
10. To create a real signed scanner input for local app development, run
   `cargo run --manifest-path core/rust/Cargo.toml -p grain-issuer-kit -- --pretty`
   and wrap the emitted `trust_pub_b64` in a local `sdk/trust` bundle.
11. For app-owned trust material, load that bundle into the platform static
   trust provider and pass a stable trust anchor ID (`trustAnchorID` in Swift,
   `trustAnchorId` in Kotlin and WASM).
12. If you build manually, use the SDK build. It will build the shared
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
- a narrow host bridge if you later opt into the AI sidecar

## Want the full map?

- `core/ts/grain-sdk/src`
- `docs/human/sdk/architecture.md`
- `docs/human/sdk/source-sdk-handoff.md`
- `docs/human/sdk/scan-quickstart.md`
- `docs/human/sdk/distribution-roadmap.md`
- `docs/human/sdk/security-review.md`
- `docs/human/sdk/release-train.md`
- `docs/human/sdk/portable-client-sdk.md`
- `docs/human/sdk/errors.md`
- `docs/human/sdk/impossible-misuse.md`
- `docs/human/sdk/cross-lang-bridge.md`
- `docs/human/sdk/ai-boundary.md`
- `docs/human/sdk/ai-ingestion.md`
- `examples/README.md`
