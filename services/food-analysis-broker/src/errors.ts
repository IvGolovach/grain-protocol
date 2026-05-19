import type { ErrorCode, ErrorShape } from "./types.js";

export class BrokerError extends Error {
  readonly status: number;
  readonly code: ErrorCode;
  readonly details?: Record<string, string | number | boolean>;

  constructor(status: number, code: ErrorCode, message: string, details?: Record<string, string | number | boolean>) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export function errorShape(error: BrokerError, requestId: string): ErrorShape {
  return {
    ok: false,
    error: {
      code: error.code,
      message: error.message,
      request_id: requestId,
      ...(error.details ? { details: error.details } : {})
    }
  };
}

export function internalError(requestId: string): ErrorShape {
  return {
    ok: false,
    error: {
      code: "INTERNAL_ERROR",
      message: "internal server error",
      request_id: requestId
    }
  };
}
