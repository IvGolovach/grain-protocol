export class SdkError extends Error {
  public readonly code: string;
  public readonly layer: "sdk" | "core";

  constructor(code: string, message?: string, layer: "sdk" | "core" = "sdk") {
    super(message ?? code);
    this.code = code;
    this.layer = layer;
    this.name = "SdkError";
  }
}

export function toSdkError(err: unknown): SdkError {
  if (err instanceof SdkError) {
    return err;
  }

  if (err && typeof err === "object" && "code" in err) {
    const code = (err as { code: unknown }).code;
    if (typeof code === "string") {
      return new SdkError(code, code, code.startsWith("SDK_ERR_") ? "sdk" : "core");
    }
  }

  return new SdkError("SDK_ERR_INTERNAL", "Unexpected SDK error");
}
