# Start Here

## If you are new

Read this page first if you want the shortest path into the repo.

## 90-second orientation

Grain is a protocol for recording physical events in a way other tools can verify later.
Food is the first shipped profile in v0.1.

What Grain gives you:
- Stable bytes for hashes and signatures.
- Portable verification without a central API.
- Deterministic results when the same valid input is reduced again.

What Grain does not give you:
- Truth of content.
- A global registry.
- A hosted product platform.

If you want the longer product direction, read [Future Vision](./future-vision.md).

## Choose your path

If you only read one more page, read [Quickstart](./quickstart.md).

- [Quickstart: run the demo first](./quickstart.md)
- [Build the smallest app with the SDK](./sdk/minimal-app-example.md)
- [Build an app on Grain](./building-on-grain.md)
- [Use the SDK primitives](./sdk/start-here.md)
- [Implement Grain itself](./implementing-grain.md)
- [Run release-grade portability verification](./portability-pack.md)
- [Read the future vision](./future-vision.md)

## Verification paths

- `./scripts/verify` is the fast local check on host toolchains.
- `./scripts/certify` is the clean-tree, containerized evidence path.
- `./scripts/ops/run_verification_pack_v1.sh` is the operator alias for certification.

## Current status snapshot

- Protocol: frozen v0.1 core (`schema_major=1`).
- Conformance: vectors are the execution gate.
- Reference implementation: Rust Core passes strict suite.
- TypeScript: full strict engine is available; `C01` is the small smoke profile kept for byte-path regressions.
- SDK: TypeScript universal primitives layer is available at `core/ts/grain-sdk`.

Repo shorthand you may see later:
- `NES` = the normative spec file `spec/NES-v0.1.md`
- `C01` = the small TypeScript smoke profile, not the main conformance criterion
