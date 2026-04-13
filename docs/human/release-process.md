# Release Process

This is the maintainer runbook for repository milestones and protocol tags.
The goal is simple: keep releases boring, repeatable, and easy to audit.

## Before you start

Make sure all of these are true:

1. Your local tree is clean.
2. `main` is green.
3. The `main protection` ruleset is enabled with the intended settings.
4. Your tag signing key is configured.

Start with:

```bash
./scripts/doctor
./scripts/bootstrap
```

## Normal release flow

1. Sync `main`.
2. Run the local checks:
   - `./scripts/verify --out-dir artifacts/dev-verify-local`
   - `./scripts/certify --out-dir artifacts/verify-local`
   - `cat artifacts/verify-local/evidence/evidence_content.sha256`
   - `python3 tools/ci/check_node_runtime_pin.py`
   - `python3 tools/ci/check_toolchain_bootstrap.py`
   - `python3 tools/ci/check_runner_contract_compat.py`
   - `python3 tools/ci/check_prohibition_coverage.py`
   - `python3 tools/ci/check_capid_csprng.py`
   - `cargo build --manifest-path core/rust/Cargo.toml -p grain-core-wasm --target wasm32-wasip1 --release`
   - `npm --prefix runner/typescript run run:wasm-subset`
3. Pick the tag type and version:
   - protocol release tag: `protocol-vX.Y.Z`
   - repo release tag: `repo-vX.Y.Z`
   - protocol RC tag: `protocol-rc-vX.Y.Z-rcN`
   - repo RC tag: `repo-rc-vX.Y.Z-rcN`
4. Confirm the tag does not already exist:
   - `git tag --list "<tag-name>"`
5. Create and sign the tag:
   - `git tag -s <tag-name> -m "<tag-message>"`
6. Push the tag:
   - `git push origin <tag-name>`
7. Verify the tag workflows:
   - `release-evidence` completed and produced `evidence-<sha>.zip`
   - `interop-certify` completed and produced `interop-evidence-<sha>.zip`
   - `golden-images` published digests for `grain-runner` and `grain-certify`
   - for `repo-*` tags, image alias `stable` is updated
   - for `repo-rc-*` tags, publish tag is `repo-rc-*` only and must not overwrite `stable`
8. Verify the matching GitHub release entry exists and attached assets are present.
9. If you are checking older imported tags, remember that some historical releases still point to reconstructed notes instead of fully reconstructed assets.

## RC stabilization window gate (TOR-RC-STAB-A01)

Before promoting `repo-rc-*` to `repo-v*`, run the stabilization checks.

1. PR smoke gate:
   - already runs in CI under the `ts-full` context
   - command family: `python3 tools/stabilization/run_rc_stab.py --mode smoke ...`
2. Deep stabilization during an active RC window:
   - workflow: `.github/workflows/rc-stabilization-deep-check.yml`
   - includes deep fuzz, reproducibility check, and rollback rehearsal
   - nightly deep runs are currently disabled on GitHub and are not part of the live release gate
3. Review the artifacts:
   - `fuzz-report.md`
   - `attack-matrix-results.md`
   - `reproducibility-report.md`
   - `rollback-rehearsal.md`
   - `stabilization-evidence.json`
   - if reproducibility fails, compare `Observed node version` in `reproducibility-report.md` with `.nvmrc`
4. Update the tracked decision log:
   - `stabilization/RC-STAB-A01/RESULTS.md`
5. If the deep gate fails:
   - do not cut the release
   - revoke the RC
   - cut `repo-rc-...-rc2` on the blocker-fix commit

## Notes

- Protocol and repo tags are intentionally independent.
- `MIGRATION.md` must stay accurate when release workflow details change.
- RC tags are readiness checkpoints, not launch announcements.
- RC rollback uses signed revocation records. History and tags are not rewritten.
