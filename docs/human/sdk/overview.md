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

## Modules

- `identity`: root/device lifecycle, bundle export/import, explicit retroactive revoke behavior
- `events`: append/void/correct, deterministic merge helpers, reducer bridge
- `e2e`: deterministic derive+encrypt+decrypt primitives, cap_id single-assignment guards
- `manifest`: deterministic put/del/resolve wrappers
- `transport`: GR1 encode/decode/verify wrappers
  - `decodeGR1()` is decode-only
  - `verifyGR1()` is verify-only and requires explicit `trust.pub_b64`
  - transport bundles reject malformed event/manifest rows instead of guessing
- `codec`: strict validation + diagnostics explanation
- `evidence`: deterministic evidence bundle builder
- optional AI sidecar (`core/ts/grain-sdk-ai`): deterministic ingestion firewall (`accept` -> `applyAccepted`)
  - structured_v1 uses explicit field profiles/maps (no implicit numeric guessing)

## What SDK does not do

- no domain logic (food/calories/recipes)
- no soft fallback modes
- no hidden conflict/quarantine/revoke suppression
- no protocol rule rewrites
- no vendor model clients or outbound network calls in SDK core
- no partial success on multi-step SDK writes; failed import/correction paths roll back

## Package path

- `core/ts/grain-sdk`
- `core/ts/grain-sdk-ai`
- compatibility matrix:
  - SDK `0.2.x` -> Protocol major `1`
- domain adapter example: `core/ts/grain-sdk/examples/sensor-event-v1.ts`
- architecture: `docs/human/sdk/architecture.md`
- error model: `docs/human/sdk/errors.md`
- impossible misuse checklist: `docs/human/sdk/impossible-misuse.md`
- cross-language bridge: `docs/human/sdk/cross-lang-bridge.md`
- AI boundary: `docs/human/sdk/ai-boundary.md`
- AI ingestion contract: `docs/human/sdk/ai-ingestion.md`
- AI explain contract: `docs/human/sdk/ai-error-explain.md`
- AI privacy boundary: `docs/human/sdk/ai-privacy.md`

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
