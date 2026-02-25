# Release Process (Private)

This process applies to repository milestones and protocol tags.

RC policy reference:
- `spec/RC-POLICY.md`
- `spec/INTEROP-CLAIM.md`
- `spec/rc/README.md`

## Preconditions

1. Local tree is clean.
2. CI on `main` is green.
3. Branch protection is enabled with the intended profile:
   - private mode baseline: `PROTECTION_PROFILE=autonomous`
   - public reviewed mode: `PROTECTION_PROFILE=reviewed`
4. Tag signing key is configured.

## Release steps

1. Sync `main`.
2. Verify local checks:
   - `python3 tools/validate_vectors.py`
   - `python3 tools/check_llm_docs.py`
   - `python3 tools/check_spec_drift.py`
   - `python3 tools/ci/check_gitattributes_policy.py`
   - `python3 tools/ci/check_forbidden_tracked.py`
   - `python3 tools/ci/check_crlf_tracked.py`
   - `cargo test --manifest-path core/rust/Cargo.toml --workspace`
   - `cargo build --manifest-path core/rust/Cargo.toml -p grain-runner`
   - `python3 tools/ci/run_runner_suite.py --vectors-root conformance/vectors --commit-sha "$(git rev-parse HEAD)" --out /tmp/suite-run.json --runner-cmd core/rust/target/debug/grain-runner run --strict --vector`
   - `node --experimental-strip-types runner/typescript/scripts/run-c01.ts`
   - `node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts`
   - `node --experimental-strip-types runner/typescript/scripts/run-full.ts`
   - `node --experimental-strip-types runner/typescript/scripts/divergence-full.ts`
   - `node --experimental-strip-types runner/typescript/scripts/properties-full.ts`
   - `tools/interop_certify.sh --out-dir /tmp/interop-cert --commit-sha "$(git rev-parse HEAD)"`
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
   - `release-evidence` attached `evidence-<sha>.zip`.
   - `interop-certify` attached `interop-evidence-<sha>.zip`.
8. For release tags (`protocol-*`, `repo-*`), verify GitHub release entry and attached assets.

## Notes

- Protocol and repo tags are intentionally independent.
- Reconstructed-history disclaimer is mandatory (`MIGRATION.md`).
- RC tags are readiness checkpoints, not GA/public release declarations.
- RC rollback uses signed revocation records; history and tags are not rewritten.
