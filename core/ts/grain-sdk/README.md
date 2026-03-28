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

Install SDK build-time dependencies:

```bash
npm ci --prefix core/ts/grain-sdk
```

Run one conformance vector through SDK runner:

```bash
npm --prefix core/ts/grain-sdk run run:vector -- conformance/vectors/cid/POS-CID-001.json
```

Run SDK invariant tests:

```bash
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk run test:ai-boundary
```

Run SDK end-to-end demo:

```bash
npm --prefix core/ts/grain-sdk run demo:e2e
```

Run full protocol suite through SDK runner:

```bash
npm --prefix core/ts/grain-sdk run run:protocol-suite
```

Build the stable JS output explicitly:

```bash
npm --prefix core/ts/grain-sdk run build
```
