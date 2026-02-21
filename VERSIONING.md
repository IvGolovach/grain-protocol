# Versioning

Grain has two version axes:

1) **Protocol schema major** (`v` field inside protocol objects)
   - Defines on-wire and on-disk semantics.
   - v0.1 uses `v = 1` and is **frozen core**.

2) **Repository release version** (SemVer tags)
   - Applies to the repo artifacts: spec text, conformance suite, core, sdk, tooling.
   - Tag namespace:
     - `protocol-*` for protocol-line anchors.
     - `repo-*` for repository milestones.

## What is frozen in Protocol v0.1

See `spec/FREEZE-v0.1.md`.

## Repo SemVer policy

- **PATCH (0.1.x):**
  - clarifications that do not change normative meaning
  - additional vectors/tests that strengthen enforcement
  - docs/tooling improvements
  - implementation bug fixes that move behavior toward conformance

- **MINOR (0.x.0):**
  - additive features that preserve v0.1 frozen invariants:
    - new object `t` types (additive, with schemas + vectors + ADR)
    - new transport profiles with new prefixes (e.g. GR2:)
    - new pairing mechanisms (without changing E2E envelope)
  - no changes to frozen core invariants

- **MAJOR (x.0.0):**
  - protocol breaking changes (requires new protocol schema major)
  - any change to frozen core invariants

## Provenance requirement

- Releases are valid only when CI evidence artifacts are bound to commit SHA.
- Reconstructed bundle history is disclosed in `MIGRATION.md`.
