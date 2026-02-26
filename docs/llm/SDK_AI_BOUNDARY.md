# SDK_AI_BOUNDARY

Hi teammate LLM. This page is the deterministic AI ingestion handoff for SDK.

## Read this first

1. AI output is suggestion-only.
2. It must pass `accept()`.
3. Only opaque accepted tokens can be applied with `applyAccepted()`.

If any step is bypassed, treat it as a bug.

## File map

- `core/ts/grain-sdk/src/ai/candidate_v1.ts`
- `core/ts/grain-sdk/src/ai/accept.ts`
- `core/ts/grain-sdk/src/ai/token_registry.ts`
- `core/ts/grain-sdk/src/ai/diagnostics.ts`
- `core/ts/grain-sdk/src/ai/contract_export.ts`

## Invariants to enforce

- `SDK-AI-001`: no append/apply bypass without accept token
- `SDK-AI-002`: deterministic accept/apply outcomes
- `SDK-AI-003`: no network in SDK core
- `SDK-AI-004`: explain redaction by default
- `SDK-AI-005`: numeric ingestion uses decimal strings only
- `SDK-AI-006`: set-array sort normalize allowed, duplicates reject
- `SDK-AI-007`: unknown critical => quarantine, no apply

## Important boundary language

- Decimal strings are ingestion convenience, not protocol semantics.
- Set-array normalization is AI-ingestion only, not strict protocol relax.
- Base64 rule here is SDK ingestion contract, not protocol-wide encoding rule.
