# FILE_MAP

Version: Protocol v0.1 (schema major = 1)

## Source-of-truth priority (highest first)

1) `spec/NES-v0.1.md`  
   Normative MUST/SHOULD/MAY rules.

2) `spec/schemas/grain-v0.1.cddl`  
   Machine-readable schemas.

3) `conformance/vectors/`  
   Conformance criterion (release gate).

4) `spec/profiles/`  
   Normative profiles for CBOR/COSE/E2E/QR.

5) `spec/FREEZE-v0.1.md`, `spec/FREEZE-CONFIRMATION-v0.1.md`, `spec/SCOPE-v0.1.md`, `spec/INTEROP-v0.1.md`, `spec/RC-POLICY.md`, `spec/INTEROP-CLAIM.md`, `spec/rc/**`  
   Freeze boundaries, scope clarification, interop claim boundaries, and RC signoff/revocation governance.

6) `docs/llm/*`  
   Indexes and mappings (invariants, edge cases, conformance mapping).

7) `adr/`  
   Decision history; rationale for frozen choices.

8) `core/rust/`, `runner/typescript/`, `core/`, `sdk/`  
   Implementations; must match spec and pass conformance.

9) `.github/workflows/`, `MIGRATION.md`, `docs/human/github-hardening.md`  
   Provenance and release-governance contract (commit-bound evidence, branch protection, tag policy).

## If conflicts exist

- Conformance vectors define expected behavior for interop.
- NES defines intended normative behavior.
- Any drift MUST block merges until resolved (update spec + vectors together).
