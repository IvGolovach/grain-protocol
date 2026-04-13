import { SdkError } from "grain-sdk-ts/errors";
import { bytesEq, sha256Hex } from "../sdk-utils.js";

const TOKEN_SECRET = Symbol("sdk-ai-accepted-token-secret");

export type AcceptedPayload = {
  kind: "object" | "event";
  target_type: string;
  cid: string;
  canonical_bytes: Uint8Array;
  apply_plan:
    | {
        mode: "object_put";
      }
    | {
        mode: "event_append";
        event: {
          t: string;
          payload_cid: string;
          body: Record<string, unknown>;
          ak?: string;
        };
      };
};

type RegistryConfig = {
  max_pending: number;
  ttl_ms: number;
  now_ms: () => number;
};

type RegistryEntry = {
  payload: AcceptedPayload;
  digest_hex: string;
  expires_at_ms: number;
  consumed: boolean;
};

export class AcceptedToken {
  readonly id: string;
  readonly issued_at_ms: number;
  #secret: symbol;

  constructor(id: string, issuedAtMs: number, secret: symbol) {
    if (secret !== TOKEN_SECRET) {
      throw new SdkError("SDK_ERR_ACCEPT_TOKEN_FORGED", "accepted token cannot be constructed outside SDK");
    }
    this.id = id;
    this.issued_at_ms = issuedAtMs;
    this.#secret = secret;
  }

  isSdkToken(): boolean {
    return this.#secret === TOKEN_SECRET;
  }
}

export type ConsumeResult = {
  payload: AcceptedPayload;
  digest_hex: string;
};

export class AcceptedTokenRegistry {
  private readonly cfg: RegistryConfig;
  private readonly entries = new Map<string, RegistryEntry>();
  private sequence = 0;

  constructor(cfg?: Partial<RegistryConfig>) {
    this.cfg = {
      max_pending: cfg?.max_pending ?? 1024,
      ttl_ms: cfg?.ttl_ms ?? 10 * 60 * 1000,
      now_ms: cfg?.now_ms ?? (() => Date.now())
    };
  }

  issue(payload: AcceptedPayload): AcceptedToken {
    this.cleanup();
    if (this.entries.size >= this.cfg.max_pending) {
      throw new SdkError("SDK_ERR_ACCEPT_TOKEN_CAP_REACHED", "accepted token registry capacity reached");
    }

    this.sequence += 1;
    const now = this.cfg.now_ms();
    const tokenId = `sdk-ai-${this.sequence.toString(16)}-${sha256Hex(payload.canonical_bytes).slice(0, 16)}`;
    const digestHex = sha256Hex(payload.canonical_bytes);
    const entry: RegistryEntry = {
      payload: {
        ...payload,
        canonical_bytes: new Uint8Array(payload.canonical_bytes)
      },
      digest_hex: digestHex,
      expires_at_ms: now + this.cfg.ttl_ms,
      consumed: false
    };

    this.entries.set(tokenId, entry);
    return new AcceptedToken(tokenId, now, TOKEN_SECRET);
  }

  consume(token: unknown): ConsumeResult {
    if (!(token instanceof AcceptedToken) || !token.isSdkToken()) {
      throw new SdkError("SDK_ERR_ACCEPT_TOKEN_FORGED", "accepted token is not an SDK-issued opaque token");
    }

    const entry = this.entries.get(token.id);
    if (!entry) {
      throw new SdkError("SDK_ERR_ACCEPT_TOKEN_UNKNOWN", "accepted token is unknown");
    }

    const now = this.cfg.now_ms();
    if (entry.expires_at_ms < now) {
      this.entries.delete(token.id);
      throw new SdkError("SDK_ERR_ACCEPT_TOKEN_EXPIRED", "accepted token expired");
    }

    if (entry.consumed) {
      this.entries.delete(token.id);
      throw new SdkError("SDK_ERR_ACCEPT_TOKEN_UNKNOWN", "accepted token already consumed");
    }

    const actualDigest = sha256Hex(entry.payload.canonical_bytes);
    if (!bytesEq(new Uint8Array(Buffer.from(actualDigest, "hex")), new Uint8Array(Buffer.from(entry.digest_hex, "hex")))) {
      this.entries.delete(token.id);
      throw new SdkError("SDK_ERR_ACCEPT_TOKEN_FORGED", "accepted token registry digest mismatch");
    }

    entry.consumed = true;
    this.entries.set(token.id, entry);
    this.cleanup();
    return {
      payload: {
        ...entry.payload,
        canonical_bytes: new Uint8Array(entry.payload.canonical_bytes)
      },
      digest_hex: entry.digest_hex
    };
  }

  cleanup(): void {
    const now = this.cfg.now_ms();
    for (const [id, entry] of this.entries.entries()) {
      if (entry.expires_at_ms < now || entry.consumed) {
        this.entries.delete(id);
      }
    }
  }
}
