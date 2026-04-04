# Contributing

Grain is protocol-first, but we try to keep the process easy to follow.
Contributions are welcome. Please keep changes small, explicit, and documented.

## Ground rules

- Protocol v0.1 is frozen core. Do not submit breaking changes unless you are explicitly proposing a new protocol major version.
- Every change must have a clear reason.
- The conformance suite is a release gate. If conformance fails, the PR does not merge.
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
- Which invariants are touched?
- Which conformance vectors are affected?
- Is this breaking?
- Which docs were updated?

### Docs sync

Before opening a PR, read `docs/llm/DOC_SYNC.md`.
If the change affects users, builders, or maintainers, update the matching human or LLM docs in the same PR.

### ADR requirement

If the PR touches encoding, CID, COSE, ledger, E2E, manifest, limits, conformance, or schemas, an ADR is mandatory.
See `adr/0000-template.md`.

### Dependabot strict lane

Workflow dependency PR automation requires repository secret `DEPENDABOT_AUTOMERGE_TOKEN`.
Missing or insufficient token permissions are fail-closed by policy (`DEPS_ERR_TOKEN_MISSING`, `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS`).
See `docs/human/dependencies-policy.md`.

If you are working in a sandbox where `.git` is readable but not writable, use
`scripts/git-sandbox-safe ...` to run git via a writable mirror in `/tmp`.

### Local hygiene hooks

Run `scripts/setup_local_hygiene.sh` once per clone.
It configures local git hooks that block commits when staged files or commit
messages contain publication-hygiene leaks, and block pushes when the full
repository hygiene checks fail.

## Style

- Use plain language.
- Define terms once.
- Avoid hidden behavior.
- Add negative vectors for any new edge case.
- For any MUST rule, link to the exact NES paragraph.

## Developer Certificate of Origin

If you want a DCO policy, add signoff requirements here.
