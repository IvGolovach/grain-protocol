#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, realpathSync } from "node:fs";
import { dirname, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { createNodeGrainClient } from "../src/node.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const vectorsRoot = realpathSync(resolve(repoRoot, "conformance/vectors"));
const wasmPath = process.env.GRAIN_CLIENT_WASM_PATH ??
  resolve(repoRoot, "core/rust/target/wasm32-wasip1/release/grain_client_wasm.wasm");

if (!existsSync(wasmPath)) {
  throw new Error(`SDK_WASM_ERR_ARTIFACT_MISSING:${wasmPath}`);
}

await runScanPreviewFixtures();
await runScanAcceptFixtures();
console.log("WASM client workflow fixtures: PASS");

async function runScanPreviewFixtures() {
  for (const fixture of loadFixtures("scan-preview")) {
    requireFixture(fixture.workflow === "scan_preview", `${fixture.fixture_id} workflow mismatch`);
    requireFixture(fixture.strict === true, `${fixture.fixture_id} must be strict`);

    const client = await createNodeGrainClient({ wasmPath });
    try {
      const preview = client.scanPreview({
        qrString: resolveStringRef(fixture.input.qr_string_ref),
        trustPubB64: resolveTrustInput(fixture.input),
      });

      requireFixture(preview.status === fixture.expect.status, `${fixture.fixture_id} status mismatch`);
      requireDiagnostics(preview.diag, fixture.expect, fixture.fixture_id);
      requireCosePresence(preview.coseB64, fixture.expect.cose_b64, fixture.fixture_id);
      requireFixture(client.listAcceptedScans().length === 0, `${fixture.fixture_id} preview mutated storage`);
    } finally {
      client.close();
    }
  }
}

async function runScanAcceptFixtures() {
  for (const fixture of loadFixtures("scan-accept")) {
    requireFixture(fixture.workflow === "scan_accept", `${fixture.fixture_id} workflow mismatch`);
    requireFixture(fixture.strict === true, `${fixture.fixture_id} must be strict`);

    const qrString = resolveStringRef(fixture.input.qr_string_ref);
    const trustPubB64 = resolveTrustInput(fixture.input);
    requireFixture(typeof trustPubB64 === "string", `${fixture.fixture_id} missing trust material`);

    const attempts = fixture.input.accept_attempts ?? 1;
    requireFixture(Number.isInteger(attempts) && attempts > 0, `${fixture.fixture_id} accept_attempts must be positive`);

    const client = await createNodeGrainClient({ wasmPath });
    try {
      let accepted = null;
      for (let i = 0; i < attempts; i += 1) {
        accepted = client.scanAccept({ qrString, trustPubB64 });
      }

      requireFixture(accepted !== null, `${fixture.fixture_id} missing accept result`);
      requireFixture(accepted.status === fixture.expect.status, `${fixture.fixture_id} status mismatch`);
      requireDiagnostics(accepted.diag, fixture.expect, fixture.fixture_id);
      requireCosePresence(accepted.coseB64, fixture.expect.cose_b64, fixture.fixture_id);

      const records = client.listAcceptedScans();
      if (fixture.expect.store_mutation === "accepted_scan_inserted") {
        requireFixture(records.length > 0, `${fixture.fixture_id} expected persisted record`);
      } else if (fixture.expect.store_mutation === "none") {
        requireFixture(records.length === 0, `${fixture.fixture_id} expected no persisted records`);
      } else {
        throw new Error(`${fixture.fixture_id} unsupported store mutation`);
      }

      if (fixture.expect.accepted_record_count !== undefined) {
        requireFixture(
          records.length === fixture.expect.accepted_record_count,
          `${fixture.fixture_id} accepted record count mismatch`,
        );
      }
    } finally {
      client.close();
    }
  }
}

function loadFixtures(kind) {
  const directory = resolve(repoRoot, `sdk/workflows/fixtures/${kind}`);
  const fixtures = readdirSync(directory)
    .filter((name) => name.endsWith(".json"))
    .sort()
    .map((name) => JSON.parse(readFileSync(resolve(directory, name), "utf8")));
  requireFixture(fixtures.length > 0, `${kind} fixture set is empty`);
  return fixtures;
}

function resolveTrustInput(input) {
  if (input.trust_pub_b64_ref !== undefined && input.trust_pub_b64 !== undefined) {
    throw new Error("trust_pub_b64_ref and trust_pub_b64 are mutually exclusive");
  }
  if (input.trust_pub_b64_ref !== undefined) {
    return resolveStringRef(input.trust_pub_b64_ref);
  }
  return input.trust_pub_b64 ?? null;
}

function resolveStringRef(ref) {
  const separator = ref.indexOf("#");
  if (separator <= 0 || !ref.slice(separator + 1).startsWith("/")) {
    throw new Error(`invalid ref: ${ref}`);
  }

  const relativePath = ref.slice(0, separator);
  const components = relativePath.split("/");
  if (
    relativePath.startsWith("/") ||
    !relativePath.startsWith("conformance/vectors/") ||
    components.some((part) => part.length === 0 || part === "." || part === "..")
  ) {
    throw new Error(`invalid ref: ${ref}`);
  }

  const filePath = realpathSync(resolve(repoRoot, relativePath));
  if (filePath !== vectorsRoot && !filePath.startsWith(`${vectorsRoot}${sep}`)) {
    throw new Error(`invalid ref: ${ref}`);
  }

  let node = JSON.parse(readFileSync(filePath, "utf8"));
  for (const rawToken of ref.slice(separator + 2).split("/")) {
    const token = decodePointerToken(rawToken);
    if (Array.isArray(node)) {
      const validArrayIndex = /^(0|[1-9]\d*)$/.test(token);
      const index = validArrayIndex ? Number(token) : -1;
      node = validArrayIndex && Number.isInteger(index) ? node[index] : undefined;
    } else if (node && typeof node === "object") {
      node = node[token];
    } else {
      node = undefined;
    }
    if (node === undefined) {
      throw new Error(`invalid ref: ${ref}`);
    }
  }

  if (typeof node !== "string") {
    throw new Error(`invalid ref: ${ref}`);
  }
  return node;
}

function decodePointerToken(token) {
  return token.replace(/~1/g, "/").replace(/~0/g, "~");
}

function requireDiagnostics(actual, expectation, fixtureId) {
  if (expectation.diag !== undefined) {
    requireFixture(JSON.stringify(actual) === JSON.stringify(expectation.diag), `${fixtureId} exact diagnostics mismatch`);
  }

  if (expectation.diag_contains !== undefined) {
    requireFixture(expectation.diag_contains.length > 0, `${fixtureId} diag_contains must not be empty`);
    for (const code of expectation.diag_contains) {
      requireFixture(actual.includes(code), `${fixtureId} expected diagnostic ${code}, actual ${actual.join(",")}`);
    }
  }
}

function requireCosePresence(coseB64, expectation, fixtureId) {
  if (expectation === "present") {
    requireFixture(coseB64 !== null, `${fixtureId} expected COSE`);
  } else if (expectation === "absent") {
    requireFixture(coseB64 === null, `${fixtureId} expected no COSE`);
  } else {
    throw new Error(`${fixtureId} unsupported cose_b64 expectation`);
  }
}

function requireFixture(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
