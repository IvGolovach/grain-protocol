import type { Json } from "./utils.ts";

export type SdkDiagCode = `SDK_ERR_${string}`;

export type AppendEventInput = {
  t: string;
  payload_cid: string;
  body: Record<string, Json>;
  ak?: string;
};

export type LedgerEvent = {
  t: string;
  ak: string;
  seq: bigint;
  payload_cid: string;
  body: Record<string, Json>;
};

export type ManifestRecord = {
  op: "put" | "del";
  cid: string;
  ak: string;
  seq: bigint;
  cap_id?: Uint8Array;
  chash?: Uint8Array;
  eligible?: boolean;
};

export type DeviceKey = {
  ak: string;
  label: string;
  pub_b64: string;
};

export type IdentityBundleV1 = {
  bundle_v: 1;
  root_kid: string;
  root_pub_b64: string;
  active_ak: string;
  device_keys: DeviceKey[];
  revoked_aks: string[];
  sync_secret_b64: string;
  seq_state: Record<string, string>;
};

export type EvidenceBundle = {
  bytes: Uint8Array;
  sha256_hex: string;
  manifest: Record<string, Json>;
};

export type ReduceResult = {
  pass: boolean;
  diag: string[];
  out: Record<string, Json>;
};
