import { BrokerError } from "./errors.js";
import type { D1DatabaseBinding } from "./usage.js";

export type EntitlementTier = "free" | "pro";
export type EntitlementSource = "default_free" | "local_dev" | "storekit";

export type EntitlementRecord = {
  entitlementId: string;
  accountId: string;
  tier: EntitlementTier;
  source: EntitlementSource;
  productId?: string;
  originalTransactionId?: string;
  effectiveAtMs: number;
  expiresAtMs?: number;
  updatedAtMs: number;
};

export type EntitlementStore = {
  getActiveEntitlement(accountId: string, nowMs: number): Promise<EntitlementRecord>;
  upsertStoreKitEntitlement(input: {
    accountId: string;
    productId: string;
    originalTransactionId: string;
    effectiveAtMs: number;
    expiresAtMs?: number;
    updatedAtMs: number;
  }): Promise<EntitlementRecord>;
};

export class DisabledEntitlementStore implements EntitlementStore {
  async getActiveEntitlement(): Promise<EntitlementRecord> {
    throw entitlementStoreNotConfigured();
  }

  async upsertStoreKitEntitlement(): Promise<EntitlementRecord> {
    throw entitlementStoreNotConfigured();
  }
}

export class InMemoryEntitlementStore implements EntitlementStore {
  private readonly entitlements = new Map<string, EntitlementRecord>();

  async getActiveEntitlement(accountId: string, nowMs: number): Promise<EntitlementRecord> {
    const active = Array.from(this.entitlements.values())
      .filter((entry) => entry.accountId === accountId)
      .filter((entry) => entry.effectiveAtMs <= nowMs)
      .filter((entry) => entry.expiresAtMs === undefined || entry.expiresAtMs > nowMs)
      .sort(compareActiveEntitlements)[0];
    return active ?? defaultFreeEntitlement(accountId, nowMs);
  }

  async upsertStoreKitEntitlement(input: {
    accountId: string;
    productId: string;
    originalTransactionId: string;
    effectiveAtMs: number;
    expiresAtMs?: number;
    updatedAtMs: number;
  }): Promise<EntitlementRecord> {
    const entitlementId = storeKitEntitlementId(input.originalTransactionId);
    const record: EntitlementRecord = {
      entitlementId,
      accountId: input.accountId,
      tier: "pro",
      source: "storekit",
      productId: input.productId,
      originalTransactionId: input.originalTransactionId,
      effectiveAtMs: input.effectiveAtMs,
      ...(input.expiresAtMs === undefined ? {} : { expiresAtMs: input.expiresAtMs }),
      updatedAtMs: input.updatedAtMs
    };
    this.entitlements.set(entitlementId, record);
    return record;
  }
}

export class D1EntitlementStore implements EntitlementStore {
  constructor(private readonly database: D1DatabaseBinding) {}

  async getActiveEntitlement(accountId: string, nowMs: number): Promise<EntitlementRecord> {
    const row = await this.database
      .prepare(`
        SELECT
          entitlement_id,
          account_id,
          tier,
          source,
          product_id,
          original_transaction_id,
          effective_at_ms,
          expires_at_ms,
          updated_at_ms
        FROM entitlements
        WHERE account_id = ?1
          AND effective_at_ms <= ?2
          AND (expires_at_ms IS NULL OR expires_at_ms > ?2)
        ORDER BY
          CASE tier WHEN 'pro' THEN 1 ELSE 0 END DESC,
          updated_at_ms DESC
        LIMIT 1
      `)
      .bind(accountId, nowMs)
      .first<EntitlementRow>();
    return row ? entitlementFromRow(row) : defaultFreeEntitlement(accountId, nowMs);
  }

  async upsertStoreKitEntitlement(input: {
    accountId: string;
    productId: string;
    originalTransactionId: string;
    effectiveAtMs: number;
    expiresAtMs?: number;
    updatedAtMs: number;
  }): Promise<EntitlementRecord> {
    const entitlementId = storeKitEntitlementId(input.originalTransactionId);
    const row = await this.database
      .prepare(`
        INSERT INTO entitlements (
          entitlement_id,
          account_id,
          tier,
          source,
          product_id,
          original_transaction_id,
          effective_at_ms,
          expires_at_ms,
          updated_at_ms
        )
        VALUES (?1, ?2, 'pro', 'storekit', ?3, ?4, ?5, ?6, ?7)
        ON CONFLICT(entitlement_id)
        DO UPDATE SET
          account_id = excluded.account_id,
          tier = excluded.tier,
          source = excluded.source,
          product_id = excluded.product_id,
          original_transaction_id = excluded.original_transaction_id,
          effective_at_ms = excluded.effective_at_ms,
          expires_at_ms = excluded.expires_at_ms,
          updated_at_ms = excluded.updated_at_ms
        RETURNING
          entitlement_id,
          account_id,
          tier,
          source,
          product_id,
          original_transaction_id,
          effective_at_ms,
          expires_at_ms,
          updated_at_ms
      `)
      .bind(
        entitlementId,
        input.accountId,
        input.productId,
        input.originalTransactionId,
        input.effectiveAtMs,
        input.expiresAtMs ?? null,
        input.updatedAtMs
      )
      .first<EntitlementRow>();
    return entitlementFromRow(row);
  }
}

type EntitlementRow = {
  entitlement_id: string;
  account_id: string;
  tier: EntitlementTier;
  source: "local_dev" | "storekit";
  product_id?: string | null;
  original_transaction_id?: string | null;
  effective_at_ms: number;
  expires_at_ms?: number | null;
  updated_at_ms: number;
};

export function defaultFreeEntitlement(accountId: string, nowMs: number): EntitlementRecord {
  return {
    entitlementId: `default_free:${accountId}`,
    accountId,
    tier: "free",
    source: "default_free",
    effectiveAtMs: nowMs,
    updatedAtMs: nowMs
  };
}

function entitlementFromRow(row: EntitlementRow | null): EntitlementRecord {
  if (!row || !isSafeInteger(row.effective_at_ms) || !isSafeInteger(row.updated_at_ms)) {
    throw new BrokerError(500, "INTERNAL_ERROR", "entitlement row is invalid");
  }
  if (row.expires_at_ms !== undefined && row.expires_at_ms !== null && !isSafeInteger(row.expires_at_ms)) {
    throw new BrokerError(500, "INTERNAL_ERROR", "entitlement row is invalid");
  }
  return {
    entitlementId: row.entitlement_id,
    accountId: row.account_id,
    tier: row.tier,
    source: row.source,
    ...(row.product_id ? { productId: row.product_id } : {}),
    ...(row.original_transaction_id ? { originalTransactionId: row.original_transaction_id } : {}),
    effectiveAtMs: row.effective_at_ms,
    ...(row.expires_at_ms === undefined || row.expires_at_ms === null ? {} : { expiresAtMs: row.expires_at_ms }),
    updatedAtMs: row.updated_at_ms
  };
}

function storeKitEntitlementId(originalTransactionId: string): string {
  return `storekit:${originalTransactionId}`;
}

function compareActiveEntitlements(left: EntitlementRecord, right: EntitlementRecord): number {
  if (left.tier !== right.tier) {
    return left.tier === "pro" ? -1 : 1;
  }
  return right.updatedAtMs - left.updatedAtMs;
}

function entitlementStoreNotConfigured(): BrokerError {
  return new BrokerError(503, "PROVIDER_NOT_CONFIGURED", "entitlement store is not configured");
}

function isSafeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value);
}
