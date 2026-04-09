# SDK Architecture

This page defines boundaries. The SDK is a strict orchestration layer, not a new protocol semantics layer.

## Practical reading

- If you are building an app, start with `identity`, `events`, `manifest`, `e2e`, and `transport`.
- If you need byte validation or diagnostics explanation, use `codec`.
- If you are handling model output, the safe path is `ai.accept()` then `ai.applyAccepted()`.

## Layer boundaries

1. Protocol (`spec/*`, `conformance/*`)
   - normative rules
   - frozen-core behavior
2. Core engines (`core/rust/grain-core`, `core/ts/grain-ts-core/src`)
   - deterministic rule execution
   - canonical diagnostics
3. Runner surface (`runner/typescript/src`)
   - CLI and conformance harness over the shared TS core
4. SDK (`core/ts/grain-sdk`)
   - typed primitives + safe builders
   - orchestration for identity/events/e2e/manifest/transport/evidence
   - deterministic AI ingestion firewall (`accept` -> `applyAccepted`)
   - no rule rewrites

## What the SDK is allowed to do

- strict by default
- stop on unsafe paths instead of guessing
- preserve core diagnostics (SDK-only codes stay in `SDK_ERR_*`)
- surface conflict/quarantine/unauthorized status explicitly

## What the SDK is not allowed to do

- invent new protocol semantics
- add soft fallback modes
- silently "repair" non-canonical data
- hide conflict, quarantine, revoke, or unauthorized states

## Module map

- `src/identity.ts`: root/device lifecycle, bundle import/export
- `src/events.ts`: append/void/correct/merge/reduce orchestration
- `src/e2e.ts`: deterministic derive/encrypt/decrypt wrappers + manifest glue
- `src/manifest.ts`: deterministic resolution bridge
- `src/transport.ts`: GR1 helpers + deterministic bundle import/export
- `src/codec.ts`: strict validation and diagnostics explanation
- `src/evidence.ts`: deterministic SDK evidence bundle
- `src/primitives.ts`: typed wrappers and set-array builder
- `src/ai/*`: model-agnostic candidate ingestion, deterministic accept/apply, opaque token registry

## Non-goals (enforced)

- no domain semantics
- no alternative conflict or revoke semantics
- no vendor model clients or outbound network calls in SDK core

## Audit anchors

- ADR: `adr/sdk/0001-sdk-universal-primitives-layer.md`
- ADR: `adr/sdk/0003-ai-boundary-deterministic-ingestion.md`
- Invariants: `docs/llm/SDK_INVARIANTS.md`
- Reject paths: `docs/llm/SDK_EDGE_CASES.md`
- Conformance binding: `docs/llm/SDK_CONFORMANCE.md`
