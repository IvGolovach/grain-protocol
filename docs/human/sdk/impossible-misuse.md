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
   - fail-closed
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

## Validation command

```bash
node --experimental-strip-types core/ts/grain-sdk/scripts/test-sdk-invariants.ts
```

This command is the executable proof for `SDK-INV-*` mappings in `docs/llm/SDK_INVARIANTS.md`.
