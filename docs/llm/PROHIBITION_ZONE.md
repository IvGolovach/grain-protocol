# Prohibition Zone (Strict, Non-Negotiable)

Hi. This is a short map of what must never be done if you want to preserve interop.

- PZ-NORM-0001: No implicit normalization of textual fields. Vectors: NEG-UTF8-WA-0001, NEG-UTF8-WA-0002
- PZ-LOCALE-0002: No locale-dependent ordering for canonical decisions. Vectors: NEG-UTF8-WA-0003, POS-UTF8-WA-0001
- PZ-TIME-0003: No wall-clock semantics for auth/conflict/reducer outcomes. Vectors: NEG-LED-010, NEG-LED-020
- PZ-ORDER-0004: No arrival-order semantics in deterministic merge/reduce. Vectors: POS-LED-001, POS-MAN-WA-0100
- PZ-OVERFLOW-0005: No platform-dependent integer overflow behavior. Vectors: NEG-LED-030, POS-LED-001
- PZ-CANON-0006: No silent canonicalization of non-canonical bytes. Vectors: NEG-ENC-001, NEG-ENC-010
- PZ-DUPKEY-0007: No duplicate-map-key acceptance at any depth. Vectors: NEG-ENC-002, NEG-ENC-020
- PZ-CBORSEQ-0008: No partial-success outputs for malformed CBOR-seq framing. Vectors: NEG-LED-WA-0002, NEG-MAN-WA-0002
- PZ-E2E-0009: No nonce/profile drift in deterministic E2E derivation. Vectors: NEG-E2E-010, NEG-E2E-WA-0004
- PZ-CAPID-0010: No deterministic cap_id generation or non-CSPRNG fallback. Vectors: NEG-E2E-WA-0001, NEG-E2E-WA-0002

If you are unsure, check vectors first and choose fail-closed behavior.
