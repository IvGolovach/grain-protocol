# Contributing

Grain is protocol-first. Contributions are welcome, but the project has a strict stance on interoperability and stability.

## Ground rules

- Protocol v0.1 is frozen core. Do not submit breaking changes unless explicitly proposing a new protocol major version.
- Every change must have rationale. If it's not explainable, it's not mergeable.
- Conformance suite is a release gate. If conformance fails, the PR does not merge.

## Where to start

- `README.md`
- `docs/human/overview.md`
- `docs/llm/FILE_MAP.md`
- `docs/llm/INVARIANTS.md`
- `conformance/README.md`

## Pull Requests

Use the PR template. You must answer:
- What changed?
- Why?
- Which invariants are touched (IDs)?
- Which conformance vectors are affected?
- Is this breaking?

### ADR requirement

If the PR touches encoding/CID/COSE/ledger/E2E/manifest/limits/conformance/schemas, an ADR is mandatory.
See `adr/0000-template.md`.

### Dependabot strict lane

Workflow dependency PR automation requires repository secret `DEPENDABOT_AUTOMERGE_TOKEN`.
Missing or insufficient token permissions are fail-closed by policy (`DEPS_ERR_TOKEN_MISSING`, `DEPS_ERR_TOKEN_INSUFFICIENT_PERMS`).
See `docs/human/dependencies-policy.md`.

## Style

- Keep docs and code explicit. Avoid “magic” behavior.
- Add negative vectors for any new edge case.
- For any MUST rule, link to the exact NES paragraph.

## Developer Certificate of Origin (optional)

If you want a DCO policy, add SIGNOFF requirements here.
