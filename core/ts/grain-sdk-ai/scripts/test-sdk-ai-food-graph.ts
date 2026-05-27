import { readFileSync } from "node:fs";
import { join } from "node:path";

import {
  defaultMealMarkFoodGraphArtifactDir,
  loadLocalFoodGraphArtifact,
  LocalFoodGraphProvider
} from "../src/index.js";

const artifact = loadLocalFoodGraphArtifact();
const graph = new LocalFoodGraphProvider(artifact);

assert(artifact.manifest.runtime_policy.no_network_required === true, "artifact must be offline");
assert(artifact.manifest.runtime_policy.advisory_only === true, "artifact must be advisory-only");

assertResolved("Greek yogurt", "yogurt");
assertResolved("walnuts", "walnut");
assertResolved("arborio rice", "rice");
assert(graph.resolveIngredient("arborio rice").canonicalName !== "ice", "arborio rice must not resolve to ice");
assert(graph.resolveIngredient("stock").status === "ambiguous", "stock must stay ambiguous");
assert(graph.resolveIngredient("totally unknown ingredient").status === "unmapped", "unknown input must stay unmapped");

const ramenPairings = graph.suggestPairings(["ramen noodle", "pork", "egg", "scallion", "miso", "garlic"], {
  model: "core",
  limit: 8
});
assert(
  ramenPairings.some((item) => item.name === "sesame_oil" || item.name === "oyster_sauce"),
  "ramen basket should produce useful pairing suggestions"
);
assert(ramenPairings.every((item) => item.advisoryOnly === true), "pairings must be advisory-only");

const similar = graph.similarMeals(
  {
    mealId: "salmon-bowl",
    label: "Salmon bowl",
    ingredients: ["salmon", "rice", "avocado", "cucumber", "soy sauce", "sesame seed"]
  },
  [
    {
      mealId: "salmon-sushi",
      label: "Salmon sushi roll",
      ingredients: ["salmon", "rice", "nori", "avocado", "cucumber", "soy sauce"]
    },
    {
      mealId: "yogurt",
      label: "Greek yogurt, walnuts, honey",
      ingredients: ["greek yogurt", "walnut", "honey"]
    }
  ]
);
assert(similar[0]?.mealId === "salmon-sushi", "similar meals should rank shared ingredient structure first");
assert(similar[0]?.advisoryOnly === true, "similar meal result must be advisory-only");

const sourceRef = graph.sourceRefFor(graph.resolveIngredients(["Greek yogurt", "stock", "not-a-food"]));
const sourceRefJson = JSON.stringify(sourceRef);
for (const forbidden of [
  "\"mean\"",
  "\"var\"",
  "mean",
  "recordTrust",
  "nutritionConfidence",
  "verified",
  "COSE",
  "privateKey",
  "photo_bytes"
]) {
  assert(!sourceRefJson.includes(forbidden), `food graph source_ref must not contain ${forbidden}`);
}

const packageJson = JSON.parse(readFileSync(join(process.cwd(), "package.json"), "utf8")) as {
  dependencies?: Record<string, string>;
};
for (const dependency of Object.keys(packageJson.dependencies ?? {})) {
  assert(!dependency.toLowerCase().includes("huggingface"), "runtime package must not depend on Hugging Face");
  assert(!dependency.toLowerCase().includes("safetensors"), "runtime package must not depend on safetensors");
}

const artifactManifestJson = JSON.stringify(artifact.manifest);
assert(!artifactManifestJson.includes("hf.space"), "artifact must not point runtime at the HF Space");
assert(defaultMealMarkFoodGraphArtifactDir().includes("mealmark-food-graph-v0.1"), "default artifact path mismatch");

console.log("sdk ai food graph: PASS");

function assertResolved(input: string, expected: string): void {
  const actual = graph.resolveIngredient(input);
  assert(actual.status === "resolved", `${input} should resolve`);
  assert(actual.canonicalName === expected, `${input} resolved to ${actual.canonicalName}, expected ${expected}`);
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}
