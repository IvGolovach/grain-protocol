#!/usr/bin/env node
import { GrainSdk } from "../src/index.ts";

async function main(): Promise<void> {
  const sdk = new GrainSdk();
  await sdk.identity.createRoot();

  const sensorEvent = {
    t: "SensorEventV1",
    payload_cid: "sensor:thermo-1:1700000000000",
    body: {
      sensor_id: "thermo-1",
      reading: 21.4,
      unit: "C",
      ts_ms: 1700000000000
    }
  } as const;

  const appended = await sdk.events.append({
    t: sensorEvent.t,
    payload_cid: sensorEvent.payload_cid,
    body: { ...sensorEvent.body }
  });

  const reduced = await sdk.events.reduce();
  const proof = await sdk.evidence.generateProofBundle({
    suite_summary: {
      demo: "sdk-end-to-end"
    }
  });

  const out = {
    strict: true,
    appended_event_id: appended.event_id,
    reducer_pass: reduced.pass,
    reducer_diag: reduced.diag,
    proof_sha256: proof.sha256_hex
  };

  process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
}

main().catch((err) => {
  const msg = err instanceof Error ? err.message : "unknown";
  process.stderr.write(`SDK demo failed: ${msg}\n`);
  process.exit(1);
});
