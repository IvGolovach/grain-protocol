# RC Stabilization Attack Matrix

This matrix is the normative scenario list for TOR-RC-STAB-A01.
Expected behavior is deterministic and must not be implementation-defined.

| ID | Scenario | Vector | Expected behavior |
| --- | --- | --- | --- |
| AM-001 | GR1 replay and reorder pressure | `conformance/vectors/qr/POS-QR-001.json` | Repeat executions are deterministic and identical across Rust/TS |
| AM-002 | COSE tag18 injection | `conformance/vectors/cose/NEG-COSE-010.json` | Deterministic reject path |
| AM-003 | COSE protected/unprotected anomaly | `conformance/vectors/cose/NEG-COSE-001.json` | Deterministic reject path |
| AM-004 | CBOR-seq garbage tail | `conformance/vectors/ledger/NEG-LED-WA-0002.json` | Deterministic framing reject |
| AM-005 | CBOR-seq invalid initial byte | `conformance/vectors/ledger/NEG-LED-WA-0003.json` | Deterministic framing reject |
| AM-006 | E2E nonce profile mismatch | `conformance/vectors/e2e/NEG-E2E-010.json` | Deterministic nonce/profile reject |
| AM-007 | E2E ciphertext hash mismatch | `conformance/vectors/e2e/NEG-E2E-020.json` | Deterministic integrity reject |
| AM-008 | Mixed manifest with tombstone | `conformance/vectors/manifest/NEG-MAN-WA-0200.json` | Deterministic unresolvable outcome |
| AM-009 | cap/chash ambiguity pressure | `conformance/vectors/manifest/NEG-MAN-WA-0201.json` | Deterministic ambiguity handling |
| AM-010 | Eligible/ineligible mixed sequence | `conformance/vectors/manifest/NEG-MAN-WA-0202.json` | Ineligible records never perturb winner |
| AM-011 | Retroactive revoke semantics | `conformance/vectors/ledger/NEG-LED-010.json` | Revoked semantics removed deterministically |
| AM-012 | UTF-8 bytes ordering trap | `conformance/vectors/utf8/NEG-UTF8-WA-0001.json` | Deterministic strict reject |

## Verdict policy
- `PASS`: expected behavior observed in both implementations.
- `FOUND_BUG`: crash, divergence, or expectation failure.
- `INTENTIONALLY_REJECTED`: malformed/fuzzed input rejected by design.
