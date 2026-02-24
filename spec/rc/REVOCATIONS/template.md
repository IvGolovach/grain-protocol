# RC Revocation Record Template

- revoked_tag: `protocol-rc-v0.1.1-rcN`
- commit_sha: `<40-hex-sha>`
- reason_category: `<conformance-regression|divergence|drift|security|other>`
- reason_details: `<short deterministic explanation>`
- evidence_sha256: `<sha256-hex>`
- signer_identity: `<github-login-or-key-id>`
- signature_ref: `<signed-tag-or-signature-file-ref>`
- timestamp_utc: `YYYY-MM-DDTHH:MM:SSZ`

## Notes

RC revocation does not delete tags or rewrite history.
If needed, add an optional marker tag `<revoked_tag>-revoked` pointing to the same commit.

