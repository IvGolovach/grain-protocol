# grain-sdk-ai-ts

Optional AI sidecar for `grain-sdk-ts`.

This package keeps AI ingestion out of the core SDK surface.
You opt in explicitly, create the sidecar from `GrainSdk`, and keep the rest of the SDK tree clean.

Quick start:

```bash
npm ci --prefix core/ts/grain-ts-core
npm ci --prefix core/ts/grain-sdk
npm ci --prefix core/ts/grain-sdk-ai
```

Minimal flow:

```ts
import { GrainSdk } from "grain-sdk-ts";
import { createGrainSdkAi } from "grain-sdk-ai-ts";

const sdk = new GrainSdk();
const ai = createGrainSdkAi(sdk);
```

Checks:

```bash
npm --prefix core/ts/grain-sdk run test:invariants
npm --prefix core/ts/grain-sdk-ai run test:boundary
```
