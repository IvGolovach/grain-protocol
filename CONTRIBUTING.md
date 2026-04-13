# Contributing

Grain is protocol-first, but contributing should still feel straightforward.
Small, focused PRs are the easiest to review and merge.

## Ground rules

- The v0.1 core protocol rules are stable. Do not submit breaking changes unless you are proposing a new protocol major version.
- Every change must have a clear reason.
- The conformance suite is the release gate. If conformance fails, the PR does not merge.
- If behavior changes, the matching docs must change in the same PR.
- If code and docs disagree, fix the mismatch before merge.

## Where to start

- `README.md`
- `docs/human/overview.md`
- `docs/llm/FILE_MAP.md`
- `docs/llm/INVARIANTS.md`
- `docs/llm/DOC_SYNC.md`
- `conformance/README.md`

## Pull Requests

Use the PR template. Please answer:
- What changed?
- Why?
- Which invariants or vectors are touched?
- Is this breaking?
- Which docs were updated?

### Docs sync

Before opening a PR, read `docs/llm/DOC_SYNC.md`.
If the change affects users, builders, or maintainers, update the matching human or LLM docs in the same PR.

### ADR requirement

If the PR changes encoding, CID, COSE, ledger, E2E, manifest, limits, conformance, or schemas, add an ADR.
See `adr/0000-template.md`.

### Maintainer-only automation note

Dependency automation uses repository secret `DEPENDABOT_AUTOMERGE_TOKEN`.
If that token is missing or under-scoped, the automation stops and tells you why (`DEPS_ERR_TOKEN_MISSING`, `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS`).
See `docs/human/dependencies-policy.md`.

If you are working in a sandbox where `.git` is readable but not writable, use
`scripts/git-sandbox-safe ...` to run git via a writable mirror in `/tmp`.

### Local hygiene hooks

Run `scripts/setup_local_hygiene.sh` once per clone.
It installs local git hooks that catch accidental leaks in staged files or commit messages before they land in history.

## Style

- Use plain language.
- Define terms once.
- Avoid hidden behavior.
- Add negative vectors for any new edge case.
- For any MUST rule, link to the exact NES paragraph.
