# Quickstart

This repository is protocol-first. The fastest path is to understand conformance.

## 1) Read the protocol boundaries
- `README.md` (what Grain is / is not)
- `spec/FREEZE-v0.1.md` (what is frozen)

## 2) Read conformance contract
- `conformance/SPEC.md` (runner interface)
- `docs/llm/CONFORMANCE.md` (how invariants map to vectors)

## 3) Inspect v0.1 invariants
- `docs/llm/INVARIANTS.md`
- `docs/llm/EDGE_CASES.md`

## 4) Build or plug an implementation
Your implementation must:
- decode/encode strict DAG-CBOR
- compute CIDv1 (dag-cbor + sha2-256)
- verify COSE_Sign1 narrow profile (Ed25519)
- apply ledger + E2E + manifest semantics deterministically
- run in Strict Conformance Mode (baseline limits)

Then run the conformance suite harness (see `conformance/SPEC.md`).

### Rust reference implementation (available now)

`core/rust` ships a reference runner compatible with the harness contract.

```bash
docker run --rm -v "$PWD":/work -w /work/core/rust rust:1.86 \
  bash -lc 'export PATH=/usr/local/cargo/bin:$PATH; cargo run -q -p grain-runner -- run --strict --vector /work/conformance/vectors/cid/POS-CID-001.json'
```

### TypeScript smoke runner (C01 / Wave A)

```bash
node --experimental-strip-types runner/typescript/scripts/run-c01.ts
node --experimental-strip-types runner/typescript/scripts/divergence-c01.ts
```

## 5) Court-hardening Wave A checks (byte-level)
Wave A is the mandatory byte-path closure before protocol implementations claim court-grade confidence.

Read:
- `conformance/SPEC.md` (ops `parse_cborseq_stream_v1`, `e2e_derive_v1`)
- `conformance/vectors/ledger/*-WA-*` and `conformance/vectors/manifest/*-WA-*` (raw CBOR-seq framing)
- `conformance/vectors/e2e/*-WA-*` (HKDF key/nonce expected bytes)
- `conformance/vectors/utf8/*-WA-*` (raw UTF-8 sorting traps)

Evidence output:
- CI artifact `evidence-<commit_sha>.zip` (`.github/workflows/ci.yml`)
- Tag release artifact via `.github/workflows/release-evidence.yml`
- Optional local workspace `.local-architect-reports/**` (never committed)
