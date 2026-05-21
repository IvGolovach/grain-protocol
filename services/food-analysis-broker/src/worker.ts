import { D1AccountStore } from "./accounts.js";
import { createBrokerDependencies } from "./dependencies.js";
import { D1EntitlementStore } from "./entitlements.js";
import { handleBrokerRequest } from "./handler.js";
import type { RuntimeEnv } from "./runtime.js";
import { D1SessionStore } from "./sessions.js";
import { D1StoreKitTransactionStore } from "./storekit.js";
import { D1UsageLimiter, type D1DatabaseBinding } from "./usage.js";

type CloudflareBrokerEnv = RuntimeEnv & {
  MEALMARK_DB?: D1DatabaseBinding;
};

export default {
  async fetch(request: Request, env: CloudflareBrokerEnv): Promise<Response> {
    return handleBrokerRequest(request, createBrokerDependencies(env, {
      ...(env.MEALMARK_DB ? {
        accountStore: new D1AccountStore(env.MEALMARK_DB),
        entitlementStore: new D1EntitlementStore(env.MEALMARK_DB),
        sessionStore: new D1SessionStore(env.MEALMARK_DB),
        storeKitTransactionStore: new D1StoreKitTransactionStore(env.MEALMARK_DB),
        usageLimiter: new D1UsageLimiter(env.MEALMARK_DB)
      } : {})
    }));
  }
};
