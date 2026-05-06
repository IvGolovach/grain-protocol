# Real App Release Execution

Date: 2026-05-06
Branch: `codex/real-app-release-slices`
Base: `origin/main` at `95e121917fa2c504fa5b43214cd22eec33c1d6c7`

## Goal

Complete the next professional path after the Rust core plus generated platform
SDK roadmap:

1. Align the release machine path.
2. Cut or prepare the next verifiable release handoff.
3. Verify release evidence and SDK source package assets.
4. Add the first real iOS app slice.
5. Add Android parity for the app slice.
6. Make developer distribution and onboarding usable from one SDK SHA.

## Operating Rules

- Preserve the dirty primary checkout; do all work in this clean worktree.
- Keep future apps thin: platform code owns sensors, local trust policy,
  protected storage, and transfer channels; Grain owns parsing, verification,
  diagnostics, workflow mutation, rollback, pairing, sync, and snapshots.
- Prefer multiple reviewable PRs if one branch becomes too broad.
- Run targeted local validation before pushing; rely on required GitHub CI for
  final full-platform proof.
- Do not claim store/registry production release unless the tag and release
  assets actually exist.

## Work Slices

| Step | Slice | Status | Proof |
| --- | --- | --- | --- |
| 1 | Release machine alignment | Implemented locally | `./scripts/bootstrap`: PASS; `mise exec -- scripts/sdk/doctor`: pinned Node/Python/wasm target present |
| 2 | Release/tag handoff readiness | Implemented locally | `docs/human/release-process.md` now records post-tag asset handoff and coordinator fields |
| 3 | Release evidence verification | Implemented locally | `python3 -m unittest tools.ci.test_check_release_evidence_assets`: PASS |
| 4 | iOS real-app slice | Implemented locally | `scripts/sdk/verify_all_sdks.sh --strict`: PASS, includes iOS smoke |
| 5 | Android parity app slice | Implemented locally | `scripts/sdk/verify_all_sdks.sh --strict`: PASS, includes Android smoke |
| 6 | Developer distribution handoff | Implemented locally | `docs/human/sdk/source-sdk-handoff.md` plus linked SDK/example entrypoints |

## Agent Assignments

| Agent | Scope |
| --- | --- |
| Descartes | Release handoff and tag-readiness |
| Pasteur | iOS app slice |
| Kuhn | Android parity app slice |
| Ampere | Developer distribution and quickstart |
| Pascal | Verification gap audit and CI guards |

## Execution Log

- 2026-05-06: Plan created from clean `main` worktree. Five agents dispatched
  with disjoint write scopes.
- 2026-05-06: Ran `./scripts/bootstrap`: PASS. Under `mise exec`, Node is
  `v22.22.0`, Python is `3.11.15`, and `wasm32-wasip1` is installed. SDK doctor
  policy checks pass; the remaining readiness warning is the expected missing
  source release package for the current work-in-progress commit.
- 2026-05-06: Integrated five agent slices: release handoff verifier, iOS camera
  handoff shell, Android camera/InputStream parity shell, source SDK handoff
  docs, and SDK source archive secret guard tests.
- 2026-05-06: Fixed an integration issue where the release evidence verifier
  passed as a direct script but failed under `python3 -m unittest` import mode.
- 2026-05-06: Local targeted validation is green for docs, SDK policy guards,
  release guard unit tests, generated bindings, Rust client core, and scanner
  examples. A real signed tag and downloaded release assets still belong after
  the PR is merged and the tag workflows exist.
- 2026-05-06: Final integrated SDK validation passed with
  `mise exec -- env JAVA_HOME=<arm64-openjdk17-home> scripts/sdk/verify_all_sdks.sh --strict --out-dir artifacts/sdk-verify-all-roadmap-final`.
  The gate covered Rust client workflow tests, fixtures, generated bindings,
  docs/policy guards, WASM, Swift, Kotlin, and reference scanner examples.
- 2026-05-06: PR #57 merged to `main` at
  `e5d32ebf5591d5e79c097a1257f2cdd9086c0eb4`; post-merge `main` CI run
  `25450444691` passed.
- 2026-05-06: Signed RC tag `repo-rc-v0.4.0-rc2` was pushed for
  `e5d32ebf5591d5e79c097a1257f2cdd9086c0eb4`. `interop-certify` passed on
  run `25451350651`. `golden-images` exposed a release-tooling blocker: GHCR
  image refs used mixed-case repository owner text, which Docker rejects before
  build/push. The fix is tracked as a narrow CI/release-tooling slice before
  cutting the next signed RC tag.
- 2026-05-06: `release-evidence` run `25451350637` passed and attached the
  expected source SDK/evidence assets to `repo-rc-v0.4.0-rc2`. Downloaded asset
  verification then exposed a handoff-verifier shape mismatch: the aggregate
  suite summary embeds SDK counts, while `sdk-suite-summary.json` carries the
  richer SDK runner metadata. The verifier fix is part of the same
  release-tooling slice before the next signed RC tag.
- 2026-05-06: Signed RC tag `repo-rc-v0.4.0-rc3` was pushed for
  `a9b2ad0857ccec21493f98d3bcd9b74613449b5a` after PR #58 merged and
  post-merge `main` CI run `25452377643` passed. `interop-certify` passed on
  run `25452731721`. `golden-images` progressed past owner casing and exposed
  two remaining blockers: `grain-runner` built from an incomplete Rust
  workspace/conformance copy, and GHCR returned `403 Forbidden` while pushing
  `grain-certify`. The workspace/conformance-copy fix is tracked before
  cutting the next signed RC tag; the GHCR package-access failure may still
  require repository package permission repair outside the codebase if it
  persists.
- 2026-05-06: Signed RC tag `repo-rc-v0.4.0-rc4` was pushed for
  `052fc9fac19952ba9466f8db001ee15bcbdc2a05` after PR #59 merged and
  post-merge `main` CI run `25453609947` passed. `release-evidence` passed on
  run `25454024026` and `interop-certify` passed on run `25454024031`.
  `golden-images` confirmed both Dockerfiles build far enough to publish, then
  failed on GHCR `403 Forbidden` while pushing account-level image names for
  both `grain-runner` and `grain-certify`. The next slice moves golden image
  publication to a repo-scoped GHCR namespace before cutting another RC tag.
