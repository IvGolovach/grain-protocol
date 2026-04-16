# Maintainer Start Here

If you just landed in the maintainer seat, start here.
The repo already has strong guardrails. This page helps you find them fast.

## Fast path (15 minutes)

1. Run `./scripts/doctor`.
   - This gives you a quick health check for branch state, toolchains, and recent verification artifacts.
2. Run `./scripts/bootstrap` if this clone does not already have the pinned local toolchains.
   - This is the blessed host setup path. It uses `mise` plus the repo package installs.
3. Run `./scripts/verify`.
   - This is the normal day-to-day confidence pass.
4. Read `CONTRIBUTING.md`.
   - It tells you the repo rules that matter during normal work.
5. Read `docs/human/release-process.md`.
   - This is the shortest reliable path to a release.
6. Read `docs/human/repository-settings.md`.
   - This explains the GitHub rules the repo expects to stay true.

If you only do one thing before reviewing or merging changes, do steps 1 through 3.

## What matters most

- Keep changes small and self-contained when you can.
- If behavior changes, update the matching docs in the same PR.
- Trust the spec and conformance vectors over any human summary if they disagree.
- Be slow near protocol semantics and fast everywhere else.
- Prefer adding guardrails over adding tribal knowledge.

## Daily jobs

### Review and merge a PR

1. Run `./scripts/doctor`.
2. Run `./scripts/bootstrap` if the host toolchain is not ready yet.
3. Read the PR for scope, risk, and docs sync.
4. Run the relevant checks, or ask for them if the PR does not include proof.
5. Make sure the diff is one logical change.
6. Merge only when the story in code, tests, and docs matches.

### Debug a red branch

1. Run `./scripts/doctor`.
2. Run `./scripts/bootstrap` if the host toolchain drift is part of the failure.
3. Run `./scripts/verify`.
4. If the problem is release-grade only, run `./scripts/certify`.
5. Use `docs/human/repro-checklist.md` when you need a clean-clone path.
6. Use `docs/human/repository-settings.md` if the failure smells like GitHub rules or branch protection drift.

### Cut a release

1. Start with `docs/human/release-process.md`.
2. Use `./scripts/doctor` to confirm your local state is sane.
3. Use `./scripts/bootstrap` if the host toolchain is not already aligned.
4. Run `./scripts/verify`.
5. Run `./scripts/certify`.
6. Follow the tag and artifact steps exactly.

## Repo map for maintainers

- `README.md`: project front door
- `CONTRIBUTING.md`: contributor rules and local hygiene
- `docs/human/release-process.md`: release runbook
- `docs/human/repository-settings.md`: GitHub settings baseline
- `docs/human/portability-pack.md`: verification and evidence model
- `docs/human/repro-checklist.md`: clean-clone reproduction
- `docs/human/maintainer-writing.md`: tone and writing rules for human docs
- `docs/llm/DOC_SYNC.md`: doc sync map when behavior or process changes

## When something feels off

That is normal. This repo is strict on purpose.
When you are unsure, use this order:

1. `spec/NES-v0.1.md`
2. `spec/schemas/grain-v0.1.cddl`
3. `conformance/vectors/`
4. `docs/llm/DOC_SYNC.md`
5. human docs and runbooks

If the layers disagree, fix the drift instead of guessing around it.
