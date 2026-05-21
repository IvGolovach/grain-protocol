import { DisabledAccountStore, type AccountStore } from "./accounts.js";
import { analyzerFromEnv } from "./analyzers.js";
import type { BrokerAuthConfig } from "./auth.js";
import { DisabledEntitlementStore, type EntitlementStore } from "./entitlements.js";
import { FoodAnalysisCandidateResolver, GrainDraftResolver } from "./resolver.js";
import type { RuntimeEnv } from "./runtime.js";
import { MAX_JSON_BODY_BYTES } from "./schema.js";
import { foodSearchProviderFromEnv } from "./search.js";
import { DisabledSessionStore, type SessionStore } from "./sessions.js";
import { DisabledStoreKitTransactionStore, type StoreKitTransactionStore, type StoreKitTransactionVerifier } from "./storekit.js";
import { appStoreServerApiVerifierFromEnv } from "./storekit_appstore.js";
import type { CandidateResolver, FoodAnalyzer, FoodSearchProvider, ObservationResolver } from "./types.js";
import { nutritionProviderFromEnv } from "./usda.js";
import { NoopUsageLimiter, type UsageLimiter } from "./usage.js";

export type BrokerDependencies = {
  accountStore: AccountStore;
  analyzer: FoodAnalyzer;
  auth: BrokerAuthConfig;
  candidateResolver: CandidateResolver;
  entitlementStore: EntitlementStore;
  maxBodyBytes: number;
  resolver: ObservationResolver;
  searchProvider: FoodSearchProvider;
  sessionStore: SessionStore;
  storeKitTransactionStore: StoreKitTransactionStore;
  storeKitVerifier?: StoreKitTransactionVerifier;
  usageLimiter: UsageLimiter;
};

export type BrokerDependencyOptions = Partial<Omit<BrokerDependencies, "auth">> & {
  auth?: Partial<BrokerAuthConfig>;
};

export function createBrokerDependencies(env: RuntimeEnv = {}, options: BrokerDependencyOptions = {}): BrokerDependencies {
  const auth = authConfigFromEnv(env, options.auth);
  const storeKitVerifier = options.storeKitVerifier ?? appStoreServerApiVerifierFromEnv(env);
  return {
    accountStore: options.accountStore ?? new DisabledAccountStore(),
    analyzer: options.analyzer ?? analyzerFromEnv(env),
    auth,
    candidateResolver: options.candidateResolver ?? new FoodAnalysisCandidateResolver({
      nutritionProvider: nutritionProviderFromEnv(env)
    }),
    entitlementStore: options.entitlementStore ?? new DisabledEntitlementStore(),
    maxBodyBytes: options.maxBodyBytes ?? MAX_JSON_BODY_BYTES,
    resolver: options.resolver ?? new GrainDraftResolver(),
    searchProvider: options.searchProvider ?? foodSearchProviderFromEnv(env),
    sessionStore: options.sessionStore ?? new DisabledSessionStore(),
    storeKitTransactionStore: options.storeKitTransactionStore ?? new DisabledStoreKitTransactionStore(),
    ...(storeKitVerifier ? { storeKitVerifier } : {}),
    usageLimiter: options.usageLimiter ?? new NoopUsageLimiter()
  };
}

export function authConfigFromEnv(env: RuntimeEnv, overrides: Partial<BrokerAuthConfig> = {}): BrokerAuthConfig {
  const devBearerToken = normalized(env.FOOD_BROKER_DEV_TOKEN);
  const mode = overrides.mode ?? authModeFromEnv(env, devBearerToken);
  return {
    mode,
    ...(env.MEALMARK_ALLOW_ANONYMOUS_FOOD_SEARCH === "1" ? { allowAnonymousFoodSearch: true } : {}),
    ...(devBearerToken ? { devBearerToken } : {}),
    ...(normalized(env.MEALMARK_SESSION_HMAC_SECRET) ? { sessionHmacSecret: normalized(env.MEALMARK_SESSION_HMAC_SECRET)! } : {}),
    ...overrides
  };
}

function authModeFromEnv(env: RuntimeEnv, devBearerToken: string | undefined): BrokerAuthConfig["mode"] {
  if (env.MEALMARK_AUTH_MODE === "session") return "session";
  if (env.MEALMARK_AUTH_MODE === "anonymous") return "anonymous";
  if (devBearerToken) return "dev_bearer";
  return "anonymous";
}

function normalized(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed : undefined;
}
