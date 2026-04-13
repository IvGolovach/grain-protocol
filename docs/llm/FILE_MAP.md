# FILE_MAP

Version: Protocol v0.1 (schema major = 1)

Hi teammate LLM. If you are deciding what to trust first, use this order.

## Source-of-truth priority

1. `spec/NES-v0.1.md`
   - Normative rules (MUST/SHOULD/MAY).
2. `spec/schemas/grain-v0.1.cddl`
   - Machine-readable schema shapes.
3. `conformance/vectors/`
   - Executable release gate and interop criterion in strict mode.
4. `spec/profiles/`
   - Normative CBOR / COSE / E2E / QR profile details.
5. `spec/FREEZE-v0.1.md`, `spec/FREEZE-CONFIRMATION-v0.1.md`, `spec/SCOPE-v0.1.md`, `spec/INTEROP-v0.1.md`, `spec/RC-POLICY.md`, `spec/INTEROP-CLAIM.md`, `spec/rc/**`
   - Freeze boundary, scope boundary, interop claim boundary, and RC governance.
6. `docs/llm/*`, including `DOC_SYNC.md`, `SDK_FILE_MAP.md`, `SDK_INVARIANTS.md`, `SDK_EDGE_CASES.md`, `SDK_CONFORMANCE.md`, `PORTING.md`, `DOMAIN_ADAPTERS.md`, `PROHIBITION_ZONE.md`
   - Fast indexes, maintenance rules, and cross-file mappings.
7. `adr/` (including `adr/sdk/`)
   - Why decisions were made; use for rationale, not as a normative override.
8. `README.md`, `docs/human/*`, `core/ts/grain-sdk/README.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`
   - Human onboarding and contributor process docs. Helpful, but they do not override spec or vectors.
9. `core/rust/`, `core/ts/grain-ts-core/`, `runner/typescript/`, `core/`, `sdk/`
   - Implementations. They must conform to the contract above.
10. `.github/workflows/`, `.githooks/*`, `scripts/setup_local_hygiene.sh`, `tools/ci/check_history_hygiene.py`, `MIGRATION.md`, `docs/human/rationale/TOR-PORTABILITY-A01.md`, `docs/human/repository-settings.md`, `docs/human/portability-pack.md`, `docs/human/porting-grain.md`
   - Provenance, local hygiene enforcement, and policy enforcement (CI gates, evidence artifacts, branch protection).
11. `stabilization/RC-STAB-A01/*`, `tools/stabilization/run_rc_stab.py`, `.github/workflows/rc-stabilization-deep-check.yml`
   - RC pressure-test tooling plus a historical RC stabilization record. Use this as reference material when a new RC window is opened.

## If two layers disagree

- Treat conformance vectors as executable interop truth.
- Treat NES as normative intent.
- Treat human docs as explanations that may need to be updated when they drift.
- Raise drift as a blocking issue; do not interpret around it.
- Resolve by updating spec and vectors together in one governed change.
