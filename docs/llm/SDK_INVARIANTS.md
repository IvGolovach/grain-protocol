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

- SDK-INV-0008: set-array builder MUST reject duplicates and enforce byte-level canonical set semantics.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0008 set-array builder strictness`)
  Modules: `core/ts/grain-sdk/src/primitives.ts`

- SDK-INV-0009: error explain contract MUST return deterministic category + NES/vector references for diagnostics.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0009 deterministic error model`)
  Modules: `core/ts/grain-sdk/src/errors.ts`, `core/ts/grain-sdk/src/codec.ts`

- SDK-INV-0010: transport bundle import/export MUST be deterministic and schema-checked.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-invariants.ts` (`SDK-INV-0010 transport bundle determinism`)
  Modules: `core/ts/grain-sdk/src/transport.ts`

- SDK-AI-001: AI candidate MUST pass `accept()` before any apply side effect; opaque token only.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-001 no public sdk.store`, `SDK-AI-001 apply accepted token`, `SDK-AI-001 forged token reject`)
  Modules: `core/ts/grain-sdk/src/sdk.ts`, `core/ts/grain-sdk/src/ai/token_registry.ts`, `core/ts/grain-sdk/src/ai/accept.ts`

- SDK-AI-002: AI acceptance/apply MUST be deterministic for same input class.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-002 deterministic accept`, `SDK-AI-002 replay reject`, `SDK-AI-002 token expiry`, `SDK-AI-002 dagcbor accept path`)
  Modules: `core/ts/grain-sdk/src/ai/accept.ts`, `core/ts/grain-sdk/src/ai/token_registry.ts`

- SDK-AI-003: SDK core MUST have no outbound network calls (model/vendor agnostic boundary).
  Tests: `tools/ci/check_sdk_no_network.py` (`SDK no-network guard: OK`)
  Modules: `core/ts/grain-sdk/src/**`, `tools/ci/check_sdk_no_network.py`

- SDK-AI-004: AI explain payload MUST be redacted by default.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-004 redaction default`, `SDK-AI-004 sensitive mode bounded`)
  Modules: `core/ts/grain-sdk/src/ai/diagnostics.ts`

- SDK-AI-005: Numeric ingestion MUST accept decimal strings only and convert deterministically.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-005 numeric fields reject JS number`, `SDK-AI-005 explicit profile required`)
  Modules: `core/ts/grain-sdk/src/ai/candidate_v1.ts`, `core/ts/grain-sdk/src/ai/accept.ts`, `core/ts/grain-sdk/src/ai/profiles.ts`

- SDK-AI-006: Set-array ingestion MAY sort deterministically but MUST reject duplicates.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-006 set-array normalization trace`, `SDK-AI-006 set-array duplicates reject`)
  Modules: `core/ts/grain-sdk/src/ai/accept.ts`

- SDK-AI-007: Unknown critical extensions MUST quarantine and MUST NOT apply.
  Tests: `core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts` (`SDK-AI-007 unknown critical quarantine`, `SDK-AI-007 quarantined cannot apply`)
  Modules: `core/ts/grain-sdk/src/ai/accept.ts`

When you finish this page, check `docs/llm/SDK_EDGE_CASES.md` before reporting to your human.
