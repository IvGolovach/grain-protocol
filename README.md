# Grain Protocol

**Open Food Infrastructure** — a neutral, verifiable language for food events.

Grain is not an app. Not a platform. Not a global registry.
It’s a **frozen-core protocol** + a **conformance suite** so independent implementations can interoperate **byte-for-byte**.

---

## Status

- **Protocol v0.1:** frozen core (encoding/CID/COSE/ledger/E2E/manifest rules are locked)
- **Conformance Suite:** shipped in this repo (release gate)
- **Grain Core (reference, Rust):** implemented in `core/rust` and passing current v0.1 vectors in strict mode
- **TypeScript runner (smoke):** implemented in `runner/typescript` for C01 (Wave A) cross-language probing
- **GitHub provenance:** CI-generated evidence artifacts are commit-bound (SHA keyed) on `main` and release tags
- **Grain SDK:** planned / in progress

---

## What problem this solves (90 seconds)

Food data is usually:
- platform-bound (one vendor DB),
- non-verifiable offline (no portable signatures),
- non-deterministic to merge (arrival order / wall-clock dependence),
- privacy-hostile (servers see plaintext identifiers).

Grain v0.1 defines:
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

This repository is protocol-first. The fastest way to engage is via the conformance suite.

**Conformance statement:** Passing the full conformance suite in **Strict Conformance Mode** is the conformance criterion for Grain v0.1.
A strong interoperability claim becomes valid after **two independent implementations** pass the full suite.

```bash
# Read the harness contract (how any implementation plugs in)
cat conformance/SPEC.md

# See the mandatory vectors (positive + negative)
find conformance/vectors -maxdepth 3 -type f | sort

# Run the Rust reference runner against one vector
docker run --rm -v "$PWD":/work -w /work/core/rust rust:1.86 \
  bash -lc 'export PATH=/usr/local/cargo/bin:$PATH; cargo run -q -p grain-runner -- run --strict --vector /work/conformance/vectors/cid/POS-CID-001.json'

# Run the full vector set (strict mode)
docker run --rm -v "$PWD":/work -w /work/core/rust rust:1.86 \
  bash -lc 'export PATH=/usr/local/cargo/bin:$PATH; for v in $(find /work/conformance/vectors -name "*.json" | sort); do cargo run -q -p grain-runner -- run --strict --vector "$v" >/dev/null; done'

# Run TS C01 smoke (all Wave A vectors)
node --experimental-strip-types runner/typescript/scripts/run-c01.ts

# Build Rust↔TS divergence report for C01
node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts
```

If you have an implementation and want to certify v0.1 compatibility, start here:
- `conformance/README.md`
- `docs/llm/CONFORMANCE.md`

### Court Hardening Wave A

Wave A is the byte-level closure pack for court-grade confidence:
- raw CBOR-seq framing vectors for ledger/manifest streams
- HKDF key/nonce expected-bytes vectors
- UTF-8 raw-byte sorting traps
- mixed manifest sequence vectors

See:
- `conformance/SPEC.md`
- `conformance/vectors/**/*-WA-*.json`
- `.github/workflows/ci.yml` (strict CI release gate)
- `.github/workflows/release-evidence.yml` (tag evidence release workflow)

---

## Provenance and release model

- Bundle-era outputs are documented as reconstructed history in `MIGRATION.md`.
- Source provenance is commit-based and CI-anchored (artifact name `evidence-<commit_sha>.zip`).
- Tag namespaces are split:
  - protocol tags: `protocol-*` (schema/invariant line)
  - repo tags: `repo-*` (implementation/tooling/governance milestones)
- Local `.local-architect-reports/**` remains local-only and is never committed.

---

## Repository map

**Source of truth priority (highest first):**
1. `spec/NES-v0.1.md` (normative MUST/SHOULD/MAY)
2. `spec/schemas/grain-v0.1.cddl` (machine-readable schemas)
3. `conformance/vectors/` (conformance criterion; release gate)
4. `spec/profiles/` (CBOR/COSE/E2E/QR profiles)
5. `docs/llm/` (LLM-first indexes of invariants and edge cases)
6. `adr/` (decision history)
7. `core/rust/`, `runner/typescript/`, `core/` and `sdk/` (implementations)

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
