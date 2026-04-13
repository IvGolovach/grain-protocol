# Start Here

If you want the shortest path into the repo, this is the page.
Pick one path, get one win, and only then go deeper.

## 90-second orientation

Grain is a protocol for recording physical events in a way other tools can verify later.
Food is the first shipped profile in v0.1.

What Grain gives you:

- Stable bytes for hashes and signatures
- Portable verification without a central API
- Deterministic results when the same valid input is reduced again

What Grain does not give you:

- Truth of content
- A global registry
- A hosted product platform

If you want the longer product direction, read [Future Vision](./future-vision.md) later.

## Choose your path

If you only read one more page, read [Quickstart](./quickstart.md).

- [Quickstart: run the demo first](./quickstart.md)
- [Build the smallest app with the SDK](./sdk/minimal-app-example.md)
- [Build an app on Grain](./building-on-grain.md)
- [Use the SDK primitives](./sdk/start-here.md)
- [Implement Grain itself](./implementing-grain.md)
- [Maintainer path: keep the repo healthy](./maintainer-start-here.md)
- [Run release-grade portability verification](./portability-pack.md)
- [Read the future vision](./future-vision.md)

## Verification paths

Blessed local bootstrap:

- `./scripts/bootstrap`

Quick health view:

- `./scripts/doctor`

Fast local verification:

- `./scripts/verify`

Release-grade certification:

- `./scripts/certify`

Compatibility alias:

- `./scripts/ops/run_verification_pack_v1.sh`

## Current status snapshot

- Protocol: stable v0.1 core (`schema_major=1`)
- Conformance: vectors are the execution gate
- Reference implementation: Rust Core passes the strict suite
- TypeScript: the full strict engine is available; `C01` is the smaller smoke profile for byte-path regressions
- SDK: the TypeScript primitives layer lives in `core/ts/grain-sdk`

Repo shorthand you may see later:

- `NES` = the normative spec file `spec/NES-v0.1.md`
- `C01` = the small TypeScript smoke profile, not the main conformance criterion

You can ignore both on your first pass unless you are working on the protocol itself.
