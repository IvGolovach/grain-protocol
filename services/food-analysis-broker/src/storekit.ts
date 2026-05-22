import type { EntitlementRecord, EntitlementStore } from "./entitlements.js";
import { BrokerError } from "./errors.js";
import type { D1DatabaseBinding } from "./usage.js";

export type StoreKitEnvironment = "Sandbox" | "Production";

const MEALMARK_PLUS_PRODUCT_IDS = new Set([
  "dev.grain.foodwallet.plus.monthly",
  "dev.grain.foodwallet.plus.yearly"
]);

export type VerifiedStoreKitTransaction = {
  transactionId: string;
  originalTransactionId: string;
  productId: string;
  environment: StoreKitEnvironment;
  purchaseDateMs: number;
  expiresDateMs?: number;
  revocationDateMs?: number;
  appAccountToken?: string;
};

export type StoreKitTransactionVerifier = {
  verifySignedTransaction(input: {
    signedTransaction: string;
  }): Promise<VerifiedStoreKitTransaction>;
};

export type StoreKitTransactionRecord = {
  transactionId: string;
  accountId: string;
  productId: string;
  originalTransactionId: string;
  environment: StoreKitEnvironment;
  signedTransactionInfo: string;
  verifiedAtMs: number;
  expiresAtMs?: number;
};

export type StoreKitTransactionStore = {
  upsertTransaction(input: StoreKitTransactionRecord): Promise<StoreKitTransactionRecord>;
};

export class DisabledStoreKitTransactionStore implements StoreKitTransactionStore {
  async upsertTransaction(): Promise<StoreKitTransactionRecord> {
    throw new BrokerError(503, "PROVIDER_NOT_CONFIGURED", "StoreKit transaction store is not configured");
  }
}

export class InMemoryStoreKitTransactionStore implements StoreKitTransactionStore {
  private readonly transactions = new Map<string, StoreKitTransactionRecord>();

  async upsertTransaction(input: StoreKitTransactionRecord): Promise<StoreKitTransactionRecord> {
    const record = { ...input };
    this.transactions.set(input.transactionId, record);
    return record;
  }
}

export class D1StoreKitTransactionStore implements StoreKitTransactionStore {
  constructor(private readonly database: D1DatabaseBinding) {}

  async upsertTransaction(input: StoreKitTransactionRecord): Promise<StoreKitTransactionRecord> {
    const row = await this.database
      .prepare(`
        INSERT INTO storekit_transactions (
          transaction_id,
          account_id,
          product_id,
          original_transaction_id,
          environment,
          signed_transaction_b64,
          verified_at_ms,
          expires_at_ms
        )
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
        ON CONFLICT(transaction_id)
        DO UPDATE SET
          account_id = excluded.account_id,
          product_id = excluded.product_id,
          original_transaction_id = excluded.original_transaction_id,
          environment = excluded.environment,
          signed_transaction_b64 = excluded.signed_transaction_b64,
          verified_at_ms = excluded.verified_at_ms,
          expires_at_ms = excluded.expires_at_ms
        RETURNING
          transaction_id,
          account_id,
          product_id,
          original_transaction_id,
          environment,
          signed_transaction_b64,
          verified_at_ms,
          expires_at_ms
      `)
      .bind(
        input.transactionId,
        input.accountId,
        input.productId,
        input.originalTransactionId,
        input.environment,
        input.signedTransactionInfo,
        input.verifiedAtMs,
        input.expiresAtMs ?? null
      )
      .first<StoreKitTransactionRow>();
    return transactionFromRow(row);
  }
}

export async function ingestStoreKitTransaction(input: {
  accountId: string;
  expectedAppAccountToken?: string;
  signedTransactionInfo: string;
  verifier?: StoreKitTransactionVerifier;
  transactionStore: StoreKitTransactionStore;
  entitlementStore: EntitlementStore;
  nowMs: number;
}): Promise<{
  transaction: StoreKitTransactionRecord;
  entitlement: EntitlementRecord;
}> {
  const signedTransactionInfo = normalizedRequestString(input.signedTransactionInfo, "signed_transaction_info");
  if (!input.verifier) {
    throw new BrokerError(503, "PROVIDER_NOT_CONFIGURED", "StoreKit transaction verifier is not configured");
  }

  const verified = assertVerifiedStoreKitTransaction(
    await input.verifier.verifySignedTransaction({ signedTransaction: signedTransactionInfo })
  );
  if (!MEALMARK_PLUS_PRODUCT_IDS.has(verified.productId)) {
    throw new BrokerError(400, "BAD_REQUEST", "StoreKit transaction product is not a MealMark Plus product");
  }
  const expectedAppAccountToken = normalizedOptionalUuidString(input.expectedAppAccountToken, "expected appAccountToken");
  const verifiedAppAccountToken = normalizedOptionalUuidString(verified.appAccountToken, "appAccountToken");
  if (!expectedAppAccountToken || !verifiedAppAccountToken) {
    throw new BrokerError(403, "FORBIDDEN", "StoreKit transaction requires a bound MealMark account");
  }
  if (verifiedAppAccountToken !== expectedAppAccountToken) {
    throw new BrokerError(403, "FORBIDDEN", "StoreKit transaction is not bound to this MealMark account");
  }
  const expiresAtMs = effectiveExpiresDateMs(verified);
  const transaction = await input.transactionStore.upsertTransaction({
    transactionId: verified.transactionId,
    accountId: input.accountId,
    productId: verified.productId,
    originalTransactionId: verified.originalTransactionId,
    environment: verified.environment,
    signedTransactionInfo,
    verifiedAtMs: input.nowMs,
    ...(expiresAtMs === undefined ? {} : { expiresAtMs })
  });
  await input.entitlementStore.upsertStoreKitEntitlement({
    accountId: input.accountId,
    productId: verified.productId,
    originalTransactionId: verified.originalTransactionId,
    effectiveAtMs: verified.purchaseDateMs,
    ...(expiresAtMs === undefined ? {} : { expiresAtMs }),
    updatedAtMs: input.nowMs
  });
  const entitlement = await input.entitlementStore.getActiveEntitlement(input.accountId, input.nowMs);
  return { transaction, entitlement };
}

type StoreKitTransactionRow = {
  transaction_id: string;
  account_id: string;
  product_id: string;
  original_transaction_id: string;
  environment: StoreKitEnvironment;
  signed_transaction_b64: string;
  verified_at_ms: number;
  expires_at_ms?: number | null;
};

function assertVerifiedStoreKitTransaction(value: unknown): VerifiedStoreKitTransaction {
  if (!isRecord(value)) {
    throw new BrokerError(502, "UPSTREAM_ERROR", "verified StoreKit transaction is invalid");
  }
  const appAccountToken = normalizedOptionalUuidString(value.appAccountToken, "appAccountToken");
  return {
    transactionId: normalizedString(value.transactionId, "transactionId"),
    originalTransactionId: normalizedString(value.originalTransactionId, "originalTransactionId"),
    productId: normalizedString(value.productId, "productId"),
    environment: assertEnvironment(value.environment),
    purchaseDateMs: safeInteger(value.purchaseDateMs, "purchaseDateMs"),
    ...(value.expiresDateMs === undefined ? {} : { expiresDateMs: safeInteger(value.expiresDateMs, "expiresDateMs") }),
    ...(value.revocationDateMs === undefined ? {} : { revocationDateMs: safeInteger(value.revocationDateMs, "revocationDateMs") }),
    ...(appAccountToken ? { appAccountToken } : {})
  };
}

function transactionFromRow(row: StoreKitTransactionRow | null): StoreKitTransactionRecord {
  if (!row || !Number.isSafeInteger(row.verified_at_ms)) {
    throw new BrokerError(500, "INTERNAL_ERROR", "StoreKit transaction row is invalid");
  }
  if (row.expires_at_ms !== undefined && row.expires_at_ms !== null && !Number.isSafeInteger(row.expires_at_ms)) {
    throw new BrokerError(500, "INTERNAL_ERROR", "StoreKit transaction row is invalid");
  }
  return {
    transactionId: row.transaction_id,
    accountId: row.account_id,
    productId: row.product_id,
    originalTransactionId: row.original_transaction_id,
    environment: row.environment,
    signedTransactionInfo: row.signed_transaction_b64,
    verifiedAtMs: row.verified_at_ms,
    ...(row.expires_at_ms === undefined || row.expires_at_ms === null ? {} : { expiresAtMs: row.expires_at_ms })
  };
}

function normalizedString(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new BrokerError(502, "UPSTREAM_ERROR", `verified StoreKit ${fieldName} is invalid`);
  }
  const trimmed = value.trim();
  if (!trimmed) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `verified StoreKit ${fieldName} is invalid`);
  }
  return trimmed;
}

function normalizedRequestString(value: string, fieldName: string): string {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new BrokerError(400, "BAD_REQUEST", `${fieldName} must be a non-empty string`);
  }
  return trimmed;
}

function normalizedOptionalUuidString(value: unknown, fieldName: string): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") {
    throw new BrokerError(502, "UPSTREAM_ERROR", `verified StoreKit ${fieldName} is invalid`);
  }
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  const lowercased = trimmed.toLowerCase();
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(lowercased)) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `verified StoreKit ${fieldName} is invalid`);
  }
  return lowercased;
}

function effectiveExpiresDateMs(verified: VerifiedStoreKitTransaction): number | undefined {
  const candidates = [verified.expiresDateMs, verified.revocationDateMs]
    .filter((value): value is number => value !== undefined);
  if (candidates.length === 0) return undefined;
  return Math.min(...candidates);
}

function safeInteger(value: unknown, fieldName: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new BrokerError(502, "UPSTREAM_ERROR", `verified StoreKit ${fieldName} is invalid`);
  }
  return value;
}

function assertEnvironment(value: unknown): StoreKitEnvironment {
  if (value !== "Sandbox" && value !== "Production") {
    throw new BrokerError(502, "UPSTREAM_ERROR", "verified StoreKit environment is invalid");
  }
  return value;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
