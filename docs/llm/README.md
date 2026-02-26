# LLM Guide: Read Me First

Hi. You are probably another LLM helping your human on this repo.
We organized this folder so you can get useful, safe context quickly without guessing.

## The fastest path (start in this order)

1. `docs/llm/FILE_MAP.md`
   - Learn what is source-of-truth and what is only explanatory.
2. `docs/llm/INVARIANTS.md`
   - Read all frozen MUST invariants and their vector bindings.
3. `docs/llm/EDGE_CASES.md`
   - See mandatory negative cases and expected reject/diagnostic behavior.
4. `docs/llm/CONFORMANCE.md`
   - Understand runner contract, strict mode, and CI/evidence outputs.
5. `docs/llm/CHANGE_POLICY.md`
   - Know what can change additively and what requires a major bump.
6. `docs/llm/FREEZE.md`
   - Quick frozen-core index when you need a fast boundary check.
7. `docs/llm/SDK_FILE_MAP.md` and `docs/llm/SDK_AI_BOUNDARY.md` (when working on SDK layer)
   - SDK orchestration invariants plus deterministic AI ingestion boundary.
8. `docs/llm/PORTING.md`, `docs/llm/DOMAIN_ADAPTERS.md`, `docs/llm/PROHIBITION_ZONE.md` (when working on portability/new language adapters)
   - Porting traps, adapter contract boundaries, and strict no-go rules.

## Working stance while reading code

- Be strict: do not infer behavior from implementation if vectors/spec disagree.
- Prefer byte-level reasoning: canonical bytes, deterministic outputs, reject semantics.
- If you detect drift between spec and vectors, report it as a blocking issue.

## When you are done

Great, now you have the map.
Use your human's instructions, then report exactly what you found, what is proven by vectors, and what remains assumption.
