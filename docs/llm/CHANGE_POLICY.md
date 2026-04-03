# CHANGE_POLICY (v0.1 frozen core)

Hi teammate LLM. Read this before proposing any change.
It tells you what is frozen, what can grow, and what must be updated together.

## Frozen core (v0.1)

The following are locked and MUST NOT change without a protocol major bump:
- DAG-CBOR strictness rules: reject non-canonical bytes, reject duplicate keys, allow only tag 42
- blessed CID set: CIDv1 + dag-cbor + sha2-256 + base32 lower
- COSE narrow profile: Ed25519 only, deterministic bytes, tag18 forbidden
- set-array closed list plus sorting and uniqueness semantics
- numeric domains and overflow behavior
- ledger authorization: root-only grant/revoke and retroactive revoke
- `(ak,seq)` uniqueness conflict ignore-all rule
- quarantine semantics and precedence
- E2E envelope: HKDF-SHA256 + A256GCM, AAD=`cap_id`, deterministic nonce, cap_id single-assignment plus chash binding
- manifest eligibility, strict op shape (`put|del`), and deterministic resolution
- GR1 prefix and QR pipeline
- baseline limits and Strict Conformance Mode behavior

## Allowed additive changes

These still require ADR + vectors:
- new protocol object types (`t`) within schema major 1
- new transport profiles with new prefixes (`GR2:`, etc.)
- new pairing mechanisms that distribute `sync_secret` without changing envelope semantics
- additional tooling and docs

## DOC_SYNC rule

If a PR changes any contract-visible behavior, the docs must change in the same PR.
Contract-visible means:
- behavior
- diagnostics
- reject paths
- command names
- workflow steps
- contributor instructions
- wording that tells readers what the repo guarantees

Use `docs/llm/DOC_SYNC.md` as the checklist.

Minimum expectation:
- protocol or conformance changes update `docs/llm/FILE_MAP.md`, `docs/llm/INVARIANTS.md`, `docs/llm/EDGE_CASES.md`, `docs/llm/CONFORMANCE.md`, and the affected human docs
- SDK changes update `docs/llm/SDK_FILE_MAP.md`, `docs/llm/SDK_INVARIANTS.md`, `docs/llm/SDK_EDGE_CASES.md`, `docs/llm/SDK_CONFORMANCE.md`, and the affected human SDK docs
- contributor or workflow changes update `docs/llm/README.md`, `docs/llm/FILE_MAP.md`, `CONTRIBUTING.md`, and `.github/pull_request_template.md` as needed

If you cannot update the docs in the same PR, stop and split the work.

## If conformance contract changes

If `conformance/SPEC.md` changes, or if the input/output or diagnostics contract changes:
- add an ADR under `adr/conformance/`
- update `conformance/contract/runner_v1.md` and bump the contract version if incompatible
- update `docs/llm/CONFORMANCE.md`
- update `docs/llm/INVARIANTS.md` and `docs/llm/EDGE_CASES.md` for vector mapping
- update `docs/llm/DOC_SYNC.md`
- update `CHANGELOG.md`

## If provenance or CI policy changes

If a PR changes CI gates, evidence artifacts, branch protection policy, tag namespace policy, or provenance docs:
- update `docs/human/github-hardening.md`
- update `MIGRATION.md` when provenance statements change
- keep required CI context names stable unless governance update is explicit
- update `docs/llm/DOC_SYNC.md`
- update `CHANGELOG.md`
- update `spec/RC-POLICY.md` and `spec/INTEROP-CLAIM.md` when RC or claim process changes

## If SDK strict contracts change

If a PR changes SDK strict orchestration behavior (`core/ts/grain-sdk/**`) in any of these areas:
- strict enforcement defaults
- SDK/core diagnostic boundary or mappings
- sequence allocation or store safety contracts
- evidence bundle canonical or hash format
- transport framing helpers

Then the PR MUST:
- add or update an ADR under `adr/sdk/`
- update `docs/llm/SDK_INVARIANTS.md`
- update `docs/llm/SDK_CONFORMANCE.md` and `docs/llm/SDK_EDGE_CASES.md` when reject-path behavior changes
- update `docs/llm/DOC_SYNC.md`
- update `CHANGELOG.md`

## Red flags

These are likely breaking:
- any change in canonicalization rules
- any change in the blessed CID set
- any change in COSE headers or algorithms for core contexts
- any change in ledger reducer semantics or conflict rules
- any change in deterministic nonce derivation or AAD binding
- any change in manifest resolution tie-break

If you see one of these, pause and escalate to your human instead of trying a safe tweak.
