import { GrainSdk, InMemorySdkStore, SdkError } from "grain-sdk-ts";
import type { AppendEventInput } from "grain-sdk-ts";
import { describeError } from "grain-sdk-ts/errors";
import { createAcceptedTokenFromObjectCandidate } from "grain-sdk-ai-ts";

const sdk = new GrainSdk({ store: new InMemorySdkStore() });
const event: AppendEventInput = {
  t: "IntakeEvent",
  payload_cid: "fixture:npm-consumer:meal-001",
  body: {
    mean: { kcal: 1 },
    var: { kcal: 0 },
    source_class: "estimated"
  }
};

const token = createAcceptedTokenFromObjectCandidate({
  candidate_version: 1,
  kind: "object",
  target_schema_major: 1,
  target_type: "ServingOffer",
  payload_format: "structured_v1",
  payload: { demo: true }
});

void sdk;
void event;
void token;
void describeError(new SdkError("SDK_ERR_STRICT_REQUIRED"));
