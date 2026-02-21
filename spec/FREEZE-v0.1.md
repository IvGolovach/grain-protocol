# Grain Protocol — Freeze Statement (v0.1)

**Protocol v0.1 is a frozen core.** The goal is long-lived interoperability.
If you change anything in this document, you are probably proposing a protocol major bump.

This statement is human-oriented. The normative rules live in `spec/NES-v0.1.md`.

## What is frozen in v0.1

### Encoding / canonicalization
- Strict DAG-CBOR for protocol objects.
- Reject non-canonical encodings (canonicalize-and-compare allowed internally, but observable behavior is reject).
- Reject duplicate map keys at any nesting level.
- Tags forbidden except tag 42 for CID links.
- UTF-8 comparisons are raw bytes only; no Unicode normalization.

### Identity (CID)
- CIDv1 blessed set:
  - codec = dag-cbor (0x71)
  - multihash = sha2-256 (MUST)
  - text form = base32 lower (multibase `b`) when text is used
- CID links in CBOR: tag42(bstr) with mandatory 0x00 prefix.

### Signatures (COSE)
- COSE_Sign1 narrow profile.
- Ed25519 (-19) only.
- Deterministic COSE bytes.
- external_aad empty; unprotected header = {}.
- Protected headers exact: {1:-19, 4:kid}.
- COSE tag 18 forbidden.

### Ledger semantics
- Append-only signed events.
- Root-only DeviceKeyGrant / DeviceKeyRevoke authority.
- Retroactive revoke (time-independent).
- (ak,seq) uniqueness: conflicts ignore-all + diagnostic.
- Reducers are order-independent.
- Normative reducer outputs: sum_mean + sum_var only.
- Numeric domains fixed; overflow returns deterministic error (no wrap/saturate).

### E2E semantics
- Capability addressing (cap_id is binary bstr32).
- cap_id MUST be random (CSPRNG) and MUST NOT be derived from plaintext CIDs/identifiers.
- AES-256-GCM only (A256GCM).
- HKDF-SHA256 derivation.
- AAD = cap_id.
- Deterministic nonce lifecycle; nonce == derived.
- cap_id single-assignment immutability.
- chash binding (sha2-256(ciphertext bytes)).
- Ciphertext envelope is NOT a CAS-object.
- Manifest inherits ledger strictness and conflict rules.
- Manifest op-shape is strict: `op in {put, del}`; put requires `cap_id+chash`; del forbids both.
- Manifest deterministic resolution (tombstone dominates; min cap_id tie-break).

### Transport (QR)
- GR1: prefix and pipeline GR1: + Base45(zlib(COSE_BYTES))

### Limits / conformance
- Conformance Baseline Limits (CBL) must be supported at least.
- Strict Conformance Mode must exist and must return deterministic limit errors.
- Conformance suite is the release gate.

## Allowed changes without a protocol major bump

Additive only:
- new object types `t` within schema major 1 (with CDDL + vectors + ADR)
- new transport profiles using new prefixes (GR2:, etc.)
- new pairing mechanisms that do not change the E2E envelope semantics
- tooling/docs improvements

## What requires a protocol major bump

Any change to frozen items above, including:
- canonicalization rules
- blessed CID set
- COSE profile
- ledger authorization/conflict/reducer rules
- E2E envelope/KDF/AAD/nonce rules
- GR1 prefix/pipeline
