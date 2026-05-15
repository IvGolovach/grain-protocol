const sdk = await import("grain-sdk-ts");
const errors = await import("grain-sdk-ts/errors");
const ai = await import("grain-sdk-ai-ts");

if (typeof sdk.GrainSdk !== "function") {
  throw new Error("missing GrainSdk public export");
}
if (typeof sdk.InMemorySdkStore !== "function") {
  throw new Error("missing InMemorySdkStore public export");
}
if (typeof errors.describeError !== "function") {
  throw new Error("missing describeError public export");
}
if (typeof ai.createAcceptedTokenFromObjectCandidate !== "function") {
  throw new Error("missing AI sidecar public export");
}

console.log(JSON.stringify({ pass: true, fixture: "external-npm-consumer" }));
