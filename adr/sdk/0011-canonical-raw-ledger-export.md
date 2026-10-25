# ADR 0011: Canonical Map Keys in Raw Ledger Export

Status: Accepted

Date: 2026-10-25

## Context

The TypeScript raw ledger CBOR-sequence exporter sorted map keys by UTF-8
lexicographic order. NES section 3.2 requires encoded-key length followed by
encoded-byte order. Existing stream-framing checks did not validate each map,
so deterministic SDK output could still fail strict canonical decoding.

## Decision

- Encode each text key once and sort by encoded length, then encoded bytes.
  Apply the same rule recursively to maps, including maps inside arrays.
- Keep event ordering, values, integer rejection and CBOR-sequence framing.
- Validate each exported element using the strict core parser; cover nested
  keys, UTF-8 byte length, equal-length ordering and the 23/24-byte boundary.
- Keep this API an export of the SDK reducer model. Canonical CBOR is not a
  typed LedgerEvent or a signed COSE envelope; no signing claim is added.

## Compatibility

Exported bytes change where the previous order violated the existing profile.
Consumers must regenerate byte hashes for such exports. Event IDs, stored
records, protocol schemas, canonicalization rules and runner contracts do not
change. Weakening the strict parser to accept the old order was rejected.

## Verification

SDK-INV-0011 now strictly parses every sequence item. SDK-REG-0004 checks nested
UTF-8 keys, both sides of the text-header length boundary, insertion-order
independence and retained values. Both checks fail before the exporter fix.
