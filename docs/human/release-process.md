# Release Process (Private)

This process applies to repository milestones and protocol tags.

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
   - `cargo test --manifest-path core/rust/Cargo.toml --workspace`
   - `cargo build --manifest-path core/rust/Cargo.toml -p grain-runner`
   - `python3 tools/ci/run_runner_suite.py --vectors-root conformance/vectors --commit-sha "$(git rev-parse HEAD)" --out /tmp/suite-run.json --runner-cmd core/rust/target/debug/grain-runner run --strict --vector`
   - `node --experimental-strip-types runner/typescript/scripts/run-c01.ts`
   - `node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts`
3. Create and sign the tag:
   - `git tag -s protocol-v0.1.1 -m "Protocol v0.1.1"`
   - `git tag -s repo-v0.2.0 -m "Repo v0.2.0"`
   - `git tag -s repo-v0.3.0 -m "Repo v0.3.0"`
4. Push tags.
5. Verify `release-evidence` workflow attached `evidence-<sha>.zip` to the tag release.

## Notes

- Protocol and repo tags are intentionally independent.
- Reconstructed-history disclaimer is mandatory (`MIGRATION.md`).
