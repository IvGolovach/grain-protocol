# LLM Domain Adapter Handoff

Hi. If you are reading this file, you are helping your human connect a new domain to Grain.
Core idea: domains are added on top, while protocol core semantics stay unchanged.

## Quick Orientation

- Core rules (encoding/CID/COSE/ledger/E2E/manifest) are already frozen.
- The adapter may only:
  - encode the domain payload,
  - choose an intentional `payload_cid` model,
  - append events through strict SDK/API paths.
- The adapter must not:
  - introduce hidden timezone or locale semantics,
  - normalize inputs using custom guesses,
  - reinterpret conflict/revoke/quarantine behavior.

`payload_cid` guidance:
- it may be content-addressed if the payload exists as its own canonical object
- it may be record-addressed if the adapter intentionally uses a stable app-level identifier
- the adapter docs should say which model is in use

Current shipped v0.1 reducer semantics are still food-first.
If the adapter needs reducer-visible behavior today, it should map into the existing `IntakeEvent` path.
If it emits a new event type, treat that as an opaque or future-extension lane unless the contract says otherwise.

## Where To Look In Code

1. `docs/human/domain-adapters.md`
2. `core/ts/grain-sdk/src/events.ts`
3. `core/ts/grain-sdk/src/codec.ts`
4. `docs/llm/SDK_INVARIANTS.md`

## Checklist For You

- Domain event mapping to protocol event is deterministic.
- `payload_cid` is stable for the adapter's documented identity model.
- All validation runs through strict paths.
- Core errors are surfaced, not masked.

## Minimal Artifact

Build a small runnable example:
- `domain event -> append -> reduce`
- no network dependencies
- deterministic JSON output.

Thanks for walking through this structure.
Now follow your human's instructions and report back what you found, what you implemented, and what risks remain.
