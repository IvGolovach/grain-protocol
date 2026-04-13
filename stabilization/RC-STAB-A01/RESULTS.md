# TOR-RC-STAB-A01 Historical Results

This file is the historical decision log for the imported
`repo-rc-v0.4.0-rc1` stabilization window.

## Baseline snapshot
- Protocol anchor: `protocol-v0.1.1`
- RC anchor: `repo-rc-v0.4.0-rc1`
- Baseline evidence hash: `35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd`
- Baseline release evidence source: historical artifact references for `repo-rc-v0.4.0-rc1` (release page backfilled later; original release assets were not reconstructed)
- Baseline interop evidence source: historical artifact references for `repo-rc-v0.4.0-rc1` (release page backfilled later; original release assets were not reconstructed)

## Latest stabilization execution
Latest imported deep run on the public-candidate mainline:

- Run mode: `deep`
- Commit: `1707b071b309e4693ad59fc8d4e26513ec9139a7`
- Verdict: `FAIL`
- Gates:
  - `attack_matrix_pass=true`
  - `fuzz_no_crash_or_divergence=true`
  - `properties_pass=true`
  - `repro_pass=false`
  - `rollback_rehearsal_pass=false`
- Artifact hash anchors:
  - `minimized-repros.sha256`: recorded in the imported deep-run artifact bundle
  - `content_digest_sha256=ef21bb875cfa2d063e692f2054499a361052e7b5859e7023341d8cf1377da3ee`

Notes:
- reproducibility failed because the observed evidence hash did not match the imported RC baseline hash
- rollback rehearsal failed because release metadata for `repo-rc-v0.4.0-rc1` was not backfilled in this repository at the time of the historical run

## Historical decision rule
- If all gates pass in deep mode:
  - candidate is ready for `repo-v0.4.0` cut.
- If any blocker fails:
  - mark `repo-rc-v0.4.0-rc1` as revoked in `spec/rc/REVOCATIONS/`
  - cut `repo-rc-v0.4.0-rc2` on blocker-fix commit
  - rerun full stabilization window.

## Stabilization invariants
- `INV-STAB-001`: cleanup failures in stabilization infrastructure are warning-only and MUST NOT flip protocol verdict.
  - Protocol verdict still depends only on attack/fuzz/properties/repro/rollback gates.
  - Cleanup state is tracked in `stabilization-evidence.json.cleanup`.
- Addendum A02: when SDK strict suite is part of required CI context, deep reproducibility includes SDK strict-suite parity checks in evidence review.
