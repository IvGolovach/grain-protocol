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

6) `docs/llm/*`
   Your fast indexes and cross-file mappings.

7) `adr/`
   Why decisions were made; use for rationale, not as normative override.

8) `core/rust/`, `runner/typescript/`, `core/`, `sdk/`
   Implementations. They must conform to the contract above.

9) `.github/workflows/`, `MIGRATION.md`, `docs/human/github-hardening.md`
   Provenance and policy enforcement (CI gates, evidence artifacts, branch protection).

## If two layers disagree

- Treat conformance vectors as executable interop truth.
- Treat NES as normative intent.
- Raise drift as a blocking issue; do not "interpret around it."
- Resolve by updating spec and vectors together in one governed change.
