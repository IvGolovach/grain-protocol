# Grain Protocol v0.1 — Audit-Ready Public Launch Packet

This packet is for auditors and technical reviewers who want the shortest accurate view of the repo.

## 1) Executive technical summary

Grain is an open protocol for representing and exchanging verifiable physical events in adversarial environments with byte-level interoperability.  
v0.1 ships a food-first schema profile while preserving domain-neutral core invariants.

Key properties in v0.1:
- **Canonical bytes:** strict DAG-CBOR; reject non-canonical; reject duplicate map keys.
- **Content addressing:** immutable objects identified by CIDv1 (dag-cbor + sha2-256).
- **Offline verification:** COSE_Sign1 narrow profile (Ed25519 only, deterministic CBOR).
- **Deterministic merge:** append-only ledger with explicit conflict elimination ((ak,seq) ignore-all).
- **Privacy-by-default:** E2E encrypted private objects using capability addressing (cap_id).
  - cap_id is random (CSPRNG) and not derived from plaintext identifiers.
  - deterministic nonce lifecycle (HKDF-based; crash-safe; nonce==derived).
  - ciphertext is not a CAS-object.
  - manifest resolution is deterministic and order-independent.
- **Forward compatibility:** unknown types stored opaque + forwarded; unknown critical quarantined deterministically.

Grain verifies integrity and authorship, not truthfulness of content.

## 2) Frozen core invariants list (IDs)

Canonicalization:
- INV-ENC-001 reject non-canonical
- INV-ENC-002 reject duplicate map keys
- INV-ENC-003 tags forbidden except tag42
- INV-ENC-004 UTF-8 bytes-only sorting; no normalization
- INV-ENC-005 closed top-level keys

Identity:
- INV-CID-001 blessed CID set
- INV-CID-002 CID link encoding tag42 with 0x00 prefix

Signatures:
- INV-COSE-001 COSE_Sign1 narrow profile
- INV-COSE-002 tag18 forbidden
- INV-COSE-003 deterministic COSE bytes

Ledger:
- INV-LED-001 root-only grant/revoke
- INV-LED-002 retroactive revoke
- INV-LED-003 (ak,seq) conflict ignore-all; quarantine excluded
- INV-LED-004 deterministic reducer outputs (sum_mean/sum_var)
- INV-LED-005 numeric domains + overflow semantics

E2E:
- INV-E2E-001 cap_id random (CSPRNG), not derived from plaintext identifiers
- INV-E2E-002 HKDF-SHA256 + A256GCM; AAD=cap_id
- INV-E2E-003 deterministic nonce; nonce==derived
- INV-E2E-004 cap_id single-assignment + chash binding

Manifest:
- INV-MAN-001 eligibility pipeline excludes quarantined/conflicted/unauthorized
- INV-MAN-002 deterministic resolution (tombstone dominates; min cap_id)
- INV-MAN-003 strict op-shape (`op∈{put,del}`; put requires `cap_id+chash`; del forbids both)

Transport:
- INV-QR-001 GR1 prefix fixed

Limits:
- INV-LIM-001 baseline limits + Strict Conformance Mode

Full mapping to vectors: `docs/llm/INVARIANTS.md`.

## 3) Threat model (short)

Assumed attackers:
- adversarial issuers (can sign lies)
- network attackers (replay, injection, MITM)
- malicious sync server (observe, drop, reorder)
- compromised device key (attacker can sign as that device)

Not assumed:
- cryptographic primitives are broken (handled as “crypto break” events -> new protocol major)
- global trusted time

Protected:
- integrity of bytes
- authorship binding to keys
- deterministic merge semantics
- privacy vs server via E2E + random cap_id

Not protected:
- truthfulness of content
- availability (bounded via limits only)
- recovery from compromised root key without new genesis (v0.1 constraint)

## 4) Repo map (source-of-truth priority)

1. `spec/NES-v0.1.md`
2. `spec/schemas/grain-v0.1.cddl`
3. `conformance/vectors/`
4. `spec/profiles/`
5. `docs/llm/`
6. `adr/`
7. `core/`, `sdk/`

## 5) Conformance suite contract

- Contract: `conformance/SPEC.md`
- Vectors: `conformance/vectors/**`
- Runner must support Strict Conformance Mode.
- Wave A byte-level ops:
  - `parse_cborseq_stream_v1` (raw stream framing)
  - `e2e_derive_v1` (exact HKDF key/nonce bytes)
- Wave A vector ID scheme: `POS/NEG-<AREA>-WA-####`
- Passing the suite is the conformance criterion for v0.1.
- A strong interoperability claim becomes valid after two independent implementations pass the full suite.
- Formal claim boundaries are defined in `spec/INTEROP-v0.1.md`.
- Freeze boundaries and change classification are defined in `spec/FREEZE-CONFIRMATION-v0.1.md`.
- Domain scope clarification is defined in `spec/SCOPE-v0.1.md`.
- Current state: Rust reference runner (`core/rust/grain-runner`) passes the current vector set in Strict Conformance Mode.
- Cross-language parity: TS full engine (`runner/typescript`) executes the full strict suite and produces Rust↔TS divergence reports for both C01 and full profiles.
- CI evidence artifacts are commit-bound (`evidence-<commit_sha>.zip`) and include suite summary + vector manifest + lock/toolchain hashes.

## 6) Change governance

- Any change touching frozen core requires ADR and is likely breaking.
- PR template requires listing invariant IDs and vectors affected.
- CI blocks merges on malformed vectors or missing mapping.

## 7) Extension policy

Additive extensions without major bump:
- new object types (`t`) within schema major 1
- new transport profiles with new prefixes (GR2:, etc.)
- new pairing methods that do not change E2E envelope semantics

Prohibited without major bump:
- changes to encoding/CID/COSE/ledger/E2E/manifest frozen rules

## 8) Security boundaries

- A valid signature means: “this exact payload was signed by the key holder”.
- It does NOT mean: “payload content is true”.
- Ledger authorization defines which keys are allowed to contribute semantics.
- E2E boundaries prevent server-side correlation if cap_id is random and single-assignment.

## 9) Known trade-offs (intentional)

- Retroactive revoke (order-independent, no trusted time; but harsh semantics).
- Root-only admin (simpler, deterministic; but no delegated authority).
- No root rotation in v0.1 (recovery requires new genesis).
- A256GCM only (minimal interop matrix).
- Deterministic nonce (stateless; binds security to derivation correctness).
- Strict canonicalization (less “lenient parsing”; stronger interop).

## 10) Open questions

None for v0.1, except external cryptographic breaks (future major bump class).

## 11) Interop certification gate (TOR-CERT-D01)

- Certification workflow: `/.github/workflows/interop-certify.yml` (manual or tag-triggered).
- Script: `tools/interop_certify.sh`.
- Required evidence pack:
  - `suite-run-rust.json`
  - `suite-run-ts.json`
  - `divergence-c01.json`
  - `divergence-full.json`
  - `property-tests.json`
  - `vector-manifest.json`
  - `inputs-hashes.json`
  - `interop-evidence.json`
  - `interop-report.md`
  - `evidence.sha256`

## 12) Provenance migration and release discipline

- Repository provenance expectations are documented in `MIGRATION.md` and ADR `adr/conformance/0002-bundle-provenance-migration.md`.
- Tag namespaces are intentionally split:
  - protocol line: `protocol-*`
  - repository milestones: `repo-*`
- Required CI checks on `main`:
  - `python-tooling`
  - `rust-core`
  - `evidence-bundle`
  - `capid-csprng-audit`
