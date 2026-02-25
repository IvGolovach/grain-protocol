# Domain Adapters on Top of Grain

Grain core is domain-neutral at the infrastructure layer. Domain meaning lives in adapter code.

## Adapter contract

- Input: domain event payload + domain schema version.
- Output: a protocol event with deterministic bytes and stable `payload_cid`.
- No adapter is allowed to bypass strict validation.
- No adapter is allowed to add hidden ordering, timezone, or normalization semantics.

## Required fields for adapter output

- `t`: protocol event type.
- `payload_cid`: CID over canonical bytes of domain payload object.
- `body`: protocol-compatible mean/var payload (or domain-specific extension under allowed schema).
- `domain_name`: short identifier.
- `domain_version`: adapter version string.

## Minimal example (`SensorEvent v1`)

```ts
import { GrainSdk } from "../../core/ts/grain-sdk/src/index.ts";

const sdk = new GrainSdk();
await sdk.identity.createRoot();

const sensorPayload = {
  sensor_id: "sensor-A7",
  reading: "23.4",
  unit: "C",
  domain_name: "sensor",
  domain_version: "v1"
};

const payloadBytes = new TextEncoder().encode(JSON.stringify(sensorPayload));
const payloadCid = `cid:sensor:${Buffer.from(payloadBytes).toString("base64url")}`;

await sdk.events.append({
  t: "IntakeEvent",
  payload_cid: payloadCid,
  body: { mean: { value: 234n }, var: { value: 0n } }
});

const reduced = await sdk.events.reduce();
console.log(reduced);
```

The adapter adds domain payload structure but never changes protocol semantics.
