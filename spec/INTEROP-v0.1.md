# INTEROP v0.1 (TOR-CERT-D01 Claim Gate)

Protocol line: `v0.1.x` (`schema_major = 1`)

This document defines interoperability claim boundaries for v0.1 strict certification.
Claim issuance and RC signoff process are governed by:
- `spec/INTEROP-CLAIM.md`
- `spec/RC-POLICY.md`

## 1) What this certification proves

For a specific commit SHA and vector manifest hash, certification proves that:
- strict-mode conformance verdicts match contract expectations, and
- two independent implementations (Rust reference, TypeScript independent) produce identical strict outputs where required by vectors.

Covered strict domains:
- canonical encoding behavior
- CID derivation behavior
- COSE verification behavior
- ledger reduction behavior
- manifest resolution behavior
- E2E derivation/decrypt behavior (where vectors define outputs/verdicts)

## 2) Claim levels (normative wording)

Conformance criterion (v0.1.x):
- passing the full conformance suite in Strict Conformance Mode.

Strong interoperability claim (v0.1.x):
- valid only when two independent implementations both pass full strict suite and produce zero divergence for defined outputs and error-code diagnostics, anchored to:
  - commit SHA,
  - vector manifest hash,
  - certification evidence hash.

Non-claim boundary:
- no claim of truthfulness for signed payload content,
- no claim outside strict mode and baseline limits,
- no claim outside the tested contract/version scope.

## 3) Scope limitations

This claim applies only to:
- Strict Conformance Mode,
- baseline limits defined by profiles,
- exact contract + vectors used in the evidence pack,
- exact implementation revisions referenced by commit SHA.

## 4) Cryptographic assumptions

The claim assumes practical security of:
- SHA-256,
- Ed25519,
- HKDF-SHA256,
- AES-256-GCM.

Cryptographic breaks are out of scope for v0.1 certification and may require profile/major evolution.

## 5) Evidence pack contract

Certification evidence pack MUST contain:
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

All artifacts MUST include commit identity directly or via bundle metadata.

## 6) Reproducibility

Evidence bundle reproducibility command:

```bash
./tools/interop_certify.sh --out-dir artifacts/interop --commit-sha <commit_sha>
```

Execution notes:
- script uses local Rust toolchain when `cargo` is available;
- otherwise script falls back to Docker (`rust:1.86`) for Rust suite execution;
- Docker is required for Rust-vs-TS divergence probes.

Reproducibility requirement:
- independent clean runs must produce identical `evidence.sha256` for the same commit and inputs.

## 7) Relation to freeze and scope

Interop claim scope is constrained by:
- `spec/FREEZE-CONFIRMATION-v0.1.md` (frozen vs breaking vs additive boundaries),
- `spec/SCOPE-v0.1.md` (domain-neutral core vs food profile scope).

## 8) Message discipline

External claims MUST NOT overstate beyond this document.
Statements implying "universal compatibility" or "truth guarantees" are invalid for v0.1.

## 9) What Grain is / is not (v0.1)

Grain is:
- a protocol for byte-level deterministic, verifiable events and immutable objects,
- an infrastructure layer for integrity/authorship, deterministic reduction, and privacy-by-default transport/sync.

Grain is not:
- a global truth registry,
- a truth oracle for payload semantics,
- a social/time-consensus platform,
- a guarantee that signed payload content is factually true.
