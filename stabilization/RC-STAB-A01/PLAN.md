# TOR-RC-STAB-A01 Historical Plan

This file records the historical stabilization plan for the imported
`repo-rc-v0.4.0-rc1` window. It is reference material, not the current live
release gate for `main`.

## 1) Baseline anchors
- Protocol tag: `protocol-v0.1.1` (frozen core, unchanged).
- RC tag under stabilization: `repo-rc-v0.4.0-rc1`.
- RC baseline evidence hash: `35475fd1767ec873a4bfa46c51ffffd23843831e21df5c17db0e5d2162b3a1bd`.
- Expected baseline suite posture: Rust full `60/60`, TS full `60/60`, divergence full `0`.

## 2) Goals
- Pressure-test RC candidate without changing frozen-core semantics.
- Detect byte-level parser failures, semantic divergence, and release-process regressions.
- Produce reproducible evidence and explicit PASS/FAIL decision for `rc1` vs `rc2`.

## 3) In scope
- Byte-level and property-based stabilization checks via `tools/stabilization/run_rc_stab.py`.
- Attack matrix execution with deterministic expected outcomes.
- PR smoke stabilization gate and manual deep stabilization runs for that RC window.
- Reproducibility drill from clean clone on RC tag.
- Rollback rehearsal (non-destructive, revocation-first model).

## 4) Out of scope
- Any frozen-core semantic change in `spec/`.
- Any conformance expected-output bending for implementation convenience.
- New product features, performance tuning, or public GA release changes.

## 5) Execution phases
1. Smoke (required on PR):
   - Attack matrix
   - Mutational byte-level fuzz smoke budget
   - Rust+TS property checks
2. Deep (manual during an active RC window):
   - Expanded mutational campaigns
   - Reproducibility check against RC baseline hash
   - Rollback rehearsal checks against release metadata
   - scheduled nightly is currently disabled on GitHub
3. Regression capture:
   - Every crash/divergence must have minimized repro and deterministic guard.

## 6) Acceptance gates
All MUST be true:
- `attack_matrix_pass=true`
- `fuzz_no_crash_or_divergence=true`
- `properties_pass=true`
- `repro_pass=true` (deep only)
- `rollback_rehearsal_pass=true` (deep only)

### Addendum A02 (non-breaking)
- Reproducibility lane MUST include SDK strict suite summary when SDK is present in required CI contexts (`ts-full` path).
- Stabilization runner MUST enforce `INV-STAB-001`:
  cleanup failures are warning-only (`STAB_CLEANUP_WARN`) and MUST NOT flip protocol verdict.

## 7) Outputs
Tracked docs:
- `stabilization/RC-STAB-A01/PLAN.md`
- `stabilization/RC-STAB-A01/ATTACK_MATRIX.md`
- `stabilization/RC-STAB-A01/PROPERTIES.md`
- `stabilization/RC-STAB-A01/REPRO_CHECKLIST.md`
- `stabilization/RC-STAB-A01/RESULTS.md`

CI artifacts:
- `fuzz-report.md`
- `attack-matrix-results.md`
- `reproducibility-report.md`
- `rollback-rehearsal.md`
- `stabilization-evidence.json`
- `minimized-repros.zip` + `minimized-repros.sha256`
