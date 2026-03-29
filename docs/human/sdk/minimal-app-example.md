# Minimal App Example

This is the smallest Grain app we recommend for a first try.

It does four things:
- creates an SDK instance
- creates a root identity
- appends one event
- reduces the event list into a deterministic result

## 1) Install build dependencies

```bash
npm ci --prefix runner/typescript
npm ci --prefix core/ts/grain-sdk
```

## 2) Build the SDK once

The SDK build is not self-contained: it uses the shared TypeScript runner
output first, then emits the SDK files.

```bash
npm --prefix core/ts/grain-sdk run build
```

## 3) Create a tiny app file

Save this as `minimal-app.mjs` in the repo root:

```js
import { GrainSdk } from "./core/ts/grain-sdk/dist/src/index.js";

async function main() {
  const sdk = new GrainSdk();
  await sdk.identity.createRoot();

  const appended = await sdk.events.append({
    t: "IntakeEvent",
    payload_cid: "cid:minimal-app:1",
    body: {
      mean: { kcal: 42 },
      var: { kcal: 0 }
    }
  });

  const reduced = await sdk.events.reduce();

  console.log(JSON.stringify({
    strict: true,
    appended_event_id: appended.event_id,
    reducer_pass: reduced.pass,
    reducer_diag: reduced.diag,
    reducer_out: reduced.out
  }, null, 2));
}

main().catch((err) => {
  const msg = err instanceof Error ? err.message : "unknown";
  console.error(`minimal app failed: ${msg}`);
  process.exit(1);
});
```

## 4) Run it

```bash
node minimal-app.mjs
```

## What you should see

You should get a JSON object with:
- `strict: true`
- `appended_event_id`
- `reducer_pass: true`
- `reducer_diag: []`

If you see an error, start over from the build step and make sure you are running the file from the repo root.

## Why this example is small

This example stays on the safe path:
- the SDK creates the identity root
- the SDK appends the event
- the SDK reduces the ledger

That keeps the first success easy to understand before you add device keys, private sync, manifests, or AI helpers.
