# SDK_CONFORMANCE

Hi teammate LLM. This file links SDK behavior to executable checks.

## Protocol suite through SDK

SDK runner path:
- `core/ts/grain-sdk/src/cli.ts`

Runner contract:
```bash
npm --prefix core/ts/grain-sdk run run:vector -- <vector.json>
```

Full protocol suite execution through SDK runner:
```bash
npm --prefix core/ts/grain-sdk run run:protocol-suite
```

## SDK-specific invariants suite

```bash
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk-ai run test:boundary
```

Expected contract:
- pass when all SDK-INV checks succeed
- deterministic JSON summary with `total`, `failed`, and per-check status
- SDK invariants currently cover `SDK-INV-0001` through `SDK-INV-0015` and `SDK-AI-000` through `SDK-AI-007`

## Portable client core

Rust client workflow checks:

```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-client-core
```

Expected contract:
- scan preview preserves explicit trust boundaries
- malformed scan/trust/signature paths reject deterministically
- valid scan without trust remains `Untrusted`, not `Verified`

## Diagnostics contract

- Core diagnostics are preserved and not renamed.
- SDK-only diagnostics use `SDK_ERR_*` namespace.
- SDK import/transport boundaries reject malformed non-standard base64 deterministically.
- Portable generated SDKs bind workflow APIs and keep raw protocol operations out of the main app surface.
- AI boundary explain payload is deterministic and redacted by default.
- structured_v1 field typing must be explicit (profile table or explicit pointer maps).

## SDK no-network policy

```bash
python3 tools/ci/check_sdk_no_network.py
```

This is a hard gate. SDK core and the AI sidecar must stay vendor/network agnostic.

If this mapping drifts, report a blocking issue before proposing any semantic change.
