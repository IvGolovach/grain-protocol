# Architecture

Grain is layered:

1) **Encoding Layer**
   - strict DAG-CBOR for protocol objects
   - reject non-canonical
   - reject duplicate map keys

2) **Identity Layer**
   - CIDv1 blessed set (dag-cbor + sha2-256)
   - CID links via tag42(bstr) with 0x00 prefix

3) **Signature Layer**
   - COSE_Sign1 narrow profile, Ed25519 only
   - deterministic COSE bytes
   - tag18 forbidden

4) **Ledger Layer**
   - append-only signed events
   - root-only grant/revoke
   - retroactive revoke (time-independent)
   - (ak,seq) uniqueness conflicts ignore-all
   - reducers are order-independent
   - normative totals: sum_mean + sum_var
   - stream ingestion path must be deterministic on raw CBOR-seq framing

5) **E2E Layer**
   - capability addressing for private objects
   - cap_id random (CSPRNG) + single-assignment
   - HKDF-SHA256 + AES-256-GCM
   - deterministic nonce; nonce == derived
   - HKDF key/nonce derivation must match expected bytes exactly
   - manifest resolution is deterministic and order-independent

6) **Transport Layer**
   - GR1 embedded QR: GR1: + Base45(zlib(COSE_BYTES))

7) **Extensibility**
   - new types `t` (additive)
   - ext/crit mechanism with deterministic quarantine

See `spec/NES-v0.1.md` for normative rules.
See `conformance/SPEC.md` and `conformance/vectors/*-WA-*` for byte-level court checks.

Reference implementation note:
- Rust Core lives in `core/rust/` and executes the same layers as a strict interpreter.
- Conformance is still the arbiter; implementation does not redefine protocol semantics.
- TS smoke runner lives in `runner/typescript/` and is currently scoped to C01 (Wave A byte-level profile) for cross-language drift detection.
