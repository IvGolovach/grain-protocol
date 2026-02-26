# grain-sdk-ts (TOR-SDK-A01 + TOR-SDK-A03)

Universal, domain-neutral SDK primitives for building on Grain without changing protocol semantics.

Principles:
- strict-by-default
- no new protocol semantics
- core diagnostics preserved
- fail-closed for risky paths (CSPRNG, cap overwrite)
- deterministic error descriptors (category + NES/vector refs)
- deterministic transport bundle import/export (`grain-transport-bundle-v1`)
- deterministic AI ingestion firewall (`accept` -> `applyAccepted`)
- no outbound network behavior in SDK core

## Quick commands

Run one conformance vector through SDK runner:

```bash
node --experimental-strip-types core/ts/grain-sdk/src/cli.ts run --strict --vector conformance/vectors/cid/POS-CID-001.json
```

Run SDK invariant tests:

```bash
node --experimental-strip-types core/ts/grain-sdk/scripts/test-sdk-invariants.ts
node --experimental-strip-types core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts
```

Run SDK end-to-end demo:

```bash
node --experimental-strip-types core/ts/grain-sdk/scripts/demo-end-to-end.ts
```

Run full protocol suite through SDK runner:

```bash
node --experimental-strip-types core/ts/grain-sdk/scripts/run-protocol-suite.ts
```
