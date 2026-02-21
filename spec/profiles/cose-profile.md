# Grain v0.1 — COSE_Sign1 Profile (Narrow)

This document is normative for Grain Protocol v0.1.

Grain uses COSE as a signature container. COSE structures are **not** DAG-CBOR protocol objects.

## 1. Container

- MUST use COSE_Sign1 (RFC 9052).
- COSE tag 18 MUST NOT be used. If tag 18 is present on input, decoders MUST reject.

## 2. Algorithm

- alg MUST be Ed25519 (-19).

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

