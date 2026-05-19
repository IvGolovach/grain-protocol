# Grain SDK Overview

The SDK gives you a safer way to build on top of Grain without changing protocol semantics.

If you want one first success, start with `docs/human/sdk/start-here.md`.
This page is the capability map after that first run.

## Design contract

- strict by default
- no new protocol semantics
- careful behavior on risky boundaries
- core diagnostics preserved (the SDK does not hide protocol error codes)

## Practical defaults

- For a first app, append one event and reduce it before reaching for device keys, manifests, or AI helpers.
- In that first app, `payload_cid` can be a stable app-level identifier.
- If you later store the payload as its own canonical Grain object, then using that real CID is the stronger pattern.
- For a first scanner app, use the local reference app path before creating
  store or registry release work.

## Modules

- `identity`: root/device lifecycle, bundle export/import, explicit retroactive revoke behavior
  - `identity.importBundle()` rejects malformed imported binary fields (`root_pub_b64`, `sync_secret_b64`, `device_keys[*].pub_b64`) instead of accepting permissive base64
- `events`: append/void/correct, deterministic merge helpers, reducer bridge
- `e2e`: deterministic derive+encrypt+decrypt primitives, cap_id single-assignment guards
- `manifest`: deterministic put/del/resolve wrappers
- `transport`: GR1 encode/decode/verify wrappers
  - `decodeGR1()` is decode-only
  - `verifyGR1()` is verify-only, requires explicit `trust.pub_b64`, rejects malformed trust bytes before verification runs, and accepts only strict `ServingOffer` payloads whose `issuer_kid` matches the verified COSE `kid`
  - transport bundles reject malformed event/manifest rows and invalid base64 on imported binary fields instead of guessing
- portable client core (`core/rust/grain-client-core`): Rust workflow layer for generated Swift/Kotlin/WASM/device SDKs
  - `scan_preview()` returns `Verified`, `Untrusted`, or `Rejected` without exposing raw protocol runner operations
  - `scan_accept()` atomically persists verified scans and stays idempotent for duplicate scans
  - identity/device/pairing/sync workflows expose portable lifecycle state without making platform apps own bundle parsing or rollback semantics
- device abstraction contract (`sdk/device`): names app-owned platform edges
  for scan input, capabilities, local storage, export sinks, diagnostics, and
  trust providers without adding account, registry, or store assumptions
- Food Wallet contract (`docs/human/sdk/food-wallet.md`): names the app-owned
  camera/photo/UI and replaceable AI adapter boundary while keeping Grain on
  validation, confirm, snapshot, trust, and safe export primitives
- `codec`: strict validation + diagnostics explanation
- `evidence`: deterministic evidence bundle builder
- optional AI sidecar (`core/ts/grain-sdk-ai`): deterministic ingestion firewall (`accept` -> `applyAccepted`)
  - structured_v1 uses explicit field profiles/maps (no implicit numeric guessing)
  - candidate v1 is object-only until an event append apply path exists
  - byte payload fields use canonical base64 standard encoding

## What SDK does not do

- no domain logic (food/calories/recipes)
- no soft fallback modes
- no hidden conflict/quarantine/revoke suppression
- no protocol rule rewrites
- no vendor model clients or outbound network calls in SDK core
- no partial success on multi-step SDK writes; failed import/correction paths roll back

## Package paths

- `core/ts/grain-sdk`
- `core/ts/grain-sdk-ai`
- `core/rust/grain-client-core`
- `sdk/swift`
- `sdk/kotlin`
- `sdk/wasm`
- `sdk/workflows`
- `sdk/trust`
- `sdk/device`
- `templates/ios-starter`, `templates/android-starter`, `templates/web-wasm-starter`
- `examples/ios-scanner`, `examples/android-scanner`, `examples/wasm-scanner`, `examples/ios-reference-app`, `examples/android-reference-app`
- compatibility matrix:
  - SDK `0.2.x` -> Protocol major `1`
- domain adapter example: `core/ts/grain-sdk/examples/sensor-event-v1.ts`
- local no-device Food pilot: `scripts/sdk/run_local_food_pilot.sh`
- Food Wallet contract and pilot: `docs/human/sdk/food-wallet.md`,
  `scripts/sdk/check_food_wallet_contract.sh`,
  `scripts/sdk/run_food_wallet_pilot.sh`
- architecture: `docs/human/sdk/architecture.md`
- error model: `docs/human/sdk/errors.md`
- impossible misuse checklist: `docs/human/sdk/impossible-misuse.md`
- cross-language bridge: `docs/human/sdk/cross-lang-bridge.md`
- portable client SDK: `docs/human/sdk/portable-client-sdk.md`
- AI boundary: `docs/human/sdk/ai-boundary.md`
- AI ingestion contract: `docs/human/sdk/ai-ingestion.md`
- AI explain contract: `docs/human/sdk/ai-error-explain.md`
- AI privacy boundary: `docs/human/sdk/ai-privacy.md`
- iOS reference app quickstart: `docs/human/sdk/quickstart-ios-reference-app.md`
- Android reference app quickstart: `docs/human/sdk/quickstart-android-reference-app.md`
- device abstraction: `docs/human/sdk/device-abstraction.md`
- local publication dry-runs: `docs/human/sdk/local-publication.md`
- external client certification: `docs/human/sdk/certification.md`

## Quick commands

On a fresh checkout, install the shared TypeScript core first.
The SDK and the runner both build on top of that shared package, but the first
app flow only needs the SDK package.

```bash
npm ci --prefix core/ts/grain-ts-core
npm ci --prefix core/ts/grain-sdk
npm --prefix core/ts/grain-sdk run demo:e2e
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk run run:protocol-suite
```

Optional AI sidecar:

```bash
npm ci --prefix core/ts/grain-sdk-ai
npm --prefix core/ts/grain-sdk-ai run test:boundary
```
