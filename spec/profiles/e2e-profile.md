# Grain v0.1 — E2E Profile (HKDF-SHA256 + AES-256-GCM)

This document is normative for Grain Protocol v0.1.

## 1. Goals

- E2E encryption for private objects.
- Server is a replica; server sees ciphertext only.
- Deterministic, crash-safe nonce lifecycle (no runtime counters).
- Capability addressing (cap_id) prevents correlation on plaintext CIDs.

## 2. cap_id

### 2.1 Representation (MUST)
- cap_id MUST be raw 32-byte bstr.
- Any text representation is presentation-only.

### 2.2 Generation (MUST)
- cap_id MUST be generated using a cryptographically secure random number generator (CSPRNG).
- cap_id MUST NOT be derived from plaintext CID, payload bytes, or any deterministic function of plaintext identifiers.
- If a CSPRNG is unavailable or fails during cap_id generation, the implementation MUST abort object creation and MUST NOT fall back to any non-cryptographic source.

Rationale: deterministic cap_id breaks privacy by enabling correlation.

### 2.3 Single-assignment immutability (MUST)
- One cap_id MUST map to exactly one ciphertext blob (byte-for-byte).
- Any attempt to store a different ciphertext under the same cap_id MUST be treated as corruption and rejected.

## 3. Key material

### 3.1 sync_secret (baseline)
v0.1 baseline assumes an out-of-band `sync_secret` (32 bytes).

Device pairing / distribution mechanisms may evolve additively without changing envelope semantics.

## 4. Cryptography (MUST)

- KDF MUST be HKDF-SHA256.
- AEAD MUST be AES-256-GCM ("A256GCM").
- AAD MUST be cap_id raw bytes.
- nonce MUST be 12 bytes.
- tag MUST be 16 bytes.

## 5. Deterministic nonce derivation (MUST)

Inputs:
- sync_secret: 32 bytes
- cap_id: 32 bytes
- cid_link_bstr: the exact CID-link bstr bytes used in tag42, including the required leading 0x00 prefix and the binary CID bytes.

Derivation:
Note on HKDF labels (MUST):
- The HKDF `info` values specified below are byte strings.
- The notation `\0` denotes a single zero byte (0x00) separator (not the two-character sequence backslash + zero).
- All label text is ASCII encoded.

- PRK = HKDF-Extract(salt = cap_id, IKM = sync_secret)
- key = HKDF-Expand(PRK, info = "GrainE2E\0v0.1\0A256GCM\0key", L=32)
- nonce_derived = HKDF-Expand(PRK, info = "GrainE2E\0v0.1\0A256GCM\0nonce\0" || cid_link_bstr, L=12)

Envelope rule:
- EncryptedObject MUST carry field `nonce` (12 bytes).
- If `nonce` is missing, the message MUST be rejected (schema violation).
- nonce MUST equal nonce_derived; otherwise reject with `NONCE_PROFILE_MISMATCH`.

## 6. EncryptedObject envelope (MUST)

EncryptedObject is a DAG-CBOR payload with closed top-level keys:
- v=1
- t="EncryptedObject"
- alg="A256GCM"
- cap_id (bstr32)
- nonce (bstr12)
- ct (bstr) = ciphertext || tag

Notes:
- Ciphertext envelope is NOT a CAS-object.
- Plaintext CAS-object CID may appear only inside encrypted domains.

## 7. chash binding (MUST)

Manifest records MUST include:
- chash = sha2-256(ciphertext_bytes)

Fetchers MUST verify chash before accepting ciphertext.

## 8. Manifest log semantics (MUST)

Manifest is an E2E-private append-only signed stream (COSE_Sign1 payload = ManifestRecord DAG-CBOR bytes).
Manifest inherits the ledger rules:
- strict canonical validation
- quarantine precedence (unknown critical excluded from semantics)
- (ak,seq) uniqueness with ignore-all conflict rule

### 8.1 Manifest authority (baseline MUST)
- Any Authorized(ak) device key that has capability "write" MAY append manifest records.
- Root-only manifest writes are NOT required in v0.1.
- Conflict rules MUST be applied strictly.

### 8.2 Eligibility pipeline (MUST)
A manifest record is eligible iff:
1) COSE verifies under narrow profile.
2) Payload is strict canonical DAG-CBOR; no duplicate map keys; closed keys.
3) schema major matches (v=1).
4) payload.ak == COSE kid.
5) Authorized(ak) == true and caps include "write".
6) Not quarantined (unknown critical -> quarantine -> ineligible).
7) Not part of a conflicted (ak,seq).
8) Operation shape is valid:
   - `op` MUST be exactly `"put"` or `"del"`.
   - If `op="put"`, both `cap_id` and `chash` MUST be present.
   - If `op="del"`, `cap_id` and `chash` MUST NOT be present.
   - Violations MUST be rejected with `GRAIN_ERR_MANIFEST_OP`.

Conflicted (ak,seq) elimination MUST be computed on eligible candidates; conflicted pairs are removed entirely.

### 8.3 Deterministic resolution (MUST)
For a given plaintext `cid`:

Let:
- D(cid) = eligible records with op="del" and that cid
- P(cid) = eligible records with op="put" and that cid

Resolution:
1) If D(cid) is non-empty -> cid is tombstoned -> UNRESOLVABLE.
2) Else:
   - For any cap_id that appears with multiple different chash values, all records with that cap_id MUST be ignored (CAP_CHASH_CONFLICT).
   - This filter MUST be applied to `P(cid)` before tie-break.
3) If P(cid) is empty -> UNRESOLVABLE.
4) Else pick the record r* in P(cid) with lexicographically smallest cap_id (raw bytes).
   Ordering definition (MUST): cap_id comparison is lexicographic over the raw 32-byte sequence (compare byte 0, then byte 1, ... through byte 31). No text forms and no locale rules apply.

This rule is order-independent and does not use wall-clock.
