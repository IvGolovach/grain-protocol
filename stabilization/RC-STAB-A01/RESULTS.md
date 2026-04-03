# TOR-RC-STAB-A01 Results

This file is the tracked decision log for the RC stabilization window.

## Baseline snapshot
- Protocol anchor: `protocol-v0.1.1`
- RC anchor: `repo-rc-v0.4.0-rc1`
- Baseline evidence hash: `35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd`
- Baseline release evidence source: published release artifacts for `repo-rc-v0.4.0-rc1`
- Baseline interop evidence source: published interop artifacts for `repo-rc-v0.4.0-rc1`

## Latest stabilization execution
Update this section from CI artifact `stabilization-evidence.json` after each deep run.

- Run mode: `smoke` / `deep`
- Commit: `<fill-from-artifact>`
- Verdict: `<PASS|FAIL>`
- Gates:
  - `attack_matrix_pass=<bool>`
  - `fuzz_no_crash_or_divergence=<bool>`
  - `properties_pass=<bool>`
  - `repro_pass=<bool|n/a(smoke)>`
  - `rollback_rehearsal_pass=<bool|n/a(smoke)>`
- Artifact hash anchors:
  - `minimized-repros.sha256=<value>`
  - `content_digest_sha256=<value>`

## Decision branch
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
