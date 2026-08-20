# INVARIANTS (MUST rules index)

Hi teammate LLM. This is your must-keep checklist.
Use it when you need to answer: "What MUST stay identical across independent implementations?"

Each invariant block gives you:
- stable ID
- normative reference (NES/profile)
- executable evidence (POS/NEG vectors or static checks)

If code behavior and an invariant disagree, trust the invariant + executable evidence and report drift.

## Encoding / DAG-CBOR

- INV-ENC-001: Protocol objects MUST be strict DAG-CBOR; reject non-canonical.  
  Ref: NES §3.2; spec/profiles/cbor-profile.md  
  Vectors: NEG-ENC-001, NEG-ENC-002, NEG-ENC-050, NEG-ENC-051, NEG-ENC-052, NEG-ENC-053, NEG-ENC-054

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

## Typed Object Validation v1

- INV-OBJ-001: Optional `dagcbor_validate.object_type` MUST select a supported top-level v0.1 CDDL production; fixed-type objects require matching `t`, `v=1`, and a top-level map. `LedgerEvent` is context-selected and retains its event-type tstr.
  Ref: NES §2.3.1; spec/profiles/cbor-profile.md §4.1
  Vectors: POS-OBJ-001, POS-OBJ-014, NEG-OBJ-001, NEG-OBJ-002, NEG-OBJ-003, NEG-OBJ-004, NEG-OBJ-005, NEG-OBJ-006, NEG-OBJ-007, NEG-OBJ-097, NEG-OBJ-098, NEG-OBJ-099

- INV-OBJ-002: A selected known object MUST satisfy all required fields, exact CBOR value kinds, closed nested productions, and exactly one IntakeEvent or ManifestRecord union branch.
  Ref: NES §2.3.1; spec/schemas/grain-v0.1.cddl
  Vectors: POS-OBJ-003, POS-OBJ-004, POS-OBJ-005, POS-OBJ-006, POS-OBJ-007, POS-OBJ-016, POS-OBJ-017, NEG-OBJ-010, NEG-OBJ-023, NEG-OBJ-030, NEG-OBJ-044, NEG-OBJ-050, NEG-OBJ-054, NEG-OBJ-057, NEG-OBJ-058, NEG-OBJ-059, NEG-OBJ-060, NEG-OBJ-089, NEG-OBJ-090, NEG-OBJ-091, NEG-OBJ-092, NEG-OBJ-093, NEG-OBJ-094

- INV-OBJ-003: Typed validation MUST enforce fixed-width byte strings, complete blessed CID-link structure, int64/uint63 ranges, non-negative Food Profile quantities, and non-negative variance.
  Ref: NES §2.3.1, §4, §6.6, §6.8; spec/profiles/cbor-profile.md §4.1, §6
  Vectors: POS-OBJ-003, POS-OBJ-008, POS-OBJ-009, POS-OBJ-015, POS-OBJ-016, NEG-OBJ-035, NEG-OBJ-036, NEG-OBJ-038, NEG-OBJ-039, NEG-OBJ-041, NEG-OBJ-042, NEG-OBJ-043, NEG-OBJ-044, NEG-OBJ-045, NEG-OBJ-046, NEG-OBJ-047, NEG-OBJ-070, NEG-OBJ-071, NEG-OBJ-072, NEG-OBJ-073, NEG-OBJ-074, NEG-OBJ-075, NEG-OBJ-076, NEG-OBJ-077, NEG-OBJ-078

- INV-OBJ-004: Typed set-arrays MUST use raw UTF-8 ordering for tstr items and canonical encoded-byte ordering for structured items, with exact duplicate rejection.
  Ref: spec/profiles/cbor-profile.md §5
  Vectors: POS-OBJ-003, POS-OBJ-004, POS-OBJ-010, NEG-OBJ-052, NEG-OBJ-053, NEG-OBJ-055, NEG-OBJ-056, NEG-OBJ-062, NEG-OBJ-063, NEG-OBJ-064, NEG-OBJ-065

- INV-OBJ-005: Typed validation MUST enforce generic and applicable type-specific Conformance Baseline Limits.
  Ref: NES §9; spec/profiles/cbor-profile.md §4.1, §7
  Vectors: POS-OBJ-001, POS-OBJ-008, POS-OBJ-014, POS-OBJ-017, NEG-OBJ-080, NEG-OBJ-081, NEG-OBJ-082, NEG-OBJ-083, NEG-OBJ-084, NEG-OBJ-085, NEG-OBJ-086

- INV-OBJ-006: Typed validation diagnostics MUST follow the documented precedence; ManifestRecord op/branch failures use `GRAIN_ERR_MANIFEST_OP`, while earlier byte and unknown-key failures retain their specific codes.
  Ref: spec/profiles/cbor-profile.md §4.1; core/rust/grain-core/docs/errors.md
  Vectors: POS-OBJ-016, POS-OBJ-017, NEG-OBJ-068, NEG-OBJ-069, NEG-OBJ-089, NEG-OBJ-090, NEG-OBJ-091, NEG-OBJ-092, NEG-OBJ-093, NEG-OBJ-094, NEG-OBJ-095, NEG-OBJ-097, NEG-OBJ-098, NEG-OBJ-099

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
  Vectors: POS-COSE-001, NEG-COSE-001, NEG-COSE-002, NEG-COSE-003

- INV-COSE-002: COSE tag 18 forbidden; tag18 input -> reject.  
  Ref: NES §5.1  
  Vectors: NEG-COSE-010

- INV-COSE-003: Deterministic COSE bytes required in core contexts.  
  Ref: NES §5.3  
  Vectors: NEG-COSE-020

- INV-COSE-004: Protected `kid` MUST equal first16(SHA-256(raw_pubkey)); mismatched pubkey/kid pairings reject.
  Ref: spec/profiles/cose-profile.md §5
  Vectors: NEG-COSE-WA-0002

- INV-COSE-005: Ed25519 verification inputs MUST be strict; weak public keys, small-order signature R values, non-canonical compressed point encodings, and non-canonical signature scalars reject.
  Ref: spec/profiles/cose-profile.md §6
  Vectors: NEG-COSE-030, NEG-COSE-031, NEG-COSE-032, NEG-COSE-033, NEG-COSE-034, NEG-COSE-035

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
  Vectors: POS-LED-WA-0001, POS-LED-WA-0002, POS-LED-WA-0003, POS-LED-WA-0004, NEG-LED-WA-0001, NEG-LED-WA-0002, NEG-LED-WA-0003

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

## Food Profile

- INV-FOOD-001: Food reducer input `source_class` MUST use the fixed Food Profile vocabulary.
  Ref: NES §6.8; spec/profiles/food-profile.md; spec/profiles/food-profile.v1.json
  Static: STATIC-FOOD-PROFILE-001

- INV-FOOD-002: Food reducer-visible `kcal` values MUST be integer kilocalories with `scale_exp10 = 0`.
  Ref: NES §6.8; spec/profiles/food-profile.md; spec/profiles/food-profile.v1.json
  Static: STATIC-FOOD-PROFILE-001

- INV-FOOD-003: Food quantity fields `amount_g`, `yield_g`, `serving_g`, and `servings` MUST be non-negative int64 values with `scale_exp10 = 0`.
  Ref: NES §6.8; spec/profiles/food-profile.md; spec/profiles/food-profile.v1.json
  Static: STATIC-FOOD-PROFILE-001

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

- INV-QR-002: After the `GR1:` prefix, body MUST be valid Base45 of a zlib-compressed COSE blob; malformed body bytes and oversized decoded COSE bytes -> reject.
  Ref: NES §8.1; qr-profile.md
  Vectors: POS-QR-001, NEG-QR-002, NEG-QR-003, NEG-QR-WA-0001

## Limits / Strict mode

- INV-LIM-001: Implementations MUST support baseline limits; strict mode enforces baseline and returns GRAIN_ERR_LIMIT.  
  Ref: NES §9; cbor-profile.md §7-8  
  Vectors: NEG-LIM-001

## Stabilization Infrastructure

- INV-STAB-001: RC stabilization cleanup failures MUST NOT change protocol verdict.  
  Ref: TOR-RC-STAB-PATCH-A02; tools/stabilization/run_rc_stab.py  
  Vectors: (policy invariant; validated by tests + audits)  
  Evidence: tools/stabilization/test_run_rc_stab.py::test_cleanup_failure_does_not_flip_protocol_pass

## Developer Product Surface

- INV-DX-001: Repo-native onboarding, fixtures, domain profile samples, interop matrix, and security regression catalog MUST stay discoverable and machine-checked.
  Ref: docs/human/start-here.md; examples/reference-fixtures/README.md; conformance/interop-matrix.v1.json; conformance/security-regressions.v1.json; spec/profiles/profile-registry.v1.json
  Static: STATIC-REPO-NATIVE-DEVELOPER-PLATFORM-001

Thanks for reading the full list. Next best step is `docs/llm/EDGE_CASES.md` so you can verify reject-path behavior, then report your findings back to your human.
