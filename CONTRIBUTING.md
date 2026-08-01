# Contributing

Thanks for helping with Grain.
This repo is protocol-first and fairly strict, but the day-to-day workflow should still feel steady and readable.

If you are new, start here:

1. Run `./scripts/demo`.
2. Run `./scripts/doctor`.
3. Run `./scripts/bootstrap` if you want the blessed local toolchain path.
4. Run `./scripts/verify`.
5. Read `docs/human/maintainer-start-here.md`.
6. Read `docs/llm/DOC_SYNC.md` before changing behavior, contracts, or process docs.

## Ground rules

- The v0.1 core protocol rules are stable.
- Every change needs a clear reason.
- The conformance suite is the release gate.
- If behavior changes, update the matching docs in the same PR.
- If code and docs disagree, fix the mismatch before merge.
- Small, focused PRs are easier to review and safer to ship.

## Where to start

- `README.md`
- `docs/human/start-here.md`
- `docs/human/maintainer-start-here.md`
- `docs/human/overview.md`
- `docs/llm/FILE_MAP.md`
- `docs/llm/INVARIANTS.md`
- `docs/llm/DOC_SYNC.md`
- `conformance/README.md`

## Pull requests

Use the PR template.
Please answer these clearly:

- What changed?
- Why?
- Which invariants or vectors are touched?
- Is this breaking?
- Which docs were updated?

## Docs sync

Before opening a PR, read `docs/llm/DOC_SYNC.md`.
If the change affects users, builders, or maintainers, update the matching human or LLM docs in the same PR.

## ADR requirement

If the PR changes encoding, CID, COSE, ledger, E2E, manifest, limits, conformance, or schemas, add an ADR.
See `adr/0000-template.md`.

## Maintainer-only CI note

Routine dependency updates are grouped monthly and merged manually. There is no
privileged Dependabot automerge token. See
`docs/human/dependencies-policy.md`.

Workflow runs from every external fork contributor require maintainer approval
before any job starts. This is separate from the full-CI approval below.

For code, executable automation, protocol, conformance, SDK, script, or unknown
paths, the workflow first runs its Linux graph, then waits at `Approve full CI`.
After reviewing the final diff, a maintainer approves the protected `full-ci`
environment from the run's `Review deployments` prompt. Only then can the
GitHub-hosted macOS and evidence jobs start. Do not attach a persistent
self-hosted runner to this public repository.

If you are working in a sandbox where `.git` is readable but not writable, use `scripts/git-sandbox-safe ...` to run git through a writable mirror in `/tmp`.

## Local hygiene hooks

Run `scripts/setup_local_hygiene.sh` once per clone.
It installs local git hooks that catch common mistakes before they land in history.

## Writing style

Use plain language.
Write like you are helping a smart teammate quickly, not like you are trying to impress a standards committee.

- Start with the fastest safe path.
- Use short sentences and short paragraphs.
- Use active voice.
- Keep docs warm, direct, and a little human.
- Put runnable commands in code blocks.
- Say what success looks like.
- Add negative vectors for new edge cases.
- For any MUST rule, link to the exact NES paragraph.

For the longer house style, read `docs/human/maintainer-writing.md`.
