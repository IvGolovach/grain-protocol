# Domain Adapters on Top of Grain

Grain core is domain-neutral at the infrastructure layer. Domain meaning lives in adapter code.
The shipped v0.1 reducer semantics are still food-first.

That means an adapter should be explicit about which job it is doing:
- mapping outside data into today's reducer-visible `IntakeEvent` path
- carrying an app-defined domain event that current v0.1 reducers will treat as opaque

The adapter adds domain structure, but it should not rewrite protocol semantics.

## Two adapter patterns

### 1) Reducer-visible adapter

Use this when you want deterministic reducer output in shipped v0.1.
Map your source data into `IntakeEvent` and populate the reducer-visible `mean` / `var` fields.

### 2) Opaque domain event

Use this when you want to preserve a domain record with a new `t` value.
That event can still be stored, exported, and forwarded, but today's v0.1 reducer does not give it built-in semantics.

See also:
- `core/ts/grain-sdk/examples/sensor-event-v1.ts`
- `docs/human/building-on-grain.md`

## Adapter contract

- Your adapter owns domain meaning, field mapping, and serialization choices for the source data.
- Grain owns validation, signatures, ledger semantics, manifest rules, and transport rules.
- No adapter may bypass strict validation.
- No adapter may add hidden ordering, timezone, locale, or normalization semantics.
- The adapter docs should say what identity model `payload_cid` uses.

## About `payload_cid`

- In current v0.1 ledger semantics, `payload_cid` is a stable payload identifier string carried in the event envelope.
- It does not have to be a literal CID in a small app adapter.
- If your app stores the payload as a separate canonical Grain object, then using that real CID is ideal.
- If your app does not do that yet, use an intentional stable identifier such as `meal-scan:<capture_id>` or `sensor:<sensor_id>:<ts_ms>`.
- Avoid fake CID-looking strings unless they are real CIDs.

## Recommended shape today

If you want reducer-visible behavior in shipped v0.1, emit `IntakeEvent` and keep the reducer-visible fields explicit:
- `mean`
- `var`
- any extra adapter metadata you need

If you emit a new event type today, expect store/forward behavior, not built-in reducer output.

## Minimal pattern: map a meal scan into `IntakeEvent`

```ts
import type { AppendEventInput } from "../../core/ts/grain-sdk/src/types.js";

type MealScan = {
  capture_id: string;
  mean_kcal: number;
  var_kcal: number;
  ts_ms: number;
};

export function toSdkEvent(input: MealScan): AppendEventInput {
  return {
    t: "IntakeEvent",
    payload_cid: `meal-scan:${input.capture_id}`,
    body: {
      mean: { kcal: input.mean_kcal },
      var: { kcal: input.var_kcal },
      ts_ms: input.ts_ms,
      source_class: "estimated"
    }
  };
}
```

This keeps the source-domain identity (`capture_id`) while still using the reducer-visible event path that exists today.

## Avoid these mistakes

- Do not imply that `payload_cid` is always a real CID if your adapter is only using a stable app-level identifier.
- Do not let the adapter invent its own ordering or normalization rules.
- Do not assume a new event type gets reducer semantics automatically.

## Next reads

- `docs/human/sdk/start-here.md`
- `docs/human/sdk/minimal-app-example.md`
- `docs/human/why-not-json.md`
