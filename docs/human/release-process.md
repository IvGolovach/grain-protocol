# Release Process

This process applies to repository milestones and protocol tags.

Normal flow:
- make sure `main` is green
- run the local verification steps
- cut a signed tag and confirm the release artifacts

RC policy reference:
- `spec/RC-POLICY.md`
- `spec/INTEROP-CLAIM.md`
- `spec/rc/README.md`

## Preconditions

1. Local tree is clean.
2. CI on `main` is green.
3. The `main protection` ruleset is enabled with the intended launch settings.
4. Tag signing key is configured.

## Release steps

1. Sync `main`.
2. Verify local checks:
   - `./scripts/verify --out-dir artifacts/dev-verify-local`
   - `./scripts/certify --out-dir artifacts/verify-local`
   - `cat artifacts/verify-local/evidence/evidence_content.sha256`
   - `python3 tools/ci/check_node_runtime_pin.py`
   - `python3 tools/ci/check_runner_contract_compat.py`
   - `python3 tools/ci/check_prohibition_coverage.py`
   - `python3 tools/ci/check_capid_csprng.py`
   - `cargo build --manifest-path core/rust/Cargo.toml -p grain-core-wasm --target wasm32-wasip1 --release`
   - `npm --prefix runner/typescript run run:wasm-subset`
3. Decide tag type and next version string:
   - protocol release tag: `protocol-vX.Y.Z`
   - repo release tag: `repo-vX.Y.Z`
   - protocol RC tag: `protocol-rc-vX.Y.Z-rcN`
   - repo RC tag: `repo-rc-vX.Y.Z-rcN`
4. Verify tag does not already exist:
   - `git tag --list "<tag-name>"`
5. Create and sign the tag:
   - `git tag -s <tag-name> -m "<tag-message>"`
6. Push tag:
   - `git push origin <tag-name>`
7. Verify tag workflows:
   - `release-evidence` completed and produced `evidence-<sha>.zip`.
   - `interop-certify` completed and produced `interop-evidence-<sha>.zip`.
   - `golden-images` published digests for `grain-runner` and `grain-certify`.
   - for `repo-*` tags, image alias `stable` is updated.
   - for `repo-rc-*` tags, publish tag is `repo-rc-*` only (must not overwrite `stable`).
8. For new tags cut from this repository, verify the matching GitHub release entry exists and attached assets are present.
9. Historical imported milestone tags in this repository now have backfilled GitHub release pages, but older milestones may still point to reconstructed notes instead of fully reconstructed release assets.

## RC stabilization window gate (TOR-RC-STAB-A01)

Before promoting `repo-rc-*` to `repo-v*`, run stabilization checks:

1. PR smoke gate (already in CI `ts-full` context):
   - `python3 tools/stabilization/run_rc_stab.py --mode smoke ...`
2. Deep stabilization (manual during an active RC window):
   - workflow: `.github/workflows/rc-stabilization-deep-check.yml`
   - includes deep fuzz, reproducibility check, rollback rehearsal.
   - scheduled nightly is currently disabled on GitHub and is not part of the live release gate.
3. Review artifacts:
   - `fuzz-report.md`
   - `attack-matrix-results.md`
   - `reproducibility-report.md`
   - `rollback-rehearsal.md`
   - `stabilization-evidence.json`
   - if reproducibility fails, compare `Observed node version` in `reproducibility-report.md` with `.nvmrc`
4. Update tracked decision log:
   - `stabilization/RC-STAB-A01/RESULTS.md`
5. If deep gate fails:
   - do not cut release,
   - revoke RC and cut `repo-rc-...-rc2` on blocker-fix commit.

## Notes

- Protocol and repo tags are intentionally independent.
- Repository provenance note (`MIGRATION.md`) must stay accurate when release workflow changes.
- RC tags are readiness checkpoints, not public launch declarations.
- Historical imported milestone tags in this repository now have backfilled GitHub release pages, but some older milestones still rely on historical evidence references instead of reconstructed GitHub release assets.
- RC rollback uses signed revocation records; history and tags are not rewritten.
