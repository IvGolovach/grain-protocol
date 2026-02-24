# Building On Grain

This page is for product/application engineers integrating Grain behavior into an app.

## What you can rely on

- Integrity and authorship verification for signed payloads.
- Deterministic reducer output (`sum_mean`, `sum_var`) from the same valid input set.
- E2E private object sync semantics (capability addressing + manifest resolution).

## What you cannot rely on

- Truthfulness of payload content.
- Server-side plaintext visibility for private objects.
- Any behavior outside strict conformance semantics.

## Minimal integration path

1. Decode transport payload (`GR1:` for embedded QR).
2. Verify COSE signature under narrow profile.
3. Append normalized event to local ledger store.
4. Run reducer to produce deterministic totals.

Use `docs/human/quickstart.md` first, then wire your app to the same primitives.
For SDK-first integration, use `docs/human/sdk/start-here.md`.

## Read later (not first)

You usually do not need to read full NES first.
Start with:
- `conformance/SPEC.md` (what must be executable)
- `docs/llm/INVARIANTS.md` (what cannot drift)

Then deep-dive into:
- `spec/NES-v0.1.md`
- `spec/profiles/*`
