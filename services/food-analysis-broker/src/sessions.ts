import { BrokerError } from "./errors.js";
import { randomRequestId, sha256Hex } from "./runtime.js";
import type { D1DatabaseBinding } from "./usage.js";
import type { EntitlementTier } from "./entitlements.js";

export type SessionRecord = {
  sessionId: string;
  accountId: string;
  deviceId?: string;
  tier: EntitlementTier;
  issuedAtMs: number;
  expiresAtMs: number;
  revokedAtMs?: number;
};

export type IssuedSession = {
  accessToken: string;
  tokenType: "Bearer";
  session: SessionRecord;
};

export type SessionStore = {
  createSession(input: {
    accountId: string;
    deviceId?: string;
    tier: EntitlementTier;
    nowMs: number;
    expiresAtMs?: number;
  }): Promise<IssuedSession>;
  getSessionByToken(token: string, nowMs: number): Promise<SessionRecord | null>;
  revokeSessionByToken(token: string, nowMs: number): Promise<boolean>;
  revokeSessionsByAccount(accountId: string, nowMs: number): Promise<void>;
};

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export class DisabledSessionStore implements SessionStore {
  async createSession(): Promise<IssuedSession> {
    throw sessionStoreNotConfigured();
  }

  async getSessionByToken(): Promise<SessionRecord | null> {
    throw sessionStoreNotConfigured();
  }

  async revokeSessionByToken(): Promise<boolean> {
    throw sessionStoreNotConfigured();
  }

  async revokeSessionsByAccount(): Promise<void> {
    throw sessionStoreNotConfigured();
  }
}

export class InMemorySessionStore implements SessionStore {
  private readonly sessions = new Map<string, SessionRecord & { tokenHash: string }>();
  private readonly sessionIdByTokenHash = new Map<string, string>();

  async createSession(input: {
    accountId: string;
    deviceId?: string;
    tier: EntitlementTier;
    nowMs: number;
    expiresAtMs?: number;
  }): Promise<IssuedSession> {
    const token = createOpaqueSessionToken();
    const tokenHash = await hashSessionToken(token);
    const session: SessionRecord & { tokenHash: string } = {
      sessionId: createSessionId(),
      accountId: input.accountId,
      ...(input.deviceId ? { deviceId: input.deviceId } : {}),
      tier: input.tier,
      issuedAtMs: input.nowMs,
      expiresAtMs: input.expiresAtMs ?? input.nowMs + SESSION_TTL_MS,
      tokenHash
    };
    this.sessions.set(session.sessionId, session);
    this.sessionIdByTokenHash.set(tokenHash, session.sessionId);
    return {
      accessToken: token,
      tokenType: "Bearer",
      session: publicSessionRecord(session)
    };
  }

  async getSessionByToken(token: string, nowMs: number): Promise<SessionRecord | null> {
    const tokenHash = await hashSessionToken(token);
    const sessionId = this.sessionIdByTokenHash.get(tokenHash);
    if (!sessionId) return null;
    const session = this.sessions.get(sessionId);
    if (!session || session.revokedAtMs !== undefined || session.expiresAtMs <= nowMs) {
      return null;
    }
    return publicSessionRecord(session);
  }

  async revokeSessionByToken(token: string, nowMs: number): Promise<boolean> {
    const tokenHash = await hashSessionToken(token);
    const sessionId = this.sessionIdByTokenHash.get(tokenHash);
    if (!sessionId) return false;
    const session = this.sessions.get(sessionId);
    if (!session || session.revokedAtMs !== undefined) return false;
    this.sessions.set(sessionId, { ...session, revokedAtMs: nowMs });
    return true;
  }

  async revokeSessionsByAccount(accountId: string, nowMs: number): Promise<void> {
    for (const [sessionId, session] of this.sessions.entries()) {
      if (session.accountId === accountId && session.revokedAtMs === undefined) {
        this.sessions.set(sessionId, { ...session, revokedAtMs: nowMs });
      }
    }
  }
}

export class D1SessionStore implements SessionStore {
  constructor(private readonly database: D1DatabaseBinding) {}

  async createSession(input: {
    accountId: string;
    deviceId?: string;
    tier: EntitlementTier;
    nowMs: number;
    expiresAtMs?: number;
  }): Promise<IssuedSession> {
    const token = createOpaqueSessionToken();
    const tokenHash = await hashSessionToken(token);
    const expiresAtMs = input.expiresAtMs ?? input.nowMs + SESSION_TTL_MS;
    const row = await this.database
      .prepare(`
        INSERT INTO sessions (
          session_id,
          token_hash,
          account_id,
          device_id,
          tier,
          issued_at_ms,
          expires_at_ms,
          revoked_at_ms
        )
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, NULL)
        RETURNING session_id, account_id, device_id, tier, issued_at_ms, expires_at_ms, revoked_at_ms
      `)
      .bind(createSessionId(), tokenHash, input.accountId, input.deviceId ?? null, input.tier, input.nowMs, expiresAtMs)
      .first<SessionRow>();
    return {
      accessToken: token,
      tokenType: "Bearer",
      session: sessionFromRow(row)
    };
  }

  async getSessionByToken(token: string, nowMs: number): Promise<SessionRecord | null> {
    const tokenHash = await hashSessionToken(token);
    const row = await this.database
      .prepare(`
        SELECT session_id, account_id, device_id, tier, issued_at_ms, expires_at_ms, revoked_at_ms
        FROM sessions
        WHERE token_hash = ?1
          AND revoked_at_ms IS NULL
          AND expires_at_ms > ?2
      `)
      .bind(tokenHash, nowMs)
      .first<SessionRow>();
    return row ? sessionFromRow(row) : null;
  }

  async revokeSessionByToken(token: string, nowMs: number): Promise<boolean> {
    const tokenHash = await hashSessionToken(token);
    const row = await this.database
      .prepare(`
        UPDATE sessions
        SET revoked_at_ms = ?1
        WHERE token_hash = ?2
          AND revoked_at_ms IS NULL
        RETURNING session_id
      `)
      .bind(nowMs, tokenHash)
      .first<{ session_id: string }>();
    return row !== null;
  }

  async revokeSessionsByAccount(accountId: string, nowMs: number): Promise<void> {
    await this.database
      .prepare(`
        UPDATE sessions
        SET revoked_at_ms = ?2
        WHERE account_id = ?1
          AND revoked_at_ms IS NULL
        RETURNING session_id
      `)
      .bind(accountId, nowMs)
      .first<{ session_id: string }>();
  }
}

type SessionRow = {
  session_id: string;
  account_id: string;
  device_id?: string | null;
  tier: EntitlementTier;
  issued_at_ms: number;
  expires_at_ms: number;
  revoked_at_ms?: number | null;
};

function createOpaqueSessionToken(): string {
  const random = new Uint8Array(32);
  globalThis.crypto.getRandomValues(random);
  return `mmst_${base64UrlEncode(random)}`;
}

function createSessionId(): string {
  return `sess_${randomRequestId().replace(/-/g, "")}`;
}

async function hashSessionToken(token: string): Promise<string> {
  return sha256Hex(token);
}

function sessionFromRow(row: SessionRow | null): SessionRecord {
  if (!row || !isSafeInteger(row.issued_at_ms) || !isSafeInteger(row.expires_at_ms)) {
    throw new BrokerError(500, "INTERNAL_ERROR", "session row is invalid");
  }
  if (row.revoked_at_ms !== undefined && row.revoked_at_ms !== null && !isSafeInteger(row.revoked_at_ms)) {
    throw new BrokerError(500, "INTERNAL_ERROR", "session row is invalid");
  }
  return {
    sessionId: row.session_id,
    accountId: row.account_id,
    ...(row.device_id ? { deviceId: row.device_id } : {}),
    tier: row.tier,
    issuedAtMs: row.issued_at_ms,
    expiresAtMs: row.expires_at_ms,
    ...(row.revoked_at_ms === undefined || row.revoked_at_ms === null ? {} : { revokedAtMs: row.revoked_at_ms })
  };
}

function publicSessionRecord(session: SessionRecord & { tokenHash?: string }): SessionRecord {
  return {
    sessionId: session.sessionId,
    accountId: session.accountId,
    ...(session.deviceId ? { deviceId: session.deviceId } : {}),
    tier: session.tier,
    issuedAtMs: session.issuedAtMs,
    expiresAtMs: session.expiresAtMs,
    ...(session.revokedAtMs === undefined ? {} : { revokedAtMs: session.revokedAtMs })
  };
}

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return globalThis.btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/u, "");
}

function sessionStoreNotConfigured(): BrokerError {
  return new BrokerError(503, "PROVIDER_NOT_CONFIGURED", "session store is not configured");
}

function isSafeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value);
}
