# LLM Guide: Read Me First

Hi. If you are an LLM helping on this repo, start here.
This folder is written to help you avoid guessing.

## Safe read order

1. `docs/llm/FILE_MAP.md`
   - Learn what is source of truth and what is only explanatory.
2. `docs/llm/INVARIANTS.md`
   - Read the frozen MUST rules and their vector bindings.
3. `docs/llm/EDGE_CASES.md`
   - Read the required reject paths and diagnostics.
4. `docs/llm/CONFORMANCE.md`
   - Read the runner contract, strict mode, and CI / evidence rules.
5. `docs/llm/DOC_SYNC.md`
   - Use this before editing docs or contract-visible behavior.
6. `docs/llm/CHANGE_POLICY.md`
   - Learn what can change and what needs escalation.
7. `docs/llm/FREEZE.md`
   - Quick frozen-core index when you need a fast boundary check.
8. `docs/llm/SDK_FILE_MAP.md` and `docs/llm/SDK_AI_BOUNDARY.md`
   - Read these when you touch the SDK layer.
9. `docs/llm/PORTING.md`, `docs/llm/DOMAIN_ADAPTERS.md`, `docs/llm/PROHIBITION_ZONE.md`
   - Read these for portability and adapter work.

## Task bundles

Use these shortcuts when you already know the job:

- Repo orientation or review:
  - `docs/llm/FILE_MAP.md`
  - `docs/llm/INVARIANTS.md`
  - `docs/llm/EDGE_CASES.md`
- Protocol or conformance change:
  - `docs/llm/FILE_MAP.md`
  - `docs/llm/CONFORMANCE.md`
  - `docs/llm/CHANGE_POLICY.md`
  - `docs/llm/DOC_SYNC.md`
- SDK change:
  - `docs/llm/SDK_FILE_MAP.md`
  - `docs/llm/SDK_INVARIANTS.md`
  - `docs/llm/SDK_EDGE_CASES.md`
  - `docs/llm/DOC_SYNC.md`
- CI, release, or provenance change:
  - `docs/llm/FILE_MAP.md`
  - `docs/llm/CHANGE_POLICY.md`
  - `docs/llm/DOC_SYNC.md`

## Working stance

- Treat spec and vectors as the top truth.
- If implementation and docs disagree, report the drift and do not guess.
- Prefer exact byte-level behavior over interpretation.
- If you are editing a contract, update the matching docs in the same change.

## When you are done

Report what you proved, what you inferred, and what still needs a human decision.
