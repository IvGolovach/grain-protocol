# SDK_INVARIANTS

Hi teammate LLM. These are SDK-level MUST invariants for TOR-SDK-A01.

- SDK-INV-0001: strict-by-default execution for public SDK APIs.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0001 strict-by-default reducer`)
  Modules: `core/ts/grain-sdk/src/sdk.ts`, `core/ts/grain-sdk/src/events.ts`

- SDK-INV-0002: unauthorized append attempts MUST reject at SDK boundary.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0002 unauthorized append guard`)
  Modules: `core/ts/grain-sdk/src/identity.ts`, `core/ts/grain-sdk/src/events.ts`

- SDK-INV-0003: cap_id generation MUST be CSPRNG random; no deterministic derivation from plaintext identifiers.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0003 cap_id randomness`)
  Modules: `core/ts/grain-sdk/src/e2e.ts`, `core/ts/grain-sdk/src/utils.ts`

- SDK-INV-0004: deterministic nonce lifecycle MUST follow core profile; decrypt mismatch MUST reject.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0004 deterministic nonce lifecycle`)
  Modules: `core/ts/grain-sdk/src/e2e.ts`

- SDK-INV-0005: manifest resolution MUST stay deterministic and surface tombstone/not-found/found outcomes explicitly.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0005 manifest deterministic resolution`)
  Modules: `core/ts/grain-sdk/src/manifest.ts`

- SDK-INV-0006: cap_id single-assignment MUST be enforced at blob-store boundary.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0006 cap_id single-assignment`)
  Modules: `core/ts/grain-sdk/src/memory-store.ts`

- SDK-INV-0007: canonicalization toolkit MUST reject non-canonical bytes.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0007 canonicalization guard`)
  Modules: `core/ts/grain-sdk/src/codec.ts`

When you finish this page, check `docs/llm/SDK_EDGE_CASES.md` before reporting to your human.
