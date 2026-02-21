# Grain Protocol — Normative Encoding & Semantics (NES) v0.1

**Status:** Frozen Core (Protocol schema major = 1)  
**License:** Apache-2.0 (spec text in this repo)  
**Audience:** implementers, auditors, conformance authors

This document is normative. It uses RFC 2119 terms: MUST, MUST NOT, SHOULD, SHOULD NOT, MAY.

## 0. Scope

Grain v0.1 defines a strict, offline-verifiable protocol for food-related objects and events, with:
- canonical bytes (strict DAG-CBOR),
- content addressing (CIDv1 blessed set),
- signatures (COSE_Sign1 + Ed25519 narrow profile),
- append-only user ledger with deterministic reduction,
- E2E private sync using capability addressing + manifest resolution,
- offline QR transport profile (GR1).

Grain v0.1 explicitly does NOT define:
- a global registry as canonical truth,
- delegated admin authority,
- transparency logs as MUST,
- trusted global time,
- BigNum / arbitrary precision in core,
- truthfulness guarantees (signatures attest source, not truth).

## 1. Terminology

- **Protocol object (CAS-object):** an immutable object encoded as strict DAG-CBOR and addressed by a CID computed from canonical bytes.
- **CID link:** a reference to a CID encoded inside DAG-CBOR using tag 42.
- **COSE message:** COSE_Sign1 structure used for signatures (outside DAG-CBOR protocol objects).
- **Ledger:** append-only signed event stream for a user.
- **Manifest:** E2E-private append-only stream mapping plaintext CIDs to capability IDs (cap_id) for sync.
- **Strict Conformance Mode:** a required implementation mode where baseline limits are enforced exactly and limit exceed returns deterministic errors.

## 2. Protocol schema major and object envelope

### 2.1 Protocol schema major (MUST)
All protocol objects MUST include:
- `v` : unsigned integer, protocol schema major. For v0.1, `v MUST be 1`.
- `t` : text string type name.

Unknown `v` (major) MUST be rejected.

### 2.2 Closed top-level keys (MUST)
For each protocol object type `t`, the set of top-level keys is closed.
Any unknown top-level key MUST be rejected.

Extensions are permitted only via:
- `ext` (non-critical extensions)
- `crit` (critical extension identifiers)
- a new type `t` within the same major (additive)

### 2.3 Unknown type handling (MUST)
If an object is canonical and otherwise valid but `t` is unknown:
- MUST store the raw bytes opaque,
- MUST forward on export/sync,
- MUST ignore in reducers (no semantic effect).

### 2.4 Unknown critical handling (MUST quarantine)
If `crit` contains an unknown critical identifier:
- MUST quarantine deterministically:
  - store opaque + forward,
  - MUST NOT participate in reducers, authorization, manifest resolution, or compute inputs.

Quarantine is applied before conflict detection.

## 3. Encoding Layer — strict DAG-CBOR

### 3.1 Payload codec (MUST)
All protocol objects MUST be encoded as **strict DAG-CBOR**.

### 3.2 Canonical encoding (MUST)
Implementations MUST reject non-canonical encodings.
Implementations MAY canonicalize-and-compare internally, but observable behavior MUST be reject.

Canonical rules include:
- definite lengths only (no indefinite-length items),
- no floating point values,
- map keys ordering as per deterministic CBOR (by encoded key length, then lexicographic bytes),
- integers encoded in shortest form,
- UTF-8 strings MUST be valid UTF-8.

### 3.3 Duplicate map keys (MUST)
Decoders MUST reject duplicate map keys at any nesting level.

### 3.4 Tags (MUST)
Tags in protocol objects are forbidden except:
- **tag 42** for CID links.

Any other tag MUST be rejected.

### 3.5 UTF-8 byte ordering (MUST)
When sorting or comparing text strings for canonical set semantics or tie-breaks:
- no Unicode normalization is applied,
- comparison MUST be lexicographic on raw UTF-8 bytes,
- locale-based comparisons MUST NOT be used.

## 4. Identity Layer — CIDv1 blessed set

### 4.1 Blessed CID set (MUST)
Protocol object IDs MUST be CIDv1 with:
- multicodec: `dag-cbor` (0x71)
- multihash: `sha2-256` (MUST)
- text form (when used): multibase base32 lower, prefix `b` (MUST)

### 4.2 CID derivation (MUST)
For a protocol object with canonical bytes `B`, its object ID is:
- `cid = CIDv1(dag-cbor, sha2-256(B))`

### 4.3 CID links in DAG-CBOR (MUST)
CID links MUST be encoded as:
- CBOR tag 42 applied to a bstr that begins with a single 0x00 prefix byte, followed by the binary CID bytes.

`tag42(bstr)` missing the 0x00 prefix MUST be rejected.

## 5. Signature Layer — COSE narrow profile

### 5.1 COSE container (MUST)
Signatures MUST use **COSE_Sign1** (untagged; tag 18 MUST NOT be used).

### 5.2 Algorithms (MUST)
- alg MUST be Ed25519 (-19).

### 5.3 Deterministic COSE bytes (MUST)
COSE structures MUST be deterministic-encoded CBOR.

### 5.4 Headers (MUST)
- external_aad MUST be empty bstr
- unprotected header MUST be empty map `{}`.
- protected header MUST be exactly `{ 1: -19, 4: kid }` where `kid` is a bstr.

Any additional protected/unprotected header fields MUST be rejected in core contexts.

### 5.5 kid derivation (MUST)
`kid` MUST be:
- first16bytes(SHA-256(raw_pubkey_32bytes))

If a grant claims a pubkey/kid pairing that does not match derivation, the grant MUST be rejected.

## 6. Ledger Layer — append-only signed events

### 6.1 Ledger event envelope (MUST)
Ledger events MUST be transported/stored as:
- COSE_Sign1(payload = canonical DAG-CBOR LedgerEvent)

Ledger event payload MUST include:
- `v=1`
- `t` (event type)
- `ak` (author kid, bstr(16))
- `seq` (uint, per-author sequence number)
- `ts_ms` (optional; not used for authorization/conflict semantics in v0.1)

### 6.2 Root-only grant/revoke (MUST)
Only the root key declared in `LedgerGenesis` may issue:
- `DeviceKeyGrant`
- `DeviceKeyRevoke`

Any grant/revoke not signed by root MUST be ignored for authorization.

### 6.2.1 Root rotation (NOT supported in v0.1)
Grain v0.1 does not define any in-protocol root rotation mechanism.

If the root private key is compromised:
- the current ledger MUST be treated as compromised,
- recovery in v0.1 requires creating a new `LedgerGenesis` (new ledger genesis).

This is an intentional v0.1 constraint to preserve determinism and avoid partially-defined authority transfer semantics.

### 6.3 Retroactive revoke (MUST)
`DeviceKeyRevoke(ak)` makes `ak` unauthorized retroactively, independent of time.
All ledger events signed by that `ak` MUST be treated as unauthorized and ignored by reducers.

### 6.4 Authorized(ak) (MUST, order-independent)
Authorization is a function of the set of valid grants/revokes:

`Authorized(ak) = true` iff:
- `ak == root_kid`, OR
- `ValidGrant(ak) == true` AND `ValidRevoke(ak) == false`

### 6.5 (ak, seq) uniqueness and conflict (MUST)
For each pair `(ak, seq)`, at most one valid event payload is allowed.
If ≥2 different valid events share the same `(ak, seq)` with different payload CIDs:
- MUST mark `(ak, seq)` conflicted,
- MUST ignore all events with that `(ak, seq)`,
- SHOULD emit diagnostic `SEQ_CONFLICT`.

Quarantined events MUST NOT participate in conflict detection.

### 6.6 Numeric domains and overflow (MUST)
- All numeric fields MUST fit within int64/uint63 as specified by schema.
- variance MUST be ≥ 0.
- Reducers MUST compute in extended precision and MUST return deterministic `GRAIN_ERR_OVERFLOW` if results cannot be represented in-domain.
- Reducers MUST NOT wrap or saturate.

### 6.7 Normative reducer outputs (MUST)
For v0.1, reducers MUST produce deterministic totals only as:
- `sum_mean`
- `sum_var`

Quantiles (p50/p90) are non-normative UI-level outputs.

## 7. E2E Layer — private sync with capability addressing

### 7.1 cap_id representation (MUST)
- cap_id MUST be raw 32-byte bstr.
- cap_id text forms are presentation-only and MUST NOT be used for AAD/KDF.

### 7.2 cap_id generation (MUST)  **[privacy-critical]**
- cap_id MUST be generated using a cryptographically secure random number generator (CSPRNG).
- cap_id MUST NOT be derived from plaintext CID, payload bytes, or any deterministic function of plaintext identifiers.
- If a CSPRNG is unavailable or fails during cap_id generation, the implementation MUST abort object creation and MUST NOT fall back to any non-cryptographic source.

Rationale: deterministic cap_id enables server-side correlation and breaks the privacy model.

### 7.3 AEAD profile (MUST)
- HKDF-SHA256 MUST be used for key/nonce derivation.
- AEAD MUST be **AES-256-GCM** (A256GCM).
- AAD MUST be cap_id raw bytes.
- nonce MUST be 12 bytes, tag MUST be 16 bytes.

### 7.4 Deterministic nonce derivation (MUST)

Nonce generation MUST be fully deterministic, crash-safe, and stateless (no runtime counters, no device-local monotonic state).

Inputs (MUST):
- `sync_secret`: 32 bytes (out-of-band shared secret)
- `cap_id`: raw 32-byte bstr
- `cid_link_bstr`: the exact CID-link bstr bytes used in tag42 encoding, including the required leading 0x00 prefix and the binary CID bytes (NOT any text form)

HKDF profile (MUST):
- KDF MUST be HKDF-SHA256.
- `PRK = HKDF-Extract(salt = cap_id, IKM = sync_secret)`

Note on HKDF labels (MUST):
- The HKDF `info` values specified below are byte strings.
- The notation `\0` denotes a single zero byte (0x00) separator (not the two-character sequence backslash + zero).
- All label text is ASCII encoded.

Key derivation (MUST):
- `key = HKDF-Expand(PRK, info = "GrainE2E\0v0.1\0A256GCM\0key", L=32)`

Nonce derivation (MUST):
- `nonce_derived = HKDF-Expand(PRK, info = "GrainE2E\0v0.1\0A256GCM\0nonce\0" || cid_link_bstr, L=12)`

Envelope binding (MUST):
- `EncryptedObject` MUST carry field `nonce` (12 bytes).
- If `nonce` is missing, the message MUST be rejected (schema violation).
- The envelope `nonce` MUST equal `nonce_derived`; otherwise the message MUST be rejected with `NONCE_PROFILE_MISMATCH`.

### 7.5 EncryptedObject envelope (MUST)
Private objects are transported as an `EncryptedObject` DAG-CBOR payload containing:
- `alg = "A256GCM"`
- `cap_id` (bstr 32)
- `nonce` (bstr 12)
- `ct` (ciphertext || tag)
- optional metadata as defined in schema (closed keys)

Ciphertext envelopes are NOT CAS-objects.

### 7.6 Single-assignment immutability + chash binding (MUST)
- cap_id MUST be single-assignment: one cap_id -> one ciphertext blob (byte-for-byte).
- manifest records MUST include `chash = sha2-256(ciphertext_bytes)` and fetchers MUST verify it.
- Any cap_id overwrite or chash mismatch MUST be treated as corruption and rejected.

### 7.7 Manifest log (MUST)
- Manifest records are append-only and E2E-private.
- Manifest MUST inherit ledger strictness and conflict rules (quarantine excludes; (ak,seq) conflicts ignore-all).
- Only authorized device keys with capability `"write"` may write manifest records.
- `ManifestRecord.op` MUST be exactly `"put"` or `"del"`.
- For `op="put"`, both `cap_id` and `chash` MUST be present.
- For `op="del"`, `cap_id` and `chash` MUST NOT be present.
- Any op-shape mismatch MUST be rejected with `GRAIN_ERR_MANIFEST_OP`.

### 7.8 Manifest eligibility + resolution (MUST)
Implementations MUST follow the eligibility pipeline and deterministic resolution rule defined in `spec/profiles/e2e-profile.md`.

Ordering definition (MUST): where resolution requires choosing the "smallest" cap_id, cap_id comparison MUST be lexicographic over the raw 32-byte sequence (compare byte 0, then byte 1, ... through byte 31). No text forms and no locale rules apply.

## 8. Transport Layer — GR1 embedded QR

### 8.1 GR1 prefix (MUST)
Embedded QR payloads MUST use prefix `GR1:`. Decoders MUST accept GR1; encoders MUST emit GR1.

Incompatible future QR formats MUST use a new prefix (e.g., GR2:).

### 8.2 Pipeline (MUST)
`GR1:` + Base45( Zlib( COSE_Sign1_BYTES ) )

Interop criterion: decode + verify + strict validate.

## 9. Limits and Strict Conformance Mode

### 9.1 Baseline limits (MUST support at least)

Implementations MUST support at least the following Conformance Baseline Limits (CBL).
These numeric values are normative and MUST NOT be treated as implementation-defined.

Parsing / structural:
- CBL_MAX_CBOR_NESTING_DEPTH = 32
- CBL_MAX_CBOR_MAP_PAIRS = 4096
- CBL_MAX_CBOR_ARRAY_LENGTH = 4096
- CBL_MAX_TSTR_UTF8_BYTES = 1024

Payload sizes:
- CBL_MAX_DAGCBOR_OBJECT_BYTES = 5_000_000
- CBL_MAX_EXT_CANONICAL_BYTES = 65_536
- CBL_MAX_CRIT_ENTRIES = 64
- CBL_MAX_CRIT_TOTAL_UTF8_BYTES = 4096

Context-specific:
- CBL_MAX_LEDGER_EVENT_PAYLOAD_BYTES = 32_768
- CBL_MAX_MANIFEST_RECORD_PAYLOAD_BYTES = 8_192
- CBL_MAX_SERVINGOFFER_PAYLOAD_BYTES = 2_048
- CBL_MAX_E2E_CIPHERTEXT_BYTES = 8_000_000

CBOR-seq segments:
- CBL_MAX_CBORSEQ_SEGMENT_BYTES = 64_000_000
- CBL_MAX_CBORSEQ_SEGMENT_ITEMS = 1_000_000

(Identical limits are also listed in `spec/profiles/cbor-profile.md` for the encoding profile.)

### 9.2 Strict Conformance Mode (MUST)

Implementations MUST provide Strict Conformance Mode where:
- baseline limits are enforced exactly,
- limit exceed returns deterministic `GRAIN_ERR_LIMIT`.

Conformance suite runs only in Strict Conformance Mode.

## 10. Conformance

Passing the conformance suite in Strict Conformance Mode is the conformance criterion for Grain Protocol v0.1.
Conformance vectors include mandatory negative cases covering:
- non-canonical encodings,
- duplicate map keys,
- COSE profile violations,
- (ak,seq) conflicts,
- manifest edge cases,
- nonce mismatch,
- GR1 prefix mismatch,
- limit exceed behavior.

See `conformance/` and `docs/llm/CONFORMANCE.md`.
