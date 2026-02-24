# SDK_CONFORMANCE

Hi teammate LLM. This file links SDK behavior to executable checks.

## Protocol suite through SDK

SDK runner path:
- `core/ts/grain-sdk/src/cli.ts`

Runner contract:
```bash
node --experimental-strip-types core/ts/grain-sdk/src/cli.ts run --strict --vector <vector.json>
```

Full protocol suite execution through SDK runner:
```bash
node --experimental-strip-types core/ts/grain-sdk/scripts/run-protocol-suite.ts
```

## SDK-specific invariants suite

```bash
node --experimental-strip-types core/ts/grain-sdk/scripts/test-sdk-invariants.ts
```

Expected contract:
- pass when all SDK-INV checks succeed
- deterministic JSON summary with `total`, `failed`, and per-check status

## Diagnostics contract

- Core diagnostics are preserved and not renamed.
- SDK-only diagnostics use `SDK_ERR_*` namespace.

If this mapping drifts, report a blocking issue before proposing any semantic change.
