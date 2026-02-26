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
node --experimental-strip-types core/ts/grain-sdk/scripts/test-sdk-ai-boundary.ts
```

Expected contract:
- pass when all SDK-INV checks succeed
- deterministic JSON summary with `total`, `failed`, and per-check status
- SDK invariants currently cover `SDK-INV-0001` through `SDK-INV-0010` and `SDK-AI-001` through `SDK-AI-007`

## Diagnostics contract

- Core diagnostics are preserved and not renamed.
- SDK-only diagnostics use `SDK_ERR_*` namespace.
- AI boundary explain payload is deterministic and redacted by default.
- structured_v1 field typing must be explicit (profile table or explicit pointer maps).

## SDK no-network policy

```bash
python3 tools/ci/check_sdk_no_network.py
```

This is a hard gate. SDK core must stay vendor/network agnostic.

If this mapping drifts, report a blocking issue before proposing any semantic change.
