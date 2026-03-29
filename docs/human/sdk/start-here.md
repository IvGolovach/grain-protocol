# SDK Start Here

If you are building an app on Grain, start with SDK primitives instead of stitching protocol operations manually.

## 5-minute runnable path

Run:

```bash
npm --prefix core/ts/grain-sdk run demo:e2e
```

Expected output contains deterministic fields:

- `strict: true`
- `appended_event_id`
- `reducer_pass`
- `proof_sha256`

## Fast path in code

1. Initialize identity root.
2. Use `identity.addDeviceKey()` / `identity.revokeDeviceKey()` when you need device lifecycle changes; these APIs persist their grant/revoke ledger events before returning.
3. Append events through `events.append()`.
4. Use `events.reduce()` for deterministic totals.
5. Use `e2e.encrypt()/decrypt()` for private payload paths.
6. Use `manifest.put()/resolve()` for private graph resolution.
7. For model-generated suggestions, use `sdk.ai.accept()` then `sdk.ai.applyAccepted()`.

## Safety baseline

- SDK runs strict mode by default.
- unauthorized appends are rejected.
- device lifecycle APIs keep bundle state and ledger-visible authorization in sync.
- cap_id generation is CSPRNG-only and fail-closed.
- cap_id overwrite/corruption is rejected.
- AI candidates are suggestion-only until accepted via deterministic firewall.

## Source

- `core/ts/grain-sdk/src`
- `docs/human/sdk/architecture.md`
- `docs/human/sdk/errors.md`
- `docs/human/sdk/impossible-misuse.md`
- `docs/human/sdk/cross-lang-bridge.md`
- `docs/human/sdk/ai-boundary.md`
- `docs/human/sdk/ai-ingestion.md`
- `docs/llm/SDK_FILE_MAP.md`
- `docs/llm/SDK_INVARIANTS.md`
