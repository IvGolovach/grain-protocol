import { BrokerError } from "./errors.js";
import { randomRequestId, sha256Hex } from "./runtime.js";
import type { D1DatabaseBinding } from "./usage.js";

export type AccountStatus = "active" | "deleted";

export type AccountRecord = {
  accountId: string;
  createdAtMs: number;
  updatedAtMs: number;
  status: AccountStatus;
  anonymousDeviceHash?: string;
  appAccountToken?: string;
};

export type AccountStore = {
  bootstrapAccount(input: {
    deviceIdHash?: string;
    appAccountToken?: string;
    nowMs: number;
  }): Promise<AccountRecord>;
  getAccount(accountId: string): Promise<AccountRecord | null>;
  deleteAccount(accountId: string, nowMs: number): Promise<AccountRecord | null>;
};

export class DisabledAccountStore implements AccountStore {
  async bootstrapAccount(): Promise<AccountRecord> {
    throw accountStoreNotConfigured();
  }

  async getAccount(): Promise<AccountRecord | null> {
    throw accountStoreNotConfigured();
  }

  async deleteAccount(): Promise<AccountRecord | null> {
    throw accountStoreNotConfigured();
  }
}

export class InMemoryAccountStore implements AccountStore {
  private readonly accounts = new Map<string, AccountRecord>();
  private readonly accountIdByDeviceHash = new Map<string, string>();
  private readonly accountIdByAppAccountToken = new Map<string, string>();

  async bootstrapAccount(input: { deviceIdHash?: string; appAccountToken?: string; nowMs: number }): Promise<AccountRecord> {
    const deviceIdHash = normalizedOptionalString(input.deviceIdHash);
    const appAccountToken = normalizedOptionalString(input.appAccountToken);
    const existingAccountId = appAccountToken
      ? this.accountIdByAppAccountToken.get(appAccountToken)
      : deviceIdHash ? this.accountIdByDeviceHash.get(deviceIdHash) : undefined;
    const accountId = existingAccountId ?? await createAccountId(appAccountToken ?? deviceIdHash);
    const existing = this.accounts.get(accountId);
    const record: AccountRecord = existing
      ? {
          ...existing,
          updatedAtMs: input.nowMs,
          status: "active",
          ...(deviceIdHash ? { anonymousDeviceHash: deviceIdHash } : {}),
          ...(appAccountToken ? { appAccountToken } : {})
        }
      : {
          accountId,
          createdAtMs: input.nowMs,
          updatedAtMs: input.nowMs,
          status: "active",
          ...(deviceIdHash ? { anonymousDeviceHash: deviceIdHash } : {}),
          ...(appAccountToken ? { appAccountToken } : {})
        };
    this.accounts.set(accountId, record);
    if (deviceIdHash) {
      this.accountIdByDeviceHash.set(deviceIdHash, accountId);
    }
    if (appAccountToken) {
      this.accountIdByAppAccountToken.set(appAccountToken, accountId);
    }
    return record;
  }

  async getAccount(accountId: string): Promise<AccountRecord | null> {
    return this.accounts.get(accountId) ?? null;
  }

  async deleteAccount(accountId: string, nowMs: number): Promise<AccountRecord | null> {
    const existing = this.accounts.get(accountId);
    if (!existing) return null;
    if (existing.anonymousDeviceHash) {
      this.accountIdByDeviceHash.delete(existing.anonymousDeviceHash);
    }
    if (existing.appAccountToken) {
      this.accountIdByAppAccountToken.delete(existing.appAccountToken);
    }
    const record: AccountRecord = {
      accountId,
      createdAtMs: existing.createdAtMs,
      updatedAtMs: nowMs,
      status: "deleted"
    };
    this.accounts.set(accountId, record);
    return record;
  }
}

export class D1AccountStore implements AccountStore {
  constructor(private readonly database: D1DatabaseBinding) {}

  async bootstrapAccount(input: { deviceIdHash?: string; appAccountToken?: string; nowMs: number }): Promise<AccountRecord> {
    const deviceIdHash = normalizedOptionalString(input.deviceIdHash);
    const appAccountToken = normalizedOptionalString(input.appAccountToken);
    const existing = await this.findBootstrapAccount({ deviceIdHash, appAccountToken });
    const accountId = existing?.accountId ?? await createAccountId(appAccountToken ?? deviceIdHash);
    const deviceIdHashToStore = existing?.appAccountToken ? existing.anonymousDeviceHash : deviceIdHash;
    const row = await this.database
      .prepare(`
        INSERT INTO accounts (account_id, created_at_ms, updated_at_ms, status, anonymous_device_hash, app_account_token)
        VALUES (?1, ?2, ?2, 'active', ?3, ?4)
        ON CONFLICT(account_id)
        DO UPDATE SET
          updated_at_ms = excluded.updated_at_ms,
          status = 'active',
          anonymous_device_hash = COALESCE(excluded.anonymous_device_hash, accounts.anonymous_device_hash),
          app_account_token = COALESCE(excluded.app_account_token, accounts.app_account_token)
        RETURNING account_id, created_at_ms, updated_at_ms, status, anonymous_device_hash, app_account_token
      `)
      .bind(accountId, input.nowMs, deviceIdHashToStore ?? null, appAccountToken ?? null)
      .first<AccountRow>();
    return accountFromRow(row);
  }

  private async findBootstrapAccount(input: {
    deviceIdHash?: string;
    appAccountToken?: string;
  }): Promise<AccountRecord | null> {
    if (input.appAccountToken) {
      const byAppToken = await this.database
        .prepare(`
          SELECT account_id, created_at_ms, updated_at_ms, status, anonymous_device_hash, app_account_token
          FROM accounts
          WHERE app_account_token = ?1
        `)
        .bind(input.appAccountToken)
        .first<AccountRow>();
      if (byAppToken) return accountFromRow(byAppToken);
    }

    if (input.deviceIdHash) {
      const byDevice = await this.database
        .prepare(`
          SELECT account_id, created_at_ms, updated_at_ms, status, anonymous_device_hash, app_account_token
          FROM accounts
          WHERE anonymous_device_hash = ?1
        `)
        .bind(input.deviceIdHash)
        .first<AccountRow>();
      if (byDevice) return accountFromRow(byDevice);
    }

    return null;
  }

  async getAccount(accountId: string): Promise<AccountRecord | null> {
    const row = await this.database
      .prepare(`
        SELECT account_id, created_at_ms, updated_at_ms, status, anonymous_device_hash, app_account_token
        FROM accounts
        WHERE account_id = ?1
      `)
      .bind(accountId)
      .first<AccountRow>();
    return row ? accountFromRow(row) : null;
  }

  async deleteAccount(accountId: string, nowMs: number): Promise<AccountRecord | null> {
    const row = await this.database
      .prepare(`
        UPDATE accounts
        SET
          status = 'deleted',
          updated_at_ms = ?2,
          anonymous_device_hash = NULL,
          app_account_token = NULL
        WHERE account_id = ?1
        RETURNING account_id, created_at_ms, updated_at_ms, status, anonymous_device_hash, app_account_token
      `)
      .bind(accountId, nowMs)
      .first<AccountRow>();
    return row ? accountFromRow(row) : null;
  }
}

type AccountRow = {
  account_id: string;
  created_at_ms: number;
  updated_at_ms: number;
  status: AccountStatus;
  anonymous_device_hash?: string | null;
  app_account_token?: string | null;
};

async function createAccountId(deviceIdHash: string | undefined): Promise<string> {
  if (deviceIdHash) {
    return `acct_${(await sha256Hex(deviceIdHash)).slice(0, 24)}`;
  }
  return `acct_${randomRequestId().replace(/-/g, "")}`;
}

function accountFromRow(row: AccountRow | null): AccountRecord {
  if (!row || !isSafeInteger(row.created_at_ms) || !isSafeInteger(row.updated_at_ms)) {
    throw new BrokerError(500, "INTERNAL_ERROR", "account row is invalid");
  }
  return {
    accountId: row.account_id,
    createdAtMs: row.created_at_ms,
    updatedAtMs: row.updated_at_ms,
    status: row.status,
    ...(row.anonymous_device_hash ? { anonymousDeviceHash: row.anonymous_device_hash } : {}),
    ...(row.app_account_token ? { appAccountToken: row.app_account_token } : {})
  };
}

function normalizedOptionalString(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}

function accountStoreNotConfigured(): BrokerError {
  return new BrokerError(503, "PROVIDER_NOT_CONFIGURED", "account store is not configured");
}

function isSafeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value);
}
