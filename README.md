# Grain Protocol

**Open Verifiable Event Infrastructure** — food is the first production profile.

Grain is not an app. Not a platform. Not a global registry.
It’s a **frozen-core protocol** + a **conformance suite** so independent implementations can interoperate **byte-for-byte**.

---

## Status

- **Protocol v0.1:** frozen core (encoding/CID/COSE/ledger/E2E/manifest rules are locked)
- **Conformance Suite:** shipped in this repo (release gate)
- **Grain Core (reference, Rust):** implemented in `core/rust` and passing current v0.1 vectors in strict mode
- **TypeScript full engine:** implemented in `runner/typescript` with full-suite strict mode + divergence checks (C01 profile retained as Wave A smoke lens)
- **GitHub provenance:** CI-generated evidence artifacts are commit-bound (SHA keyed) on `main` and release tags
- **Grain SDK:** implemented as strict universal primitives layer in `core/ts/grain-sdk`
- **Portability pack:** containerized one-command verify path, WASM read/verify smoke, and runner contract compatibility gates

---

## What problem this solves (90 seconds)

Physical-world event data is usually:
- platform-bound (one vendor DB),
- non-verifiable offline (no portable signatures),
- non-deterministic to merge (arrival order / wall-clock dependence),
- privacy-hostile (servers see plaintext identifiers).

Grain v0.1 defines a domain-neutral core:
- **canonical bytes** (strict DAG-CBOR; reject non-canonical; reject duplicate map keys),
- **content IDs** (CIDv1 blessed set),
- **offline verification** (COSE_Sign1 + Ed25519 narrow profile),
- **deterministic merge** (append-only ledger + explicit conflicts),
- **privacy-by-default** (E2E sync; capability addressing; ciphertext is not a CAS-object),
- **forward compatibility** (unknown types stored opaque and forwarded; unknown critical quarantined deterministically).

**Security boundary:** Grain verifies **integrity** and **authorship**. Grain does **not** guarantee that the content is true.

---

## What Grain is

- A strict protocol for immutable, content-addressed objects (**CID**)
- A signed event ledger with deterministic reduction
- An E2E private sync model (capability addressing + manifest resolution)
- An offline QR transport profile (**GR1:**)
- A base layer that can host multiple domain profiles (food profile is first in v0.1)

## What Grain is NOT (v0.1)

- No global registry as canonical truth
- No delegated admin
- No transparency log as MUST
- No trusted global time
- No BigNum / arbitrary precision core
- No social layer
- No “truth” guarantees (signature indicates source, not reality)

---

## Quickstart (5 minutes)

Start with the runnable onboarding flow:
- `docs/human/start-here.md`
- `docs/human/quickstart.md`
- `docs/human/repro-checklist.md`
- `docs/human/portability-pack.md`
- `docs/human/porting-grain.md`
- `docs/human/domain-adapters.md`
- `docs/human/dependencies-policy.md`
- `docs/human/sdk/start-here.md`

One-command deterministic verification from a clean tree:

```bash
./scripts/verify
```

Optional fuzz smoke in the same command path:

```bash
./scripts/verify --fuzz-smoke
```

Conformance statement:
- Passing the full suite in **Strict Conformance Mode** is the conformance criterion for Grain v0.1.
- A strong interoperability claim becomes valid after **two independent full implementations** pass the full suite.

Implementation-entry references:
- `conformance/README.md`
- `conformance/SPEC.md`
- `docs/llm/CONFORMANCE.md`
- `core/ts/grain-sdk/README.md`

TS full engine commands:

```bash
node --experimental-strip-types runner/typescript/scripts/run-full.ts
node --experimental-strip-types runner/typescript/scripts/divergence-full.ts
node --experimental-strip-types runner/typescript/scripts/properties-full.ts
```

### Court Hardening Wave A

Wave A is the byte-level closure pack for court-grade confidence:
- raw CBOR-seq framing vectors for ledger/manifest streams
- HKDF key/nonce expected-bytes vectors
- UTF-8 raw-byte sorting traps
- mixed manifest sequence vectors

See:
- `conformance/SPEC.md`
- `conformance/contract/runner_v1.md`
- `conformance/vectors/**/*-WA-*.json`
- `.github/workflows/ci.yml` (strict CI release gate)
- `.github/workflows/release-evidence.yml` (tag evidence release workflow)
- `.github/workflows/interop-certify.yml` (TOR-CERT-D01 certification gate)
- `.github/workflows/golden-images.yml` (golden container images)

---

## Provenance and release model

- Bundle-era outputs are documented as reconstructed history in `MIGRATION.md`.
- Source provenance is commit-based and CI-anchored (artifact name `evidence-<commit_sha>.zip`).
- Tag namespaces are split:
  - protocol tags: `protocol-*` (schema/invariant line)
  - repo tags: `repo-*` (implementation/tooling/governance milestones)
- Local `.local-architect-reports/**` remains local-only and is never committed.
- Local verification and CI/release evidence share deterministic `evidence_content.sha256` semantics.

## Dependabot strict lane (source repo)

- Workflow updates are auto-merged only through the strict safe lane.
- Repository secret `DEPENDABOT_AUTOMERGE_TOKEN` is mandatory for this lane.
- No fallback token path is allowed; missing/insufficient token fails closed.

---

## Repository map

**Source of truth priority (highest first):**
1. `spec/NES-v0.1.md` (normative MUST/SHOULD/MAY)
2. `spec/schemas/grain-v0.1.cddl` (machine-readable schemas)
3. `conformance/vectors/` (conformance criterion; release gate)
4. `spec/profiles/` (CBOR/COSE/E2E/QR profiles)
5. `spec/FREEZE-v0.1.md`, `spec/FREEZE-CONFIRMATION-v0.1.md`, `spec/SCOPE-v0.1.md`, `spec/INTEROP-v0.1.md`, `spec/RC-POLICY.md`, `spec/INTEROP-CLAIM.md`, `spec/rc/**`
6. `docs/llm/` (LLM-first indexes of invariants and edge cases)
7. `adr/` (decision history)
8. `core/rust/`, `runner/typescript/`, `core/` and `sdk/` (implementations)

---

## Protocol / Core / SDK

- **Protocol:** defines what is valid (bytes, IDs, signatures, ledger/E2E semantics)
- **Conformance:** executable truth (vectors + harness contract)
- **Core:** reference implementation of the protocol
- **SDK:** adoption layer (developer-friendly API), must still pass conformance

---

## Contributing

- `CONTRIBUTING.md`
- `docs/llm/CHANGE_POLICY.md`
- `adr/0000-template.md`

Any PR touching frozen core invariants requires an ADR and will be treated as breaking.

---

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
