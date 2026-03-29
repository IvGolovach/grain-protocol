# Grain Design In One Page

## Mission

Give people a small, portable protocol for real-world events that can be verified byte-for-byte.

## What stays fixed

- Encoding: strict DAG-CBOR.
- Identity: CIDv1.
- Signature: COSE_Sign1 with Ed25519.
- Ledger: append-only events with deterministic reduction.
- E2E: capability-addressed ciphertext with deterministic derivation rules.
- Transport: `GR1:` QR format.

## Security boundary

- Grain guarantees integrity, authorship, and deterministic behavior.
- Grain does not guarantee that the content is true.

## How the repo is split

- Protocol specs define the rules.
- Conformance vectors check those rules.
- Rust Core is the reference executor.
- TypeScript full engine is the independent strict implementation.
- The SDK is the friendly layer for apps.

## Change rule

- Core rules stay frozen in major version 1.
- New behavior is added, not rewritten.
- `C01` stays as a small smoke profile for byte-path checks, not as the main compatibility criterion.
