# DOC_SYNC

This file tells you which docs must move together when a contract or process changes.

## One rule

If behavior changes, update the matching docs in the same pull request.
Do not leave the repo in a state where code, tests, and docs tell different stories.

If you are unsure whether a doc is affected, assume that it is.

## What counts as a contract change

- protocol semantics
- vector inputs, outputs, or diagnostics
- SDK behavior
- reject paths or edge cases
- command names or workflow steps
- contributor or release process
- any wording that tells readers what the repo guarantees
- SDK/domain app-facing contracts such as Food Wallet schemas, safe-summary
  boundaries, and platform starter guarantees

## Update matrix

### Protocol or conformance changes

Update:

- `spec/NES-v0.1.md`
- `spec/schemas/grain-v0.1.cddl`
- `conformance/vectors/`
- `conformance/contract/runner_v1.md`
- `docs/llm/FILE_MAP.md`
- `docs/llm/INVARIANTS.md`
- `docs/llm/EDGE_CASES.md`
- `docs/llm/CONFORMANCE.md`
- `docs/llm/CHANGE_POLICY.md`
- any human docs that explain the changed workflow or guarantee

For Typed Object Validation v1, protocol ADR-0012 is the approved exception to
the general `adr/conformance/` location rule because NES/CDDL owns known-object
validity; do not add a duplicate conformance ADR. Also keep these synchronized:

- `adr/protocol/0012-typed-object-validation-v1.md`
- `conformance/vectors/object/`
- `core/rust/grain-core/docs/errors.md`
- `docs/llm/PORTING.md`
- `docs/human/implementing-grain.md`
- `docs/human/porting-grain.md`

Do not add a new `runner_v1` operation for typed validation. The compatible
surface is optional `object_type` on existing `dagcbor_validate`.

### SDK behavior changes

Raw ledger CBOR-sequence changes also keep SDK ADR-0011, SDK-INV-0011,
SDK-REG-0004 and the TypeScript README synchronized. Distinguish canonical
reducer-model bytes from typed/signed protocol events.

Update:

- `core/ts/grain-sdk/src/*`
- `core/ts/grain-sdk-ai/src/*`
- `core/rust/grain-client-core/src/*`
- SDK tests
- `docs/llm/SDK_FILE_MAP.md`
- `docs/llm/SDK_INVARIANTS.md`
- `docs/llm/SDK_EDGE_CASES.md`
- `docs/llm/SDK_CONFORMANCE.md`
- `docs/llm/SDK_AI_BOUNDARY.md` if the AI boundary changed
- `docs/llm/CHANGE_POLICY.md`
- the human SDK docs that explain the changed behavior

Identity import sequence-safety changes also keep
`adr/sdk/0009-identity-import-sequence-high-water.md`, the Rust
`identity_device_lifecycle` tests, the TypeScript `SDK-REG-0002` checks, and
`sdk/workflows/contract/client_workflow_v1.md` synchronized. State the saved
counter guarantee and TypeScript live-allocator coverage separately from authorization reconciliation and cold-backup
rollback protection.

Identity history merge changes also keep SDK ADR-0010, Rust `identity_recovery`
and public `binding_api` tests, TypeScript `SDK-REG-0003`, and the identity/sync
merge policy synchronized. Distinguish valid-state preservation from recovery
of legacy state with missing metadata.

Snapshot sequence-safety changes also keep
`adr/sdk/0008-snapshot-sequence-high-water.md`,
`sdk/workflows/contract/client_workflow_v1.md`, and
`core/rust/grain-client-core/tests/storage_contract.rs` synchronized, including
the limits of restoring backups without newer local sequence state.

### Human onboarding changes

Update:

- `README.md`
- `docs/human/start-here.md`
- `docs/human/overview.md`
- `docs/human/quickstart.md`
- `docs/human/building-on-grain.md`
- `docs/human/implementing-grain.md`
- `docs/human/design-in-one-page.md`
- `docs/human/maintainer-start-here.md`
- `docs/human/maintainer-writing.md`
- `docs/human/sdk/minimal-app-example.md`
- `docs/human/sdk/scan-quickstart.md`
- `sdk/README.md`
- `examples/README.md`
- `core/ts/grain-sdk/README.md`
- `core/ts/grain-sdk-ai/README.md`
- `docs/human/future-vision.md` if the product direction claim changed

### Contributor and maintenance changes

Update:

- `docs/llm/README.md`
- `docs/llm/FILE_MAP.md`
- `docs/llm/SDK_FILE_MAP.md`
- `docs/llm/CHANGE_POLICY.md`
- `CONTRIBUTING.md`
- `.github/pull_request_template.md`
- `docs/human/maintainer-start-here.md`
- `docs/human/maintainer-writing.md`
- `docs/human/repository-settings.md` if release or governance rules changed
- `docs/human/release-process.md` if maintainers need new release steps

### CI, release, and provenance changes

Update:

- `.github/workflows/*` that changed
- `docs/human/dependencies-policy.md` when dependency cadence, runner trust, or full-CI approval changes
- `docs/human/repository-settings.md`
- `docs/human/release-process.md`
- `docs/human/portability-pack.md`
- `docs/llm/CONFORMANCE.md` when required contexts or full-graph conditions change
- `GOVERNANCE.md` when the live ruleset contract changes
- a superseding ADR when accepted CI or dependency automation policy changes
- `docs/human/repro-checklist.md` if clean-clone verification changed
- `MIGRATION.md` if the repository provenance note changed
- `docs/llm/CHANGE_POLICY.md`

When release evidence starts publishing or omitting artifacts, keep the human
release runbook and repository-settings evidence policy in sync with the actual
workflow. SDK release packages are release evidence only after the same commit
passes strict SDK verification and the package metadata checker.

## Merge check

Before merge, confirm:

- the code change is explained in plain language
- the new or changed invariant has a vector or test
- the matching docs were updated in the same PR
- the maintainer front door still points to the right runbooks and commands
- the PR template checklist reflects any new reviewer burden

If a change cannot satisfy this checklist, stop and split the work.
