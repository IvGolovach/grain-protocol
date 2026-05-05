export type GrainScanPreviewStatus = "Verified" | "Untrusted" | "Rejected";
export type GrainScanAcceptStatus = "Accepted" | "AlreadyAccepted" | "Rejected";

export interface GrainScanPreviewInput {
  qrString: string;
  trustPubB64?: string | null;
}

export interface GrainScanAcceptInput {
  qrString: string;
  trustPubB64: string;
}

export interface GrainScanPreview {
  status: GrainScanPreviewStatus;
  diag: string[];
  coseB64: string | null;
}

export interface GrainScanAccept {
  status: GrainScanAcceptStatus;
  diag: string[];
  scanId: string | null;
  coseB64: string | null;
  trustPubB64: string | null;
}

export interface GrainAcceptedScan {
  scanId: string;
  coseB64: string;
  trustPubB64: string;
}

export class GrainClient {
  constructor(wasmExports: WebAssembly.Exports);
  scanPreview(input: GrainScanPreviewInput): GrainScanPreview;
  scanAccept(input: GrainScanAcceptInput): GrainScanAccept;
  listAcceptedScans(): GrainAcceptedScan[];
  close(): void;
}

export function createGrainClientFromInstance(instance: WebAssembly.Instance): GrainClient;
