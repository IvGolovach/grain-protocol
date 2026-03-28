import type { AppendEventInput } from "../src/types.js";

export type SensorEventV1 = {
  sensor_id: string;
  reading: number;
  unit: string;
  ts_ms: number;
};

export function toSdkEvent(input: SensorEventV1): AppendEventInput {
  return {
    t: "SensorEventV1",
    payload_cid: `sensor:${input.sensor_id}:${input.ts_ms}`,
    body: {
      sensor_id: input.sensor_id,
      reading: input.reading,
      unit: input.unit,
      ts_ms: input.ts_ms
    }
  };
}
