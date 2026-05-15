import { GrainSdk, InMemorySdkStore, SdkError } from "grain-sdk-ts";
import type { AppendEventInput } from "grain-sdk-ts";
import { describeError } from "grain-sdk-ts/errors";
import { createGrainSdkAi } from "grain-sdk-ai-ts";
import type { AICandidateEnvelopeV1 } from "grain-sdk-ai-ts";

const sdk = new GrainSdk(new InMemorySdkStore());
const event: AppendEventInput = {
  t: "IntakeEvent",
  payload_cid: "fixture:npm-consumer:meal-001",
  body: {
    mean: { kcal: 1 },
    var: { kcal: 0 },
    source_class: "estimated"
  }
};

const ai = createGrainSdkAi(sdk);
const candidate: AICandidateEnvelopeV1 = {
  candidate_version: 1,
  kind: "object",
  target_schema_major: 1,
  target_type: "IntakeEvent",
  payload_format: "structured_v1",
  payload: {
    data: {
      mean: { kcal: "1" },
      var: { kcal: "0" },
      source_class: "estimated",
      tags: ["fixture"]
    },
    profile_id: "intake_event_v1"
  }
};

void sdk;
void event;
void ai;
void candidate;
void describeError(new SdkError("SDK_ERR_STRICT_REQUIRED").code);
