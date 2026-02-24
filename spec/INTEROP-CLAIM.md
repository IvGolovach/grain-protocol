# Interop Claim Template (v0.1.x)

Use this template when issuing certification statements.

## 1) Conformance criterion

Passing the full conformance suite in Strict Conformance Mode is the criterion for protocol conformance in `v0.1.x`.

## 2) Strong interoperability claim

A strong interoperability claim is valid only when all conditions hold:
- two independent implementations pass the full strict suite,
- divergence is zero for verdicts, error codes, and required byte outputs,
- results are anchored to commit SHA and vector-manifest hash,
- evidence bundle hash is published.

## 3) Scope limits

The claim applies only to:
- Strict Conformance Mode,
- baseline limits,
- exact vector set and contract version used for certification,
- exact implementation revisions identified by commit SHA.

## 4) Non-claims

This claim does not assert:
- truthfulness of payload content,
- universal compatibility outside the tested contract,
- guarantees beyond standard crypto assumptions.

## 5) Required citation block

Every strong interop statement MUST include:
- `commit_sha`
- `vector_manifest_sha256`
- `evidence_sha256`
- links/ids to CI run artifacts
- signatures from required signers (see `spec/RC-POLICY.md`)

