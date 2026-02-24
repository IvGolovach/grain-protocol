# INVARIANTS (MUST rules index)

Hi teammate LLM. This is your non-negotiable checklist.
Use it when you need to answer: "What MUST stay identical across independent implementations?"

Each invariant block gives you:
- stable ID
- normative reference (NES/profile)
- executable vector evidence (POS/NEG IDs)

If code behavior and an invariant disagree, trust the invariant + vectors and report drift.

## Encoding / DAG-CBOR

- INV-ENC-001: Protocol objects MUST be strict DAG-CBOR; reject non-canonical.  
  Ref: NES §3.2; spec/profiles/cbor-profile.md  
  Vectors: NEG-ENC-001, NEG-ENC-002

- INV-ENC-002: Decoders MUST reject duplicate map keys at any nesting level.  
  Ref: NES §3.3  
  Vectors: NEG-ENC-010

- INV-ENC-003: Tags forbidden except tag 42 for CID links; any other tag -> reject.  
  Ref: NES §3.4  
  Vectors: NEG-ENC-020

- INV-ENC-004: UTF-8 comparisons/sorting are raw bytes only; no normalization; no locale rules.  
  Ref: NES §3.5; spec/profiles/cbor-profile.md §3  
  Vectors: NEG-ENC-030, POS-UTF8-WA-0001, NEG-UTF8-WA-0001, POS-UTF8-WA-0002, NEG-UTF8-WA-0002

- INV-ENC-005: Closed top-level keys; unknown top-level key -> reject.  
  Ref: NES §2.2  
  Vectors: NEG-ENC-040

- INV-ENC-006: Set-array semantics require sorted unique arrays by canonical ordering key.  
  Ref: spec/profiles/cbor-profile.md §5  
  Vectors: NEG-UTF8-WA-0003

## Identity / CID

- INV-CID-001: Blessed CID set: CIDv1 + dag-cbor + sha2-256; text base32 lower when used.  
  Ref: NES §4.1  
  Vectors: POS-CID-001

- INV-CID-002: CID link encoding MUST be tag42(bstr) with mandatory 0x00 prefix.  
  Ref: NES §4.3  
  Vectors: NEG-CID-010, NEG-E2E-WA-0003

## COSE signatures

- INV-COSE-001: COSE_Sign1 only; Ed25519 only; headers exact; external_aad empty; unprotected {}.  
  Ref: NES §5; spec/profiles/cose-profile.md  
  Vectors: POS-COSE-001, NEG-COSE-001

- INV-COSE-002: COSE tag 18 forbidden; tag18 input -> reject.  
  Ref: NES §5.1  
  Vectors: NEG-COSE-010

- INV-COSE-003: Deterministic COSE bytes required in core contexts.  
  Ref: NES §5.3  
  Vectors: NEG-COSE-020

## Ledger semantics

- INV-LED-001: Root-only grant/revoke authority.  
  Ref: NES §6.2  
  Vectors: NEG-LED-001

- INV-LED-002: Retroactive revoke (time-independent).  
  Ref: NES §6.3  
  Vectors: NEG-LED-010

- INV-LED-003: (ak,seq) uniqueness; conflicts ignore-all + diagnostic; quarantine excluded.  
  Ref: NES §6.5  
  Vectors: NEG-LED-020

- INV-LED-004: Reducers order-independent; normative outputs sum_mean + sum_var only.  
  Ref: NES §6.7  
  Vectors: POS-LED-001

- INV-LED-005: Numeric domains fixed; overflow -> deterministic error; no wrap/saturate.  
  Ref: NES §6.6  
  Vectors: NEG-LED-030

- INV-LED-006: Raw CBOR-seq ledger framing is deterministic and malformed framing MUST reject.  
  Ref: NES §3.2; NES §9.1 (CBOR-seq limits); spec/profiles/cbor-profile.md §7  
  Vectors: POS-LED-WA-0001, POS-LED-WA-0002, POS-LED-WA-0003, NEG-LED-WA-0001, NEG-LED-WA-0002, NEG-LED-WA-0003

## E2E semantics

- INV-E2E-001: cap_id MUST be random (CSPRNG) and MUST NOT be derived from plaintext identifiers.  
  Ref: NES §7.2; spec/profiles/e2e-profile.md  
  Vectors: (policy invariant; validated by review + audits)

- INV-E2E-002: AEAD profile MUST be HKDF-SHA256 + A256GCM; AAD=cap_id.  
  Ref: NES §7.3  
  Vectors: POS-E2E-001

- INV-E2E-003: Deterministic nonce; nonce == derived; mismatch -> reject.  
  Ref: NES §7.4; e2e-profile.md §5  
  Vectors: NEG-E2E-010, NEG-E2E-WA-0004

- INV-E2E-004: cap_id single-assignment; overwrite -> reject; chash binding required.  
  Ref: NES §7.6  
  Vectors: NEG-E2E-020, NEG-MAN-030

- INV-E2E-005: HKDF derivation output (key/nonce) is deterministic byte-for-byte for given inputs.  
  Ref: NES §7.4; spec/profiles/e2e-profile.md §5  
  Vectors: POS-E2E-WA-0001, POS-E2E-WA-0002, POS-E2E-WA-0003, POS-E2E-WA-0004, POS-E2E-WA-0005, NEG-E2E-WA-0001, NEG-E2E-WA-0002, NEG-E2E-WA-0003

- INV-E2E-006: EncryptedObject envelope requires nonce and AEAD authentication binding.  
  Ref: NES §7.4; spec/profiles/e2e-profile.md §6  
  Vectors: NEG-E2E-WA-0005, NEG-E2E-WA-0006

## Manifest resolution

- INV-MAN-001: Eligibility pipeline excludes quarantined and conflicted records.  
  Ref: e2e-profile.md §8.2  
  Vectors: NEG-MAN-010, POS-MAN-WA-0100, NEG-MAN-WA-0202

- INV-MAN-002: Deterministic resolution (tombstone dominates; min cap_id).  
  Ref: e2e-profile.md §8.3  
  Vectors: POS-MAN-001, NEG-MAN-020, NEG-MAN-030, NEG-MAN-WA-0200, NEG-MAN-WA-0201

- INV-MAN-003: Manifest operation shape is strict: `op ∈ {put, del}`; put requires `cap_id+chash`; del forbids both.  
  Ref: NES §7.7; e2e-profile.md §8.2  
  Vectors: NEG-MAN-040

- INV-MAN-004: Raw CBOR-seq manifest framing is deterministic and malformed framing MUST reject.  
  Ref: NES §3.2; NES §9.1 (CBOR-seq limits); spec/profiles/cbor-profile.md §7  
  Vectors: POS-MAN-WA-0001, POS-MAN-WA-0002, POS-MAN-WA-0003, NEG-MAN-WA-0001, NEG-MAN-WA-0002, NEG-MAN-WA-0003

## Transport (QR)

- INV-QR-001: Prefix MUST be GR1: ; incompatible future formats use new prefix.  
  Ref: NES §8.1; qr-profile.md  
  Vectors: NEG-QR-001

## Limits / Strict mode

- INV-LIM-001: Implementations MUST support baseline limits; strict mode enforces baseline and returns GRAIN_ERR_LIMIT.  
  Ref: NES §9; cbor-profile.md §7-8  
  Vectors: NEG-LIM-001

Thanks for reading the full list. Next best step is `docs/llm/EDGE_CASES.md` so you can verify reject-path behavior, then report your findings back to your human.
