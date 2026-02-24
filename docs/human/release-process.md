# Release Process (Private)

This process applies to repository milestones and protocol tags.

RC policy reference:
- `spec/RC-POLICY.md`
- `spec/INTEROP-CLAIM.md`
- `spec/rc/README.md`

## Preconditions

1. Local tree is clean.
2. CI on `main` is green.
3. Branch protection is enabled.
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
3. Create and sign tags:
   - `git tag -s protocol-v0.1.1 -m "Protocol v0.1.1"`
   - `git tag -s repo-v0.2.0 -m "Repo v0.2.0"`
   - `git tag -s repo-v0.3.0 -m "Repo v0.3.0"`
   - RC tags (when applicable):
     - `git tag -s protocol-rc-v0.1.1-rc1 -m "Protocol RC v0.1.1-rc1"`
     - `git tag -s repo-rc-v0.3.1-rc1 -m "Repo RC v0.3.1-rc1"`
4. Push tags.
5. Verify tag workflows:
   - `release-evidence` attached `evidence-<sha>.zip`.
   - `interop-certify` attached `interop-evidence-<sha>.zip`.

## Notes

- Protocol and repo tags are intentionally independent.
- Reconstructed-history disclaimer is mandatory (`MIGRATION.md`).
- RC tags are readiness checkpoints, not GA/public release declarations.
- RC rollback uses signed revocation records; history and tags are not rewritten.
