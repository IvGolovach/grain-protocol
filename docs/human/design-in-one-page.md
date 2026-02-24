# Grain Design In One Page

## Mission

Provide a portable, adversarially robust language for food events with byte-level interoperability.

## Frozen core

- Encoding: strict DAG-CBOR.
- Identity: CIDv1 blessed set.
- Signature: COSE_Sign1 narrow profile (Ed25519).
- Ledger: append-only events with deterministic reducer semantics.
- E2E: capability-addressed ciphertext with deterministic derivation rules.
- Transport: GR1 QR format.

## Security boundary

- Guarantees: integrity + authorship + deterministic semantics.
- Not guaranteed: truthfulness of content.

## Governance model

- Conformance vectors are release gate.
- Frozen invariants do not change inside major version 1.
- Additive evolution only (new `t`, new transport prefix, extensions).

## Implementation strategy

- Rust Core: strict reference executor.
- TypeScript C01: cross-language smoke probe (Wave A byte path).
- Full second independent implementation follows after court-grade closure.
