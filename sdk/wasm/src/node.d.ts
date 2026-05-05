export { GrainClient } from "./index.mjs";
export type {
  AcceptedScan,
  GrainScanAccept,
  GrainScanAcceptInput,
  GrainScanAcceptStatus,
  GrainScanPreview,
  GrainScanPreviewInput,
  GrainScanPreviewStatus,
} from "./index.mjs";

export function createNodeGrainClient(options: { wasmPath: string }): Promise<GrainClient>;
