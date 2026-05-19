export { AiBoundary, createGrainSdkAi } from "./ai/accept.js";
export { AcceptedToken } from "./ai/token_registry.js";
export { DeterministicFakeFoodProvider, estimateFoodPhotoDraft } from "./ai/food.js";
export { type ContractExportV1 } from "./ai/contract_export.js";

export type { AICandidateEnvelopeV1, IntelligenceAdapter, AIInput, AIExplainChunk } from "./ai/adapter.js";
export type { AcceptOptions, ApplyOptions, AcceptResult, ApplyResult, AiBoundaryOptions } from "./ai/accept.js";
export type {
  DeterministicFakeFoodProviderOptions,
  FoodAdviceContext,
  FoodInsightProvider,
  FoodInsightResult,
  FoodPhotoEstimateRequest,
  FoodPhotoEstimatorProvider
} from "./ai/food.js";
