import { BrokerError } from "./errors.js";
import type { BrokerAuthContext } from "./auth.js";

export type UsageFeature = "photo_analysis" | "food_search";

export type UsageDecision = {
  allowed: boolean;
  limit: number;
  used: number;
  resetAtMs: number;
};

export type UsageLimiter = {
  reserve(input: {
    auth: BrokerAuthContext;
    feature: UsageFeature;
    requestId: string;
  }): Promise<UsageDecision>;
};

export type D1DatabaseBinding = {
  prepare(query: string): D1PreparedStatementBinding;
};

export type D1PreparedStatementBinding = {
  bind(...values: Array<string | number | null>): D1PreparedStatementBinding;
  first<T = Record<string, unknown>>(): Promise<T | null>;
};

export class NoopUsageLimiter implements UsageLimiter {
  async reserve(input: { auth: BrokerAuthContext; feature: UsageFeature; requestId: string }): Promise<UsageDecision> {
    const limit = input.auth.tier === "pro" ? 500 : 10;
    return {
      allowed: true,
      limit,
      used: 0,
      resetAtMs: startOfNextUtcMonth()
    };
  }
}

export class D1UsageLimiter implements UsageLimiter {
  constructor(private readonly database: D1DatabaseBinding) {}

  async reserve(input: {
    auth: BrokerAuthContext;
    feature: UsageFeature;
    requestId: string;
  }): Promise<UsageDecision> {
    const bucketStartMs = startOfCurrentUtcMonth();
    const resetAtMs = startOfNextUtcMonth();
    const limit = monthlyLimit(input.auth.tier, input.feature);
    const nowMs = Date.now();
    await this.ensureAccount(input.auth.accountId, nowMs);
    const row = await this.database
      .prepare(`
        INSERT INTO usage_buckets (account_id, feature, bucket_start_ms, used, limit_value, updated_at_ms)
        VALUES (?1, ?2, ?3, 1, ?4, ?5)
        ON CONFLICT(account_id, feature, bucket_start_ms)
        DO UPDATE SET
          used = usage_buckets.used + 1,
          limit_value = excluded.limit_value,
          updated_at_ms = excluded.updated_at_ms
        RETURNING used
      `)
      .bind(input.auth.accountId, input.feature, bucketStartMs, limit, nowMs)
      .first<{ used: number }>();
    const used = integerFrom(row?.used) ?? limit + 1;
    return {
      allowed: used <= limit,
      limit,
      used,
      resetAtMs
    };
  }

  private async ensureAccount(accountId: string, nowMs: number): Promise<void> {
    await this.database
      .prepare(`
        INSERT INTO accounts (account_id, created_at_ms, updated_at_ms, status)
        VALUES (?1, ?2, ?2, 'active')
        ON CONFLICT(account_id)
        DO UPDATE SET
          updated_at_ms = excluded.updated_at_ms
        RETURNING account_id
      `)
      .bind(accountId, nowMs)
      .first<{ account_id: string }>();
  }
}

export async function assertUsageAllowed(
  limiter: UsageLimiter,
  input: {
    auth: BrokerAuthContext;
    feature: UsageFeature;
    requestId: string;
  }
): Promise<void> {
  const decision = await limiter.reserve(input);
  if (!decision.allowed) {
    throw new BrokerError(429, "RATE_LIMITED", "MealMark usage limit reached", {
      feature: input.feature,
      limit: decision.limit,
      used: decision.used,
      reset_at_ms: decision.resetAtMs,
      entitlement_required: input.auth.tier === "free"
    });
  }
}

function startOfNextUtcMonth(): number {
  const now = new Date();
  return Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1);
}

function startOfCurrentUtcMonth(): number {
  const now = new Date();
  return Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1);
}

function monthlyLimit(tier: BrokerAuthContext["tier"], feature: UsageFeature): number {
  if (tier === "pro") {
    return feature === "photo_analysis" ? 500 : 10_000;
  }
  return feature === "photo_analysis" ? 10 : 500;
}

function integerFrom(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isSafeInteger(value)) return null;
  return value;
}
