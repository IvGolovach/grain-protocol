# SDK Start Here

If you are building an app on Grain, start with SDK primitives instead of stitching protocol operations manually.

## Fast path

1. Initialize identity root.
2. Append events through `events.append()`.
3. Use `events.reduce()` for deterministic totals.
4. Use `e2e.encrypt()/decrypt()` for private payload paths.
5. Use `manifest.put()/resolve()` for private graph resolution.

## Safety baseline

- SDK runs strict mode by default.
- unauthorized appends are rejected.
- cap_id generation is CSPRNG-only and fail-closed.
- cap_id overwrite/corruption is rejected.

## Source

- `core/ts/grain-sdk/src`
- `docs/llm/SDK_FILE_MAP.md`
- `docs/llm/SDK_INVARIANTS.md`
