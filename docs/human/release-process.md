# Release Process

This is the maintainer runbook for repository milestones and protocol tags.
The goal is simple: keep releases boring, repeatable, and easy to audit.

## Before you start

Make sure all of these are true:

1. Your local tree is clean.
2. `main` is green.
3. The `main protection` ruleset is enabled with the intended settings.
4. Your tag signing key is configured.
5. Your release machine is aligned with the repo pins from `.nvmrc`,
   `mise.toml`, and `core/rust/rust-toolchain.toml`.

Start with:

```bash
./scripts/doctor
./scripts/bootstrap
python3 tools/ci/check_node_runtime_pin.py
python3 tools/ci/check_toolchain_bootstrap.py
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
   - `scripts/sdk/package_client_sdks.sh`
   - `python3 tools/ci/check_sdk_release_package.py --out-dir artifacts/sdk-release/$(git rev-parse HEAD) --expected-commit "$(git rev-parse HEAD)" --require-strict --require-clean`
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
     plus SDK release package assets for the same commit
   - `interop-certify` completed and produced `interop-evidence-<sha>.zip`
   - `golden-images` published digests for `grain-runner` and `grain-certify`
   - `golden-images` ran from the pushed tag, not manual dispatch; any non-tag
     publish path must fail closed with `GOLDEN_ERR_TAG_REQUIRED`
   - the SDK release package includes `manifest.json`, `SHA256SUMS`,
     `sbom.spdx.json`, and source SDK archives, including the TypeScript SDK
     packet, verified by
     `check_sdk_release_package.py --require-strict --require-clean`
   - for `repo-*` tags, image alias `stable` is updated
   - for `repo-rc-*` tags, publish tag is `repo-rc-*` only and must not overwrite `stable`
8. Download and verify the attached release assets as one handoff:
   ```bash
   tag="<tag-name>"
   sha="$(git rev-list -n 1 "$tag")"
   rm -rf "artifacts/release-assets/$tag"
   mkdir -p "artifacts/release-assets/$tag"
   gh release download "$tag" --dir "artifacts/release-assets/$tag"
   python3 tools/ci/check_release_evidence_assets.py \
     --release-dir "artifacts/release-assets/$tag" \
     --expected-commit "$sha" \
     --expected-tag "$tag"
   ```
9. Verify the matching GitHub release entry exists and attached assets are present.
10. If you are checking older imported tags, remember that some historical releases still point to reconstructed notes instead of fully reconstructed assets.

## Release handoff record

For a new release or RC, hand the coordinator these exact values:

- tag name
- tag target commit SHA
- `release-evidence` run URL and result
- `interop-certify` run URL and result
- `evidence-<sha>.zip` asset name
- SDK release package manifest SHA-256 from `SHA256SUMS`
- local output from `check_release_evidence_assets.py`

Do not call the release ready until the signed tag exists, the tag workflows are
green, and the downloaded release assets pass the local handoff check.

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
