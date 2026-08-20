# ADR-0012: Typed Object Validation v1

- Status: Accepted
- Date: 2026-08-18
- Owners: Grain Contributors
- Affects: Protocol, Conformance, Core
- Invariants touched: INV-OBJ-001, INV-OBJ-002, INV-OBJ-003, INV-OBJ-004, INV-OBJ-005, INV-OBJ-006
- Conformance vectors impacted: `conformance/vectors/object/*.json`

## Context

Grain v0.1 already requires every known protocol object to satisfy its CDDL
production. The strict Rust and TypeScript paths enforced canonical DAG-CBOR,
closed top-level keys, `crit`, and selected context-specific shapes, but the
generic `dagcbor_validate` operation did not expose a way to request complete
validation of one named CDDL production.

That gap allowed a canonical map with a known `t` to pass the generic byte
checks even when required fields were missing or had the wrong type. It also
left nested records, union branches, fixed-width byte strings, numeric domains,
and full CID-link structure without one shared cross-language vector pack.

This decision is recorded under `adr/protocol/` because known-object validity
is an NES/CDDL protocol rule. The optional runner input only exposes caller
context needed to execute that existing rule; it is not the rule's source.

## Decision

`runner_v1` keeps its existing operation set. The existing
`dagcbor_validate` operation receives one optional input:

```json
{
  "bytes_b64": "...",
  "object_type": "IngredientRef"
}
```

When `object_type` is absent, the operation keeps its existing strict
DAG-CBOR behavior. When present, it MUST be a supported string selector; an
unknown string does not bypass earlier strict-byte diagnostics. The
implementation MUST:

1. apply the generic and applicable context byte limits;
2. parse and validate strict canonical DAG-CBOR;
3. require a top-level map and schema-major envelope;
4. select the named v0.1 CDDL production;
5. enforce closed keys, required fields, value types, fixed widths, full CID
   structure, nested productions, union exclusivity, numeric domains, and
   set-array rules;
6. return deterministic diagnostics using the documented precedence.

The supported selector values are the 14 top-level v0.1 productions:

- `IngredientRef`
- `NutrientProfile`
- `CookRun`
- `NutritionComputeResult`
- `IntakeEvent`
- `ServingOffer`
- `LedgerGenesis`
- `DeviceKeyGrant`
- `DeviceKeyRevoke`
- `VoidEvent`
- `CorrectionEvent`
- `LedgerEvent`
- `EncryptedObject`
- `ManifestRecord`

For productions with a fixed `t` literal, the encoded `t` MUST match the
selector. `LedgerEvent` is the deliberate exception: its CDDL production uses
`tstr` because the field carries the event type, so `object_type="LedgerEvent"`
selects the envelope schema while permitting any text-string `t` value.

`IntakeEvent` MUST match exactly one of its three source branches.
`ManifestRecord` MUST match exactly one `put` or `del` branch. Manifest branch
or op-shape failures use `GRAIN_ERR_MANIFEST_OP`; other typed shape failures use
`GRAIN_ERR_SCHEMA` unless a more specific existing diagnostic applies.

## Compatibility

This is an additive `runner_v1` input and an implementation correction toward
the already normative NES/CDDL/CBOR-profile contract. It does not add an
operation, change the runner output, add an object type, change schema major
`v=1`, or redefine a valid v0.1 encoding.

Compatibility is measured against that complete normative contract, not
against acceptance by an earlier incomplete validator. In particular,
`NutrientProfile.uncert` is variance and MUST be non-negative under NES §6.6
and the CBOR profile §6. Historical negative `uncert` values were
nonconforming. Producers that persisted signed application metadata there must
move it under `ext` (or remove it), recompute valid variance when applicable,
and rederive affected CIDs before enabling selected typed validation.

- Valid v0.1 objects remain valid.
- Canonical bytes that never satisfied their selected CDDL production now
  reject deterministically.
- The protocol schema major remains `1`.
- The repository release classification is PATCH.

## Consequences

### Positive

- Rust, TypeScript, SDK, and downstream implementations can prove the same
  typed boundary with shared bytes.
- CID derivation and persistence callers can validate a selected object shape
  before treating bytes as that type.
- The vector pack covers every top-level v0.1 production and both union-heavy
  shapes.

### Trade-offs

- Implementations must maintain a complete v0.1 schema table.
- More invalid inputs reject than under the previously incomplete generic
  implementation path.
- New additive object types still require CDDL, vectors, and an ADR before they
  can become valid selector values.

### Security / privacy impact

- Rejects malformed typed bytes before callers treat them as a known object,
  reducing parser/schema differential and malformed-link risks.
- Adds no cryptographic primitive, key material, telemetry, network access, or
  privacy-bearing field. `object_type` is local validation context only.
- Introduces no new valid wire representation or data-retention requirement.

### Interop / determinism impact

- Rust, TypeScript, and WASM apply the same named production and diagnostic
  precedence to identical bytes.
- Shared vectors make invalid-input rejection deterministic; valid canonical
  bytes and CID derivation remain unchanged.
- Ledger reduction, manifest resolution order, signatures, and E2E semantics
  are not changed.

## Implementation notes and non-goals

- Keep `object_type` optional on existing `dagcbor_validate`; do not add a
  runner operation, output field, or encoded object field.
- Use a closed schema selector table and recursive validation for nested maps,
  CID links, unions, set-arrays, numeric domains, and applicable limits.
- Preserve generic strict DAG-CBOR behavior when the selector is absent.
- Non-goals: schema inference from `t`, object construction/coercion, new CDDL
  productions, new SDK APIs, or changes to cryptography/reducer semantics.

## Alternatives considered

- Add `typed_object_validate_v1` as a new runner operation. Rejected because
  the `runner_v1` operation set is frozen and the existing operation can accept
  an additive optional input.
- Infer the target only from encoded `t`. Rejected because `LedgerEvent.t` is
  intentionally data, and explicit selection makes caller intent auditable.
- Validate only required top-level fields. Rejected because nested records,
  unions, fixed-width byte strings, CID links, and numeric domains are equally
  normative.

## References

- `spec/NES-v0.1.md` §2
- `spec/schemas/grain-v0.1.cddl`
- `spec/profiles/cbor-profile.md`
- `conformance/SPEC.md`
- `conformance/contract/runner_v1.md`
- `docs/llm/INVARIANTS.md`
