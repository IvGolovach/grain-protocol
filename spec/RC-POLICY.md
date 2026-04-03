# RC Policy (Audit-Grade)

Protocol line: `v0.1.x` (`schema_major = 1`)

This policy defines release-candidate discipline for certification cycles.

## 1) Tag namespaces (MUST)

- Protocol semantic tags: `protocol-*`
- Repo milestone tags: `repo-*`
- Protocol RC tags: `protocol-rc-vX.Y.Z-rcN`
- Repo RC tags: `repo-rc-vX.Y.Z-rcN`

All RC tags MUST be annotated and signed.

## 2) RC metadata (MUST)

RC tag message (or linked signoff file) MUST include:
- target commit SHA,
- toolchain hash references,
- Rust suite summary hash,
- TS suite summary hash,
- divergence summary hash,
- interop evidence hash,
- CI run id / evidence artifact reference.

## 3) Stabilization window (MUST)

Baseline stabilization window: `14` calendar days from RC tag creation.

Allowed changes during RC window:
- blocker fixes,
- docs-only clarifications,
- CI/repro hardening that does not change frozen semantics or expected vector outcomes.

Forbidden during RC window:
- frozen-core semantic changes,
- expected vector redefinition to match implementation behavior,
- diagnostic contract redefinition,
- adding features unrelated to blocker resolution.

## 4) No-regressions rule (MUST)

Any of the following invalidates RC and requires formal revocation:
- conformance suite not 100% strict pass,
- Rust↔TS divergence non-zero,
- spec/CDDL/vector drift in frozen domains,
- deterministic nonce output regression,
- manifest/ledger deterministic behavior regression,
- any frozen-core file semantic change.

## 5) RC rollback / revocation (MUST)

RC rollback MUST NOT rewrite history and MUST NOT delete the revoked tag.

Revocation requires:
- signed revocation document under `spec/rc/REVOCATIONS/`,
- reason category and evidence hash,
- signer identity and signature method.

Optional marker tag:
- `<rc-tag>-revoked` pointing to the same commit.

## 6) Claim sign-off policy (MUST)

- RC Ready sign-off: minimum 1 maintainer signature.
- Strong interoperability claim sign-off: minimum 2 signatures
  (maintainer + independent reviewer/auditor) over evidence hash.

Sign-off records live under `spec/rc/SIGNOFFS/`.

## 7) RC is not GA (MUST)

RC status means readiness under current evidence, not public general availability.
GA/public claims require separate decision and scope.
