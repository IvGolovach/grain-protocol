# Overview

Grain is **Open Food Infrastructure**: a neutral language for food events that can be verified offline and merged deterministically.

Grain v0.1 provides:
- canonical object bytes (strict DAG-CBOR)
- content addressing (CIDv1)
- signatures (COSE_Sign1 + Ed25519)
- append-only user ledger with deterministic reduction
- E2E private sync (capability addressing + manifest resolution)
- offline QR transport (GR1:)
- byte-level conformance evidence via Wave A vectors (raw streams, HKDF expected-bytes, UTF-8 traps, mixed manifest sequences)

Grain does **not** provide:
- a global registry as canonical truth
- truth guarantees (signatures attest authorship/integrity only)
- a platform, social graph, or central DB

Start here:
- `docs/human/quickstart.md`
- `docs/human/architecture.md`
- `spec/NES-v0.1.md`
