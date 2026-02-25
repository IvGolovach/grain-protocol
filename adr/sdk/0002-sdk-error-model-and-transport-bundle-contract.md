# ADR 0002: SDK Error Model and Transport Bundle Contract

Status: Accepted

Date: 2026-02-25

## Context

TOR-SDK-A01 requires deterministic SDK diagnostics and explicit safe transport helpers.

Two gaps existed:

1. SDK errors were code-only and lacked deterministic category/ref metadata.
2. Transport toolkit lacked deterministic bundle import/export APIs with schema checks.

These gaps increase integration ambiguity and make audit/debug workflows weaker.

## Decision

1. Introduce deterministic SDK error descriptors in `core/ts/grain-sdk/src/errors.ts`:
   - `code`
   - `category`
   - `layer`
   - `nes_ref`
   - `vector_refs`
   - `human_hint`
2. Update canonical explain API to return structured diagnostics with references.
3. Extend transport toolkit with deterministic bundle APIs:
   - `bundleExport(...)`
   - `bundleImport(...)`
4. Add typed primitive helpers and set-array strict builder in `src/primitives.ts`.
5. Extend SDK invariant suite with checks for:
   - set-array builder duplicate rejection
   - deterministic error explain contract
   - transport bundle schema/roundtrip behavior

## Consequences

- SDK diagnostics are machine-usable and audit-friendly.
- Integrators get deterministic transport bundle boundary checks.
- Misuse paths are covered by executable invariant tests.
- Protocol semantics remain unchanged.

## Invariants touched

- SDK-INV-0008
- SDK-INV-0009
- SDK-INV-0010
- Existing SDK-INV-0001..0007 unchanged in meaning.
