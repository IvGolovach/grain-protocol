# SDK Error Model

SDK errors are deterministic and structured. The machine contract is `code + category`; free-text is explanatory only.

## Shape

Every SDK error exposes:

- `code`
- `category`
- `layer` (`sdk` or `core`)
- `nes_ref`
- `vector_refs[]`
- `details`
- `human_hint`
- `summary`

## Categories

- `VALIDATION`
- `CANONICAL`
- `CRYPTO`
- `E2E`
- `MANIFEST`
- `LEDGER`
- `LIMITS`
- `QUARANTINE`
- `CONTRACT`

## Determinism rules

- `code` and `category` MUST be deterministic.
- SDK MUST not rename core diagnostics.
- SDK-native checks use `SDK_ERR_*`.

## Quick examples

- `SDK_ERR_UNAUTHORIZED_AK` (`LEDGER`)
  - append attempted with revoked/non-authorized key
- `SDK_ERR_CSPRNG_UNAVAILABLE` (`CRYPTO`)
  - cap_id generation failed, so the operation stopped
- `GRAIN_ERR_NONCANONICAL` (`CANONICAL`, layer=`core`)
  - strict validation rejected non-canonical bytes

## Programmatic use

Use `sdk.codec.explain(code)` for a stable explanation payload:

- `code`
- `category`
- `summary`
- `hint`
- `nes_ref`
- `vector_refs`

For AI ingestion rejects, use `sdk.ai.accept(...)` result `error` payload:

- `summary`
- `likely_causes[]`
- `how_to_fix[]`
- `spec_refs[]`
- `invariant_refs[]`
- `vector_refs[]`
- `normalization_applied[]`
- `redaction_policy`
