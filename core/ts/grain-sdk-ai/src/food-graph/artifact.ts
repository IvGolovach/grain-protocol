import { createHash } from "node:crypto";
import { readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

import type {
  FoodGraphArtifact,
  FoodGraphArtifactManifest,
  FoodGraphModelKey,
  FoodGraphNeighbor
} from "./types.js";

type AliasFile = {
  aliases: Record<string, string>;
  ambiguous_aliases: Record<string, string[]>;
};

const MODEL_KEYS: readonly FoodGraphModelKey[] = ["cooc", "core", "chem"];

export function defaultMealMarkFoodGraphArtifactDir(): string {
  return fileURLToPath(new URL("../../../food-graph-artifacts/mealmark-food-graph-v0.1", import.meta.url));
}

export function loadLocalFoodGraphArtifact(
  artifactDir = defaultMealMarkFoodGraphArtifactDir()
): FoodGraphArtifact {
  const manifest = readJson<FoodGraphArtifactManifest>(join(artifactDir, "manifest.json"));
  assertManifestPolicy(manifest);
  verifyChecksums(artifactDir, manifest);

  const vocabulary = readJson<string[]>(join(artifactDir, "vocabulary.json"));
  if (vocabulary.length !== manifest.vocabulary_count) {
    throw new Error(`Food graph vocabulary count mismatch: manifest=${manifest.vocabulary_count} actual=${vocabulary.length}`);
  }

  const aliasFile = readJson<AliasFile>(join(artifactDir, "aliases.json"));
  const neighbors = new Map<FoodGraphModelKey, ReadonlyMap<string, readonly FoodGraphNeighbor[]>>();
  for (const modelKey of MODEL_KEYS) {
    const modelNeighbors = readJson<Record<string, FoodGraphNeighbor[]>>(join(artifactDir, `neighbors-${modelKey}.json`));
    neighbors.set(modelKey, new Map(Object.entries(modelNeighbors)));
  }

  return {
    manifest,
    vocabulary,
    aliases: new Map(Object.entries(aliasFile.aliases)),
    ambiguousAliases: new Map(Object.entries(aliasFile.ambiguous_aliases)),
    neighbors
  };
}

function readJson<T>(path: string): T {
  return JSON.parse(readFileSync(path, "utf8")) as T;
}

function verifyChecksums(artifactDir: string, manifest: FoodGraphArtifactManifest): void {
  for (const [fileName, expected] of Object.entries(manifest.files)) {
    const path = join(artifactDir, fileName);
    const stat = statSync(path);
    if (stat.size !== expected.bytes) {
      throw new Error(`Food graph artifact byte-size mismatch for ${fileName}`);
    }
    const actual = createHash("sha256").update(readFileSync(path)).digest("hex");
    if (actual !== expected.sha256) {
      throw new Error(`Food graph artifact checksum mismatch for ${fileName}`);
    }
  }
}

function assertManifestPolicy(manifest: FoodGraphArtifactManifest): void {
  if (manifest.schema !== "mealmark.food_graph.artifact.v1") {
    throw new Error(`Unsupported food graph artifact schema: ${manifest.schema}`);
  }
  const policy = manifest.runtime_policy;
  if (
    policy.no_network_required !== true ||
    policy.advisory_only !== true ||
    policy.may_change_kcal !== false ||
    policy.may_change_record_trust !== false ||
    policy.may_change_nutrition_confidence !== false ||
    policy.raw_photo_persistence !== "forbidden" ||
    policy.raw_vector_persistence !== "forbidden"
  ) {
    throw new Error("Food graph artifact violates advisory-only runtime policy");
  }
}
