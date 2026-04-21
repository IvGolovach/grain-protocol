# Impossible Misuse Checklist

This checklist documents what public SDK APIs reject by construction.

## Guaranteed reject paths

1. Unauthorized append
   - revoked or unknown `ak` in `events.append()`
   - code: `SDK_ERR_UNAUTHORIZED_AK`
2. cap_id overwrite / corruption
   - same `cap_id`, different ciphertext/chash
   - code: `SDK_ERR_CAP_OVERWRITE_OR_CORRUPTION`
3. Missing CSPRNG for cap generation
   - operation stops instead of guessing
   - code: `SDK_ERR_CSPRNG_UNAVAILABLE`
4. Non-canonical bytes
   - rejected by `codec.strictValidate()`
   - code: core canonical diagnostics (for example `GRAIN_ERR_NONCANONICAL`)
5. Duplicate set-array values in typed builder
   - rejected by `buildSetArray(...)`
   - code: `GRAIN_ERR_SET_ARRAY_DUP`
6. Invalid transport bundle payload/schema
   - rejected by `transport.bundleImport(...)`
   - code: `SDK_ERR_TRANSPORT_BUNDLE_SCHEMA` / `SDK_ERR_TRANSPORT_BUNDLE_DECODE`
7. Invalid imported transport binary fields
   - non-standard base64 in `objects[*]`, `manifest[*].cap_id_b64`, or `manifest[*].chash_b64`
   - code: `SDK_ERR_TRANSPORT_BUNDLE_SCHEMA`
8. Invalid imported identity-bundle binary fields
   - non-standard base64 in `root_pub_b64`, `sync_secret_b64`, or `device_keys[*].pub_b64`
   - code: `SDK_ERR_IDENTITY_BUNDLE_INVALID`
9. Verify call without explicit trust material
   - rejected by `transport.verifyGR1(...)`
   - code: `SDK_ERR_TRANSPORT_VERIFY_TRUST_REQUIRED`
10. Verify call with malformed trust bytes
   - rejected by `transport.verifyGR1(...)`
   - code: `SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID`
11. Forged/expired/unknown AI accepted token
   - rejected by `ai.applyAccepted(...)`
   - code: `SDK_ERR_ACCEPT_TOKEN_FORGED` / `SDK_ERR_ACCEPT_TOKEN_UNKNOWN` / `SDK_ERR_ACCEPT_TOKEN_EXPIRED`
12. AI candidate bypass around deterministic firewall
   - no public `sdk.store` access; side effects require sidecar `accept()` then opaque token apply
   - code path: `SDK-AI-001` gate suite
13. Unknown critical AI candidate extensions
   - quarantined deterministically
   - code: `SDK_ERR_AI_QUARANTINED_UNKNOWN_CRITICAL`

## Consistency guarantees

- `identity.addDeviceKey()` and `identity.revokeDeviceKey()` persist their matching ledger lifecycle events before returning.
- Public SDK callers do not need a second manual `events.append()` step to keep authorization state aligned with reducer-visible ledger history.
- `identity.importBundle()` either finishes fully or rolls back.
- `events.correct()` either writes both events or rolls back both.

## Validation command

```bash
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk-ai run test:boundary
```

This command is the executable proof for `SDK-INV-*` mappings in `docs/llm/SDK_INVARIANTS.md`.
