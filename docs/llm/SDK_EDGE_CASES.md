# SDK_EDGE_CASES

Hi teammate LLM. Use this as the SDK reject-path checklist.

- SDK-NEG-0001: append with revoked/unauthorized `ak` -> `SDK_ERR_UNAUTHORIZED_AK`
- SDK-NEG-0002: cap_id overwrite under same key with different ciphertext/chash -> `SDK_ERR_CAP_OVERWRITE_OR_CORRUPTION`
- SDK-NEG-0003: missing CSPRNG during cap generation -> `SDK_ERR_CSPRNG_UNAVAILABLE`
- SDK-NEG-0004: non-canonical bytes into codec strict validate -> core reject diagnostic (`GRAIN_ERR_NONCANONICAL` or equivalent)
- SDK-NEG-0005: invalid identity bundle format/version -> `SDK_ERR_IDENTITY_BUNDLE_INVALID` / `SDK_ERR_IDENTITY_BUNDLE_VERSION`
- SDK-NEG-0006: duplicate entries through set-array builder -> `GRAIN_ERR_SET_ARRAY_DUP`
- SDK-NEG-0007: malformed bundle import payload/root schema -> `SDK_ERR_TRANSPORT_BUNDLE_SCHEMA`
- SDK-NEG-0008: invalid bundle JSON bytes -> `SDK_ERR_TRANSPORT_BUNDLE_DECODE`
- SDK-NEG-AI-0001: malformed AI candidate envelope (version/kind/schema/target/payload_format) -> `SDK_ERR_AI_*`
- SDK-NEG-AI-0002: malformed payload by format (`structured_v1` / `dagcbor_b64`) -> deterministic reject
- SDK-NEG-AI-0003: numeric field not decimal-string or out-of-range -> `SDK_ERR_AI_NUMERIC_*`
- SDK-NEG-AI-0004: bytes field not base64 standard -> `SDK_ERR_AI_BYTES_B64`
- SDK-NEG-AI-0005: invalid/missing json-pointer paths -> `SDK_ERR_AI_POINTER_*`
- SDK-NEG-AI-0006: set-array duplicates -> `GRAIN_ERR_SET_ARRAY_DUP`
- SDK-NEG-AI-0007: unknown critical extension -> `SDK_ERR_AI_QUARANTINED_UNKNOWN_CRITICAL`
- SDK-NEG-AI-0008: cid derive contract mismatch -> `SDK_ERR_AI_CID_DERIVE`
- SDK-NEG-AI-0009: forged or replayed accepted token -> `SDK_ERR_ACCEPT_TOKEN_FORGED` / `SDK_ERR_ACCEPT_TOKEN_UNKNOWN`
- SDK-NEG-AI-0010: expired accepted token -> `SDK_ERR_ACCEPT_TOKEN_EXPIRED`
- SDK-NEG-AI-0011: token registry capacity exceeded -> `SDK_ERR_ACCEPT_TOKEN_CAP_REACHED`
- SDK-NEG-AI-0012: structured_v1 profile metadata missing/unknown -> `SDK_ERR_AI_PROFILE_*`

These checks are asserted in:
- `core/ts/grain-sdk/scripts/test-sdk-invariants.ts`
- `core/ts/grain-sdk-ai/scripts/test-sdk-ai-boundary.ts`
