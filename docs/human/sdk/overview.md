# Grain SDK Overview (TOR-SDK-A01)

The SDK is a universal primitives surface for building systems on top of Grain without changing protocol semantics.

## Design contract

- strict by default
- no new protocol semantics
- fail-closed behavior on risky boundaries
- core diagnostics preserved (SDK does not translate away protocol error codes)

## Modules

- `identity`: root/device lifecycle, bundle export/import, explicit retroactive revoke behavior
- `events`: append/void/correct, deterministic merge helpers, reducer bridge
- `e2e`: deterministic derive+encrypt+decrypt primitives, cap_id single-assignment guards
- `manifest`: deterministic put/del/resolve wrappers
- `transport`: GR1 encode/decode/verify wrappers
- `codec`: strict validation + diagnostics explanation
- `evidence`: deterministic proof bundle builder

## What SDK does not do

- no domain logic (food/calories/recipes)
- no soft fallback modes
- no hidden conflict/quarantine/revoke suppression
- no protocol rule rewrites

## Package path

- `core/ts/grain-sdk`
- domain adapter example: `core/ts/grain-sdk/examples/sensor-event-v1.ts`
- architecture: `docs/human/sdk/architecture.md`
- error model: `docs/human/sdk/errors.md`
- impossible misuse checklist: `docs/human/sdk/impossible-misuse.md`
- cross-language bridge: `docs/human/sdk/cross-lang-bridge.md`

## Quick commands

```bash
node --experimental-strip-types core/ts/grain-sdk/scripts/demo-end-to-end.ts
node --experimental-strip-types core/ts/grain-sdk/scripts/test-sdk-invariants.ts
node --experimental-strip-types core/ts/grain-sdk/scripts/run-protocol-suite.ts
```
