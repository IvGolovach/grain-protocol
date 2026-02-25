# FILE_MAP

Version: Protocol v0.1 (schema major = 1)

Hi teammate LLM. If you are deciding what to trust first, use this order.

## Source-of-truth priority (highest first)

1) `spec/NES-v0.1.md`
   Normative rules (MUST/SHOULD/MAY).

2) `spec/schemas/grain-v0.1.cddl`
   Machine-readable schema shapes.

3) `conformance/vectors/`
   Executable release gate and interop criterion in strict mode.

4) `spec/profiles/`
   Normative CBOR/COSE/E2E/QR profile details.

5) `spec/FREEZE-v0.1.md`, `spec/FREEZE-CONFIRMATION-v0.1.md`, `spec/SCOPE-v0.1.md`, `spec/INTEROP-v0.1.md`, `spec/RC-POLICY.md`, `spec/INTEROP-CLAIM.md`, `spec/rc/**`
   Freeze boundary, scope boundary, interop claim boundary, and RC governance.

6) `docs/llm/*`, including `SDK_FILE_MAP.md`, `SDK_INVARIANTS.md`, `SDK_EDGE_CASES.md`, `SDK_CONFORMANCE.md`, `PORTING.md`, `DOMAIN_ADAPTERS.md`, `PROHIBITION_ZONE.md`
   Your fast indexes and cross-file mappings.

7) `adr/` (including `adr/sdk/`)
   Why decisions were made; use for rationale, not as normative override.

8) `core/rust/`, `runner/typescript/`, `core/`, `sdk/`
   Implementations. They must conform to the contract above.

9) `.github/workflows/`, `MIGRATION.md`, `docs/human/github-hardening.md`, `docs/human/portability-pack.md`, `docs/human/porting-grain.md`
   Provenance and policy enforcement (CI gates, evidence artifacts, branch protection).

10) `stabilization/RC-STAB-A01/*`, `tools/stabilization/run_rc_stab.py`, `.github/workflows/rc-stabilization-nightly.yml`
   RC pressure-test contract and execution tooling. Use this when deciding whether RC can be promoted or must be revoked/cut as RC2.

## If two layers disagree

- Treat conformance vectors as executable interop truth.
- Treat NES as normative intent.
- Raise drift as a blocking issue; do not "interpret around it."
- Resolve by updating spec and vectors together in one governed change.
