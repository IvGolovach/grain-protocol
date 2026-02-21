# Grain Core (reference implementation)

Status: active.

Rust reference implementation lives in:
- `core/rust/grain-core` (library)
- `core/rust/grain-runner` (conformance runner CLI)

Conformance contract:
- runner command: `grain-runner run --strict --vector <path>`
- strict mode is mandatory for v0.1 vectors

Quick entrypoints:
- `core/rust/README.md`
- `core/rust/grain-core/docs/errors.md`

Hard requirement:
- implementation behavior MUST track `spec/NES-v0.1.md` + `conformance/vectors/**`
