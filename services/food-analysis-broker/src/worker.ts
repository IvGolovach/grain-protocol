import { createBrokerDependencies } from "./dependencies.js";
import { handleBrokerRequest } from "./handler.js";
import type { RuntimeEnv } from "./runtime.js";
import { D1UsageLimiter, type D1DatabaseBinding } from "./usage.js";

type CloudflareBrokerEnv = RuntimeEnv & {
  MEALMARK_DB?: D1DatabaseBinding;
};

export default {
  async fetch(request: Request, env: CloudflareBrokerEnv): Promise<Response> {
    return handleBrokerRequest(request, createBrokerDependencies(env, {
      ...(env.MEALMARK_DB ? { usageLimiter: new D1UsageLimiter(env.MEALMARK_DB) } : {})
    }));
  }
};
