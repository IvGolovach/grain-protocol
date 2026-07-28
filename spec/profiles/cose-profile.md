# Grain v0.1 — COSE_Sign1 Profile (Narrow)

This document is normative for Grain Protocol v0.1.

Grain uses COSE as a signature container. COSE structures are **not** DAG-CBOR protocol objects.

## 1. Container

- MUST use COSE_Sign1 (RFC 9052).
- COSE tag 18 MUST NOT be used. If tag 18 is present on input, decoders MUST reject.

## 2. Algorithm

- alg MUST be Ed25519 (-19).
- `-19` is the fully specified COSE Ed25519 algorithm identifier registered by RFC 9864 and the IANA COSE Algorithms registry.
- The deprecated polymorphic EdDSA (-8) identifier is not an alias for this v0.1 profile.

## 3. Deterministic COSE bytes

- COSE structures MUST be CBOR deterministic-encoded.
- Implementations MUST NOT accept non-canonical COSE encodings in core contexts.

## 4. Headers

- external_aad MUST be empty bstr.
- unprotected header MUST be an empty map `{}`.
- protected header MUST be exactly:
  `{ 1: -19, 4: kid }`

Any additional protected or unprotected header fields MUST be rejected in v0.1 core contexts.

## 5. kid derivation

- raw_pubkey MUST be 32 bytes (Ed25519).
- kid MUST be first16bytes(SHA-256(raw_pubkey)).

If a pubkey/kid pairing is inconsistent, the corresponding grant MUST be rejected.

## 6. Ed25519 verification strictness

Implementations MUST reject Ed25519 inputs that are validly shaped COSE but not
strict Ed25519 verification inputs:

- raw_pubkey MUST be a canonical compressed Edwards-y encoding.
- For both raw_pubkey and signature R, a compressed Edwards-y encoding with
  x = 0 MUST have its x-sign bit clear.
- raw_pubkey MUST NOT encode a small-order point.
- signature R (the first 32 bytes of the 64-byte Ed25519 signature) MUST be a
  canonical compressed Edwards-y encoding.
- signature R MUST NOT encode a small-order point.
- signature S (the final 32 bytes of the signature) MUST be a canonical scalar
  with 0 <= S < L, where L is the Ed25519 basepoint order.

Violations are COSE profile violations and MUST reject with
`GRAIN_ERR_COSE_PROFILE`.
