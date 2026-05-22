export type SupportedImageMediaType = "image/jpeg" | "image/png" | "image/webp";

export type FoodAnalyzePhotoRequest = {
  request_id?: string;
  capture_id?: string;
  client?: {
    platform?: "ios";
    app_version?: string;
    device_id_hash?: string;
  };
  hints?: {
    locale?: string;
    meal_context?: string;
    timezone?: string;
  };
  photo: {
    media_type: SupportedImageMediaType;
    bytes_b64: string;
  };
  draft?: {
    draft_id?: string;
    payload_cid?: string;
    ts_ms?: number;
  };
};

export type FoodObservation = {
  recognition_status: "food_detected" | "no_food" | "uncertain";
  non_food_reason: string | null;
  items: Array<{
    label: string;
    confidence: number;
  }>;
  total_kcal: number;
  kcal_variance: number;
  nutrition_label: {
    is_visible: boolean;
    calories_per_container: number | null;
    calories_per_serving: number | null;
    servings_per_container: number | null;
    serving_size_text: string | null;
    container_size_text: string | null;
    source_text: string | null;
  } | null;
  serving_g: number | null;
  amount_g: number | null;
  servings: number | null;
  portion_basis: PortionBasis;
  portion_confidence: number;
  portion_rationale: string;
  confidence: number;
  rationale: string;
};

export type PortionBasis = "visible_label" | "package_serving" | "visual_estimate" | "unknown";
export type DishType = "single" | "mixed" | "packaged" | "unknown";
export type EstimateConfidence = "high" | "medium" | "low";

export type PortionEstimate = {
  gramsMin: number;
  gramsMode: number;
  gramsMax: number;
};

export type NutritionRange = {
  minKcal: number;
  modeKcal: number;
  maxKcal: number;
};

export type MealMacronutrients = {
  proteinGrams: number;
  carbohydrateGrams: number;
  fatGrams: number;
  fiberGrams?: number;
};

export type FoodAnalysisCandidate = {
  id: string;
  primaryLabel: string;
  genericLabel: string;
  dishType: DishType;
  portion: PortionEstimate;
  nutrition: NutritionRange;
  macronutrients: MealMacronutrients;
  confidence: EstimateConfidence;
  assumptions: Array<{
    id: string;
    label: string;
    isEnabled: boolean;
  }>;
  evidence: Array<{
    provider: string;
    providerID: string;
    matchedName: string;
    servingBasis: string;
  }>;
  userConfirmationRequired: true;
};

export type FoodNutrientKcal = {
  kcal: number;
};

export type FoodIntakeDraft = {
  draft_v: 1;
  draft_id: string;
  payload_cid: string;
  source: "photo_estimate";
  source_class: "estimated";
  mean: FoodNutrientKcal;
  var: FoodNutrientKcal;
  amount_g?: number;
  serving_g?: number;
  servings?: number;
  ts_ms?: number;
  source_ref: {
    estimate_id: string;
    capture_id?: string;
    confidence: number;
      evidence: {
        photo_sha256_16: string;
        model_id: string;
        observation_schema: "grain_food_photo_observation_v2";
      };
      food_items: Array<{
      label: string;
      confidence: number;
    }>;
  };
  privacy: {
    raw_photo_persistence: "forbidden";
    allowed_persistent_photo_fields: readonly ["photo_sha256_16"];
  };
};

export type FoodAnalyzePhotoSuccess = {
  ok: true;
  request_id: string;
  mode: "mock" | "openai";
  analysis_id: string;
  observation: FoodObservation;
  candidate: FoodAnalysisCandidate;
  draft: FoodIntakeDraft;
  privacy: {
    store: false;
    raw_image_logged: false;
    raw_image_persisted: false;
  };
};

export type FoodSearchRequest = {
  request_id?: string;
  query?: string;
  barcode?: string;
  limit?: number;
  locale?: string;
};

export type FoodSearchMatchType = "name" | "barcode";
export type FoodSearchSourceLabel = "deterministic_fixture" | "open_food_facts" | "usda_fdc";
export type FoodSearchEvidenceSourceLabel = "curated_fixture" | "open_food_facts_product" | "usda_branded_food" | "usda_generic_food";
export type FoodSearchTrustLabel = "fixture_verified" | "barcode_fixture" | "barcode_provider" | "provider_estimate";

export type FoodSearchPer100gNutrition = {
  kcal: number;
  protein_g: number;
  carbohydrate_g: number;
  fat_g: number;
  fiber_g?: number;
};

export type FoodSearchResult = {
  result_id: string;
  primary_label: string;
  generic_label: string;
  brand_label: string | null;
  category: string;
  source_label: FoodSearchSourceLabel;
  trust_label: FoodSearchTrustLabel;
  match: {
    type: FoodSearchMatchType;
    score: number;
  };
  serving: {
    basis: "per_100g";
    serving_size_g: number | null;
    serving_label: string | null;
  };
  nutrition: {
    per_100g: FoodSearchPer100gNutrition;
  };
  provider_evidence: Array<{
    provider: FoodSearchSourceLabel;
    provider_id: string;
    matched_name: string;
    match_type: FoodSearchMatchType;
    source_label: FoodSearchEvidenceSourceLabel;
    trust_label: FoodSearchTrustLabel;
  }>;
  user_confirmation_required: true;
};

export type FoodSearchSuccess = {
  ok: true;
  request_id: string;
  query?: string;
  barcode?: string;
  results: FoodSearchResult[];
};

export type ErrorCode =
  | "ACCOUNT_REQUIRED"
  | "BAD_JSON"
  | "BAD_REQUEST"
  | "FORBIDDEN"
  | "METHOD_NOT_ALLOWED"
  | "NO_FOOD_DETECTED"
  | "NOT_FOUND"
  | "PAYLOAD_TOO_LARGE"
  | "PROVIDER_NOT_CONFIGURED"
  | "RATE_LIMITED"
  | "UNAUTHORIZED"
  | "UPSTREAM_ERROR"
  | "UPSTREAM_TIMEOUT"
  | "INTERNAL_ERROR";

export type ErrorShape = {
  ok: false;
  error: {
    code: ErrorCode;
    message: string;
    request_id: string;
    details?: Record<string, string | number | boolean>;
  };
};

export type FoodAnalyzer = {
  analyze(input: {
    request: FoodAnalyzePhotoRequest;
    imageBytes: Uint8Array;
    photoSha25616: string;
  }): Promise<{
    mode: "mock" | "openai";
    modelId: string;
    observation: FoodObservation;
  }>;
};

export type ObservationResolver = {
  resolve(input: {
    request: FoodAnalyzePhotoRequest;
    observation: FoodObservation;
    photoSha25616: string;
    modelId: string;
  }): Promise<FoodIntakeDraft>;
};

export type CandidateResolver = {
  resolveCandidate(input: {
    request: FoodAnalyzePhotoRequest;
    observation: FoodObservation;
    photoSha25616: string;
    modelId: string;
  }): Promise<FoodAnalysisCandidate>;
};

export type FoodSearchProvider = {
  search(request: FoodSearchRequest): Promise<FoodSearchResult[]>;
};
