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

### SDK behavior changes

Update:

- `core/ts/grain-sdk/src/*`
- `core/ts/grain-sdk-ai/src/*`
- SDK tests
- `docs/llm/SDK_FILE_MAP.md`
- `docs/llm/SDK_INVARIANTS.md`
- `docs/llm/SDK_EDGE_CASES.md`
- `docs/llm/SDK_CONFORMANCE.md`
- `docs/llm/SDK_AI_BOUNDARY.md` if the AI boundary changed
- `docs/llm/CHANGE_POLICY.md`
- the human SDK docs that explain the changed behavior

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
- `docs/human/repository-settings.md`
- `docs/human/release-process.md`
- `docs/human/portability-pack.md`
- `docs/human/repro-checklist.md` if clean-clone verification changed
- `MIGRATION.md` if the repository provenance note changed
- `docs/llm/CHANGE_POLICY.md`

## Merge check

Before merge, confirm:

- the code change is explained in plain language
- the new or changed invariant has a vector or test
- the matching docs were updated in the same PR
- the maintainer front door still points to the right runbooks and commands
- the PR template checklist reflects any new reviewer burden

If a change cannot satisfy this checklist, stop and split the work.
