export type StructuredFieldProfile = {
  profile_id: string;
  numeric_fields: string[];
  bytes_fields: string[];
  set_array_fields: string[];
};

const PROFILES: Record<string, StructuredFieldProfile> = {
  claim_v1: {
    profile_id: "claim_v1",
    numeric_fields: ["/amount"],
    bytes_fields: [],
    set_array_fields: ["/tags"]
  },
  intake_event_v1: {
    profile_id: "intake_event_v1",
    numeric_fields: ["/mean/kcal", "/var/kcal"],
    bytes_fields: [],
    set_array_fields: ["/tags"]
  },
  cook_run_v1: {
    profile_id: "cook_run_v1",
    numeric_fields: ["/servings"],
    bytes_fields: [],
    set_array_fields: ["/tags"]
  }
};

const TARGET_TYPE_DEFAULT_PROFILE: Record<string, string> = {
  Claim: "claim_v1",
  IntakeEvent: "intake_event_v1",
  CookRun: "cook_run_v1"
};

export function listProfiles(): StructuredFieldProfile[] {
  return Object.values(PROFILES).map((p) => ({
    profile_id: p.profile_id,
    numeric_fields: [...p.numeric_fields],
    bytes_fields: [...p.bytes_fields],
    set_array_fields: [...p.set_array_fields]
  }));
}

export function resolveProfileById(profileId: string): StructuredFieldProfile | null {
  const profile = PROFILES[profileId];
  if (!profile) return null;
  return {
    profile_id: profile.profile_id,
    numeric_fields: [...profile.numeric_fields],
    bytes_fields: [...profile.bytes_fields],
    set_array_fields: [...profile.set_array_fields]
  };
}

export function resolveDefaultProfileForTarget(targetType: string): StructuredFieldProfile | null {
  const profileId = TARGET_TYPE_DEFAULT_PROFILE[targetType];
  if (!profileId) return null;
  return resolveProfileById(profileId);
}
