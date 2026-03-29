# grain-sdk-ts

Friendly, strict building blocks for apps on Grain.

If you are new here, start with:
- [SDK Start Here](../../../docs/human/sdk/start-here.md)
- [Minimal app example](../../../docs/human/sdk/minimal-app-example.md)
- Run `npm --prefix core/ts/grain-sdk run demo:e2e` for the smallest demo.

Use this README as a package map after the first demo.

What this package is for:
- helping apps use Grain safely
- keeping protocol rules unchanged
- keeping diagnostics and failures explicit
- making the safe path the easy path

What it does for you:
- strict-by-default behavior
- fail-closed handling for risky paths like CSPRNG and `cap_id` overwrite
- deterministic error messages with NES/vector references
- deterministic transport bundle import/export (`grain-transport-bundle-v1`)
- device lifecycle APIs that keep local authorization and ledger history in sync
- deterministic AI ingestion (`accept` -> `applyAccepted`)
- no outbound network behavior in the SDK core

For first examples, `payload_cid` can be a stable application identifier for the payload.
If you later store that payload as its own canonical Grain object, then using the real CID is the stronger pattern.

## Copy these commands

Install the shared runner and SDK build-time dependencies:

```bash
npm ci --prefix runner/typescript
npm ci --prefix core/ts/grain-sdk
```

Build output is not fully self-contained: the SDK build first builds the shared
TypeScript runner in `runner/typescript`, then emits SDK files.

Try the smallest end-to-end demo:

```bash
npm --prefix core/ts/grain-sdk run demo:e2e
```

Run SDK invariant checks:

```bash
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk run test:ai-boundary
```

Run the full protocol suite through the SDK runner:

```bash
npm --prefix core/ts/grain-sdk run run:protocol-suite
```

Build the SDK output:

```bash
npm --prefix core/ts/grain-sdk run build
```

If you want to go deeper after the first app, read:
- `core/ts/grain-sdk/src`
- `docs/human/sdk/architecture.md`
- `docs/human/sdk/errors.md`
- `docs/human/sdk/impossible-misuse.md`
