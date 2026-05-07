# SDK Release Assets Dirty Checkout Inventory

This inventory is read-only. The primary Grain checkout was not reset, cleaned,
stashed, restored, or otherwise mutated.

## Source State

- Checkout: primary Grain checkout
- Branch: `codex/sdk-release-assets`
- Branch HEAD: `d9bd721e86b04fe067398746f051f0dda508d056`
- Current `origin/main`: `08b858e8ee0f4043c7257ed5cd612d48c6f36b97`
- Relationship: the dirty checkout is based before the merged real-app SDK
  roadmap and before `repo-v0.4.2`.

## Conclusion

Do not use this checkout as an implementation base. Treat it as a stale
pre-merge scratch branch unless a specific path is manually cherry-picked after
comparison against `origin/main`.

The large `git diff origin/main --` is dominated by apparent deletions of files
that now exist on `main`, including:

- `core/rust/grain-issuer-kit/**`
- `sdk/trust/**`
- `examples/ios-reference-app/**`
- `examples/android-reference-app/**`
- `scripts/sdk/doctor`
- `scripts/sdk/check_ios_reference_app.sh`
- `scripts/sdk/check_android_reference_app.sh`
- `tools/ci/check_external_sdk_handoff.py`
- `tools/ci/check_release_evidence_assets.py`
- `tools/ci/check_real_app_docs.py`
- `docs/human/sdk/source-sdk-handoff.md`
- `docs/human/sdk/scan-quickstart.md`
- `docs/human/sdk/distribution-roadmap.md`
- `docs/human/sdk/custody-threat-model.md`

Those files are present on `origin/main`, so the deletion view is a branch-age
artifact, not a useful cleanup proposal.

## Path Classification

| Group | Category | Reason | Action |
| --- | --- | --- | --- |
| `core/rust/grain-issuer-kit/**` | Already merged / stale local view | Added in later roadmap commits and present on `origin/main`. | Do not port from dirty checkout. Use `origin/main`. |
| `sdk/trust/**` | Already merged / stale local view | Trust bundle schema and fixture are present on `origin/main`. | Do not port from dirty checkout. Use `origin/main`. |
| `examples/ios-reference-app/**` | Already merged / stale local view | iOS reference app is present on `origin/main`. | Do not port from dirty checkout. Use `origin/main`. |
| `examples/android-reference-app/**` | Already merged / stale local view | Android reference app is present on `origin/main`. | Do not port from dirty checkout. Use `origin/main`. |
| `tools/ci/check_external_sdk_handoff.py` and tests | Already merged / stale local view | External SDK handoff checker is present and passed release validation on `repo-v0.4.2`. | Do not port from dirty checkout. |
| `tools/ci/check_release_evidence_assets.py` and tests | Already merged / stale local view | Release asset checker is present and passed downloaded `repo-v0.4.2` assets. | Do not port from dirty checkout. |
| `scripts/sdk/doctor` | Already merged / stale local view | SDK doctor exists on `origin/main` and currently reports policy PASS with local readiness WARN. | Do not port from dirty checkout. |
| `.github/**`, `scripts/sdk/**`, `docs/**`, `sdk/**`, `examples/**` modified paths | Uncertain but high-risk stale | They were edited before later PRs and conflict with current verified `origin/main` state. | Ignore by default. Re-open only if a path contains a named feature not present on `origin/main`. |
| `.dockerignore`, `adr/sdk/0005-reference-issuer-kit.md`, `docs/superpowers/plans/2026-05-06-real-app-release-execution.md` apparent deletions | Obsolete cleanup candidate only after review | The dirty branch shows deletions relative to current main, but the deletion set is not trustworthy as a patch. | Do not apply. If cleanup is needed, create a separate fresh PR from `origin/main`. |

## Recommended Cleanup Policy

1. Keep all current work on clean worktrees from `origin/main`.
2. Do not merge or rebase `codex/sdk-release-assets` into the new work.
3. After this plan finishes, archive or delete the stale branch only with an
   explicit user cleanup request.
4. If a specific stale path becomes interesting, inspect that path with
   `git diff codex/sdk-release-assets -- <path>` from a clean worktree and port
   only the minimal still-useful hunk.
