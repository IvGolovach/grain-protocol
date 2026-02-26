# SDK Architecture (TOR-SDK-A01 + TOR-SDK-A03)

This page defines boundaries. SDK is a strict orchestration layer, not a protocol semantics layer.

## Layer boundaries

1. Protocol (`spec/*`, `conformance/*`)
   - normative rules
   - frozen-core behavior
2. Core engines (`core/rust/grain-core`, `runner/typescript/src`)
   - deterministic rule execution
   - canonical diagnostics
3. SDK (`core/ts/grain-sdk`)
   - typed primitives + safe builders
   - orchestration for identity/events/e2e/manifest/transport/evidence
   - deterministic AI ingestion firewall (`accept` -> `applyAccepted`)
   - no rule rewrites

## SDK contract

- strict by default
- fail-closed for unsafe paths
- preserve core diagnostics (SDK-only codes stay in `SDK_ERR_*`)
- surface conflict/quarantine/unauthorized status explicitly

## Module map

- `src/identity.ts`: root/device lifecycle, bundle import/export
- `src/events.ts`: append/void/correct/merge/reduce orchestration
- `src/e2e.ts`: deterministic derive/encrypt/decrypt wrappers + manifest glue
- `src/manifest.ts`: deterministic resolution bridge
- `src/transport.ts`: GR1 helpers + deterministic bundle import/export
- `src/codec.ts`: strict validation and diagnostics explanation
- `src/evidence.ts`: deterministic SDK proof bundle
- `src/primitives.ts`: typed wrappers and set-array builder
- `src/ai/*`: model-agnostic candidate ingestion, deterministic accept/apply, opaque token registry

## Non-goals (enforced)

- no domain semantics
- no soft fallback mode
- no hidden canonicalization repair
- no alternative conflict/revoke semantics

## Audit anchors

- ADR: `adr/sdk/0001-sdk-universal-primitives-layer.md`
- ADR: `adr/sdk/0003-ai-boundary-deterministic-ingestion.md`
- Invariants: `docs/llm/SDK_INVARIANTS.md`
- Reject paths: `docs/llm/SDK_EDGE_CASES.md`
- Conformance binding: `docs/llm/SDK_CONFORMANCE.md`
