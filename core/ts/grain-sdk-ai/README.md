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
npm --prefix core/ts/grain-sdk-ai run test:food-graph
```

## MealMark Food Graph

`grain-sdk-ai-ts` also ships the optional MealMark Food Graph sidecar. It is a
local, advisory ingredient graph built from pinned Epicure artifacts and
committed into this package under `food-graph-artifacts/`.

Runtime rules:

- no Hugging Face or network call is made at runtime;
- outputs are advisory suggestions only;
- kcal, variance, record trust, nutrition confidence, and draft confirmation
  state are never changed by the graph;
- raw photos and raw embedding vectors are not accepted or persisted.

Minimal flow:

```ts
import { loadLocalFoodGraphArtifact, LocalFoodGraphProvider } from "grain-sdk-ai-ts";

const graph = new LocalFoodGraphProvider(loadLocalFoodGraphArtifact());
const ingredients = graph.resolveIngredients(["Greek yogurt", "walnuts", "honey"]);
const pairings = graph.suggestPairings(["ramen noodle", "pork", "egg"], { model: "core" });
const sourceRef = graph.sourceRefFor(ingredients);
```

Use `sourceRef` only as app metadata before a user-confirmed Food Wallet draft.
Do not treat it as a verified nutrition source.

To rebuild the artifact intentionally:

```bash
/tmp/epicure-spike-venv/bin/python tools/food_graph/build_mealmark_food_graph.py
npm --prefix core/ts/grain-sdk-ai run test:food-graph
```

The builder is an update tool. It may use `huggingface_hub`; the package runtime
must not.
