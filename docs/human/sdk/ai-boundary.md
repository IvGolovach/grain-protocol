# SDK AI Boundary

This page defines the deterministic SDK boundary for any model output.

## Core rule

Model output is always a suggestion until it passes:

1. `const ai = createGrainSdkAi(sdk)` (explicit opt-in sidecar)
2. `ai.accept(candidate)` (pure validation + canonicalization gate)
3. `ai.applyAccepted(token)` (explicit side effect)

No direct append path exists for raw AI candidates.

Minimal setup:

```ts
import { GrainSdk } from "grain-sdk-ts";
import { createGrainSdkAi } from "grain-sdk-ai-ts";

const sdk = new GrainSdk();
const ai = createGrainSdkAi(sdk);
```

## Deterministic outcomes

`accept()` returns one of:

- `accepted` with canonical bytes + CID + opaque token
- `quarantined` when unknown critical extensions are present
- `rejected` with deterministic error code + explain payload

`applyAccepted()` rejects forged/expired/unknown tokens deterministically.

## Side-effect in v1

In the current AI sidecar, `applyAccepted()` writes accepted canonical bytes to SDK object store under derived CID.
Ledger append remains an explicit application decision after acceptance.

## Security posture

- SDK AI boundary is model-agnostic.
- AI is not built into `GrainSdk`; you opt in with `createGrainSdkAi(sdk)`.
- SDK core and the AI sidecar have no outbound network calls.
- Tokens are opaque runtime objects, not JSON payloads.
- Quarantined candidates cannot be applied.
- Token timing behavior is configurable for deterministic tests on sidecar creation (`createGrainSdkAi(sdk, { now_ms })`).
