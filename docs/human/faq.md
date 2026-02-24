# FAQ

**Q: Does Grain guarantee nutrition accuracy?**  
No. Grain guarantees integrity and authorship, not truth.

**Q: Why so strict about canonical encoding?**  
Because interoperability is measured byte-for-byte. Loose parsing causes malleability and drift.
See also: `docs/human/why-not-json.md`.

**Q: Why is revoke retroactive?**  
To avoid wall-clock dependence and make authorization order-independent.

**Q: Can we rotate root key in v0.1?**  
No. Root rotation is intentionally not supported in v0.1. Recovery is new ledger genesis.

**Q: Why A256GCM only?**  
Minimal interop matrix. Additional algorithms can be added additively later.

**Q: Why does conformance include `e2e_derive_v1` and raw CBOR-seq parse ops?**  
Because interop failures often happen on byte paths before business semantics (KDF labels/separators, stream framing, parser edge cases). Wave A makes these failures explicit and deterministic.

**Q: Is Grain only for food forever?**  
No. v0.1 ships a food-first schema profile, but core invariants are domain-neutral. See `spec/SCOPE-v0.1.md`.
