# Grain Protocol

Portable, verifiable records for real-world events.
Food is the first production profile in v0.1.

Grain is a protocol plus a conformance suite.
It is not an app, not a hosted platform, and not a global registry.

The goal is simple:
if two independent implementations read the same valid input, they should agree on the bytes, the verdict, and the result.

---

## New Here?

If you are new, start with one of these:

- See the project quickly: `docs/human/start-here.md`
- Run one happy-path demo: `docs/human/quickstart.md`
- Build the smallest possible app: `docs/human/sdk/minimal-app-example.md`
- Build an app on top of Grain: `docs/human/building-on-grain.md`
- Use the SDK path: `docs/human/sdk/start-here.md`
- Implement Grain itself: `docs/human/implementing-grain.md`
- Run release-grade verification: `docs/human/portability-pack.md`

---

## Project Zones

- Onboarding
  - `docs/human/start-here.md`
  - `docs/human/quickstart.md`
  - `docs/human/overview.md`
- Build
  - `docs/human/building-on-grain.md`
  - `docs/human/sdk/start-here.md`
  - `docs/human/sdk/minimal-app-example.md`
  - `core/ts/grain-sdk/README.md`
- Implement
  - `docs/human/implementing-grain.md`
  - `conformance/SPEC.md`
  - `conformance/contract/runner_v1.md`
- Operate
  - `docs/human/portability-pack.md`
  - `docs/human/repro-checklist.md`
  - `docs/human/release-process.md`
- Governance
  - `docs/human/github-hardening.md`
  - `docs/human/dependencies-policy.md`
  - `docs/llm/CHANGE_POLICY.md`
- Vision
  - `docs/human/future-vision.md` (read this after the current-state docs above)

---

## What Grain Guarantees

- Stable, canonical bytes for protocol objects
- Portable verification through CID + COSE
- Deterministic ledger and manifest behavior
- Private sync semantics for encrypted objects
- Strict conformance checks that independent implementations can run

## What Grain Does Not Guarantee

- That the content is true
- That one server or vendor is the source of truth
- That Grain itself is a hosted product platform
- That anything outside strict conformance semantics will interoperate

---

## Status Snapshot

- Protocol v0.1 frozen core: encoding, CID, COSE, ledger, E2E, and manifest rules are locked inside major version 1.
- Conformance suite: shipped in this repo and used as the release gate.
- Rust Core: implemented in `core/rust` and passing the strict suite.
- TypeScript full engine: implemented in `runner/typescript` and checked against the full suite plus drift checks.
- SDK: implemented as a strict primitives layer in `core/ts/grain-sdk`.
- Provenance: CI evidence is commit-bound on `main` and release tags.
- Portability pack: available through `./scripts/certify`.

## Verification paths

Fast local verification on host toolchains:

```bash
./scripts/verify
```

Release-grade certification with deterministic evidence:

```bash
./scripts/certify
```

Compatibility operator alias:

```bash
./scripts/ops/run_verification_pack_v1.sh
```

If you generate evidence, use the exact Node patch version pinned in `.nvmrc`.
Evidence records `node -v`, so floating `22.x` resolution changes `inputs-hashes.json` and the final evidence hash.

Optional fuzz smoke:

```bash
./scripts/certify --fuzz-smoke
```

Conformance statement:
- Passing the full suite in Strict Conformance Mode is the conformance criterion for Grain v0.1.
- A strong interoperability claim becomes valid after two independent full implementations pass the full suite.

---

## Source Of Truth

If two layers disagree, trust them in this order:

1. `spec/NES-v0.1.md` (normative MUST/SHOULD/MAY)
2. `spec/schemas/grain-v0.1.cddl` (machine-readable schemas)
3. `conformance/vectors/` (conformance criterion; release gate)
4. `spec/profiles/` (CBOR/COSE/E2E/QR profiles)
5. `spec/FREEZE-v0.1.md`, `spec/FREEZE-CONFIRMATION-v0.1.md`, `spec/SCOPE-v0.1.md`, `spec/INTEROP-v0.1.md`, `spec/RC-POLICY.md`, `spec/INTEROP-CLAIM.md`, `spec/rc/**`
6. `docs/llm/` (LLM-first indexes and cross-file maps)
7. `adr/` (decision history)
8. `core/rust/`, `runner/typescript/`, `core/` and `sdk/` (implementations)

---

## Deep References

- `conformance/README.md`
- `conformance/SPEC.md`
- `conformance/contract/runner_v1.md`
- `docs/llm/README.md`
- `docs/llm/CONFORMANCE.md`
- `docs/llm/INVARIANTS.md`
- `docs/llm/EDGE_CASES.md`
- `core/ts/grain-sdk/README.md`

---

## Contributing

- `CONTRIBUTING.md`
- `docs/llm/CHANGE_POLICY.md`
- `adr/0000-template.md`

Any PR touching frozen core invariants requires an ADR and will be treated as breaking.

---

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
