# LLM Domain Adapter Handoff

Hi. If you are reading this file, you are helping your human connect a new domain to Grain.
Core idea: domains are added on top, while protocol core semantics stay unchanged.

## Quick Orientation

- Core rules (encoding/CID/COSE/ledger/E2E/manifest) are already frozen.
- The adapter may only:
  - encode the domain payload,
  - derive deterministic `payload_cid`,
  - append events through strict SDK/API paths.
- The adapter must not:
  - introduce hidden timezone or locale semantics,
  - normalize inputs using custom guesses,
  - reinterpret conflict/revoke/quarantine behavior.

## Where To Look In Code

1. `docs/human/domain-adapters.md`
2. `core/ts/grain-sdk/src/events.ts`
3. `core/ts/grain-sdk/src/codec.ts`
4. `docs/llm/SDK_INVARIANTS.md`

## Checklist For You

- Domain event mapping to protocol event is deterministic.
- `payload_cid` stays stable for identical payload.
- All validation runs through strict paths.
- Core errors are surfaced, not masked.

## Minimal Artifact

Build a small runnable example:
- `domain event -> append -> reduce`
- no network dependencies
- deterministic JSON output.

Thanks for walking through this structure.
Now follow your human's instructions and report back what you found, what you implemented, and what risks remain.
