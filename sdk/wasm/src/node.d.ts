export { GrainClient } from "./index.mjs";
export type {
  AcceptedScan,
  GrainScanAccept,
  GrainScanAcceptInput,
  GrainScanAcceptStatus,
  GrainScanPreview,
  GrainScanPreviewInput,
  GrainScanPreviewStatus,
  GrainStoreSnapshotInput,
  GrainStoreSnapshotResult,
  GrainStoreSnapshotStatus,
} from "./index.mjs";

export function createNodeGrainClient(options: { wasmPath: string }): Promise<GrainClient>;
