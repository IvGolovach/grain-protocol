export { GrainClient, GrainStaticTrustProvider } from "./index.mjs";
export type {
  AcceptedScan,
  GrainAcceptedScan,
  GrainScanAccept,
  GrainScanAcceptInput,
  GrainScanAcceptStatus,
  GrainScanPreview,
  GrainScanPreviewInput,
  GrainScanPreviewStatus,
  GrainTrustProvider,
  GrainTrustProviderInput,
  GrainStoreSnapshotInput,
  GrainStoreSnapshotResult,
  GrainStoreSnapshotStatus,
} from "./index.mjs";

export function createNodeGrainClient(options: { wasmPath: string }): Promise<GrainClient>;
