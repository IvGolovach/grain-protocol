# FREEZE CONFIRMATION v0.1

Protocol line: `v0.1.x` (`schema_major = 1`)

This document confirms what is frozen for major 1 and how to classify changes.
It is a release-governance companion to:
- `spec/FREEZE-v0.1.md`
- `spec/NES-v0.1.md`
- `spec/INTEROP-v0.1.md`

## 1) Frozen in major 1

The following are frozen and MUST NOT change within major 1:

1. Encoding and canonicalization:
- strict DAG-CBOR profile
- reject non-canonical bytes
- reject duplicate map keys at any nesting
- tag policy (only tag 42 for CID links)
- closed top-level keys behavior in v0.1 schemas

2. Identity:
- blessed CID set (`CIDv1 + dag-cbor + sha2-256`)
- CID link binary form (`tag42(bstr)` with required `0x00` prefix in link payload)

3. Signature profile:
- COSE_Sign1 narrow profile for core contexts
- Ed25519-only in v0.1 core profile
- deterministic COSE bytes requirement

4. Ledger semantics:
- root-only grant/revoke
- retroactive revoke
- `(ak,seq)` conflict rule: ignore-all on conflict
- deterministic reducer behavior and overflow semantics

5. E2E profile:
- HKDF-SHA256 + AES-256-GCM profile
- deterministic nonce derivation and nonce equality check
- `cap_id` CSPRNG-only rule and non-derivation from plaintext identifiers
- `cap_id` single-assignment and `chash` binding

6. Manifest semantics:
- eligibility pipeline behavior (invalid/quarantine/conflict/unauthorized exclusion)
- deterministic resolution rule (including tombstone precedence and cap tie-break)

7. Transport:
- `GR1:` prefix definition for v0.1 embedded QR profile

8. Strict conformance contract behavior:
- baseline limits + strict mode diagnostics (`GRAIN_ERR_LIMIT`)
- vector-driven deterministic verdict behavior

## 2) Breaking changes (major-level class)

A change is breaking if it can alter any of the following for already valid or invalid inputs:
- canonical bytes
- CID derivation result
- signature verification decision
- reducer output
- manifest resolution output
- deterministic error code contract where vectors assert exact code

Any such change is major-level by default unless formal analysis proves otherwise.

## 3) Additive changes (major-preserving class)

The following are additive and MAY be introduced within major 1:
- new object/event `t` values (with additive schemas and vectors)
- new transport profiles with new prefixes (for incompatible transport evolution)
- additional vectors that tighten quality, as long as frozen semantics are unchanged
- implementation optimizations that do not change observable strict behavior

Additive changes MUST keep existing vectors valid or add versioned vectors without redefining frozen outcomes.

## 4) Claim discipline

Conformance criterion:
- passing strict conformance suite for v0.1 contract.

Strong interoperability claim:
- requires two independent implementations with full strict-suite pass and zero divergence on required outputs, anchored to commit SHA and vector-manifest hash.

Non-claim boundary:
- no truth guarantee for signed content;
- no claim beyond strict mode/baseline limits/specified contract scope.

## 5) Review gate checklist

Any PR touching frozen domains MUST include:
- affected invariant IDs
- vector impact assessment
- explicit breaking/additive classification
- ADR reference if frozen-core-adjacent behavior is touched
