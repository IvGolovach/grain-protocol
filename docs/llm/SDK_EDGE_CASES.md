# SDK_EDGE_CASES

Hi teammate LLM. Use this as the SDK reject-path checklist.

- SDK-NEG-0001: append with revoked/unauthorized `ak` -> `SDK_ERR_UNAUTHORIZED_AK`
- SDK-NEG-0002: cap_id overwrite under same key with different ciphertext/chash -> `SDK_ERR_CAP_OVERWRITE_OR_CORRUPTION`
- SDK-NEG-0003: missing CSPRNG during cap generation -> `SDK_ERR_CSPRNG_UNAVAILABLE`
- SDK-NEG-0004: non-canonical bytes into codec strict validate -> core reject diagnostic (`GRAIN_ERR_NONCANONICAL` or equivalent)
- SDK-NEG-0005: invalid identity bundle format/version -> `SDK_ERR_IDENTITY_BUNDLE_INVALID` / `SDK_ERR_IDENTITY_BUNDLE_VERSION`

These checks are asserted in:
- `core/ts/grain-sdk/scripts/test-sdk-invariants.ts`
