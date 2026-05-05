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
await runDeviceLifecycleFixtures();
await runPairingFixtures();
await runSyncBundleFixtures();
await runStoreSnapshotFixtures();
console.log("WASM client workflow fixtures: PASS");

async function runScanPreviewFixtures() {
  for (const fixture of loadFixtures("scan-preview")) {
    requireFixture(fixture.workflow === "scan_preview", `${fixture.fixture_id} workflow mismatch`);
    requireFixture(fixture.strict === true, `${fixture.fixture_id} must be strict`);

    const client = await createNodeGrainClient({ wasmPath });
    try {
      const preview = client.scanPreview({
        qrString: fixtureQrString(fixture),
        trustPubB64: resolveTrustInput(fixture.input),
      });

      requireFixture(preview.status === fixture.expect.status, `${fixture.fixture_id} status mismatch`);
      requireDiagnostics(preview.diag, fixture.expect, fixture.fixture_id);
      requireCosePresence(preview.coseB64, requiredExpectation(fixture.expect.cose_b64, "cose_b64", fixture.fixture_id), fixture.fixture_id);
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

    const qrString = fixtureQrString(fixture);
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
      requireCosePresence(accepted.coseB64, requiredExpectation(fixture.expect.cose_b64, "cose_b64", fixture.fixture_id), fixture.fixture_id);

      const records = client.listAcceptedScans();
      const storeMutation = requiredExpectation(fixture.expect.store_mutation, "store_mutation", fixture.fixture_id);
      if (storeMutation === "accepted_scan_inserted") {
        requireFixture(records.length > 0, `${fixture.fixture_id} expected persisted record`);
      } else if (storeMutation === "none") {
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

async function runDeviceLifecycleFixtures() {
  for (const fixture of loadFixtures("device-lifecycle")) {
    requireFixture(fixture.workflow === "device_lifecycle", `${fixture.fixture_id} workflow mismatch`);
    requireFixture(fixture.strict === true, `${fixture.fixture_id} must be strict`);

    const client = await createNodeGrainClient({ wasmPath });
    try {
      const root = client.createRootIdentity({ label: fixture.input.root_label ?? "root" });
      requireFixture(root.status === "Created", `${fixture.fixture_id} root create mismatch`);
      const added = client.addDeviceKey({ label: fixture.input.device_label ?? "device" });
      requireFixture(added.status === "Added", `${fixture.fixture_id} device add mismatch`);
      requirePresence(added.deviceAk, "present", "device_ak", fixture.fixture_id);

      const active = client.setActiveDevice({ ak: added.deviceAk });
      requireFixture(active.status === "Active", `${fixture.fixture_id} active device mismatch`);
      const revoked = client.revokeDeviceKey({ ak: added.deviceAk });
      requireFixture(revoked.status === "Revoked", `${fixture.fixture_id} revoke mismatch`);

      const lifecycle = client.clientLifecycle();
      requireFixture(lifecycle.status === fixture.expect.status, `${fixture.fixture_id} lifecycle status mismatch`);
      requireDiagnostics(lifecycle.diag, fixture.expect, fixture.fixture_id);
      requirePresence(lifecycle.rootKid, fixture.expect.root_kid, "root_kid", fixture.fixture_id);
      requirePresence(lifecycle.activeAk, fixture.expect.active_ak, "active_ak", fixture.fixture_id);
      requirePresence(added.deviceAk, fixture.expect.device_ak, "device_ak", fixture.fixture_id);
      requireCount(lifecycle.deviceCount, fixture.expect.device_count, "device_count", fixture.fixture_id);
      requireCount(lifecycle.revokedCount, fixture.expect.revoked_count, "revoked_count", fixture.fixture_id);
      requireCount(
        lifecycle.acceptedRecordCount,
        fixture.expect.accepted_record_count,
        "accepted_record_count",
        fixture.fixture_id,
      );
      requireCount(
        lifecycle.lifecycleEventCount,
        fixture.expect.lifecycle_event_count,
        "lifecycle_event_count",
        fixture.fixture_id,
      );
    } finally {
      client.close();
    }
  }
}

async function runPairingFixtures() {
  for (const fixture of loadFixtures("pairing")) {
    requireFixture(fixture.workflow === "pairing", `${fixture.fixture_id} workflow mismatch`);
    requireFixture(fixture.strict === true, `${fixture.fixture_id} must be strict`);

    const source = await createNodeGrainClient({ wasmPath });
    const target = await createNodeGrainClient({ wasmPath });
    try {
      const root = source.createRootIdentity({ label: fixture.input.root_label ?? "root" });
      requireFixture(root.status === "Created", `${fixture.fixture_id} root create mismatch`);
      const added = source.addDeviceKey({ label: fixture.input.device_label ?? "device" });
      requireFixture(added.status === "Added", `${fixture.fixture_id} device add mismatch`);

      const envelope = source.createPairingEnvelope();
      requireFixture(envelope.status === "Created", `${fixture.fixture_id} envelope create mismatch`);
      requirePresence(envelope.envelopeB64, fixture.expect.envelope_b64, "envelope_b64", fixture.fixture_id);
      const preview = source.previewPairingEnvelope({ envelopeB64: envelope.envelopeB64 });
      requireFixture(preview.status === "Valid", `${fixture.fixture_id} pairing preview mismatch`);

      const attempts = fixture.input.accept_attempts ?? 1;
      requireFixture(
        Number.isInteger(attempts) && attempts > 0,
        `${fixture.fixture_id} accept_attempts must be positive`,
      );
      let paired = null;
      for (let i = 0; i < attempts; i += 1) {
        paired = target.acceptPairingEnvelope({ envelopeB64: envelope.envelopeB64 });
      }
      requireFixture(paired !== null, `${fixture.fixture_id} missing pairing result`);
      requireFixture(paired.status === fixture.expect.status, `${fixture.fixture_id} pairing status mismatch`);
      requireDiagnostics(paired.diag, fixture.expect, fixture.fixture_id);
      requirePresence(paired.rootKid, fixture.expect.root_kid, "root_kid", fixture.fixture_id);
      requirePresence(paired.pairingId, fixture.expect.pairing_id, "pairing_id", fixture.fixture_id);
      requireCount(paired.deviceCount, fixture.expect.device_count, "device_count", fixture.fixture_id);
    } finally {
      source.close();
      target.close();
    }
  }
}

async function runSyncBundleFixtures() {
  for (const fixture of loadFixtures("sync-bundle")) {
    requireFixture(fixture.workflow === "sync_bundle", `${fixture.fixture_id} workflow mismatch`);
    requireFixture(fixture.strict === true, `${fixture.fixture_id} must be strict`);

    const source = await createNodeGrainClient({ wasmPath });
    const target = await createNodeGrainClient({ wasmPath });
    try {
      const root = source.createRootIdentity({ label: fixture.input.root_label ?? "root" });
      requireFixture(root.status === "Created", `${fixture.fixture_id} root create mismatch`);
      const added = source.addDeviceKey({ label: fixture.input.device_label ?? "device" });
      requireFixture(added.status === "Added", `${fixture.fixture_id} device add mismatch`);

      const trustPubB64 = resolveTrustInput(fixture.input);
      requireFixture(typeof trustPubB64 === "string", `${fixture.fixture_id} missing trust material`);
      const accepted = source.scanAccept({ qrString: fixtureQrString(fixture), trustPubB64 });
      requireFixture(accepted.status === "Accepted", `${fixture.fixture_id} scan accept mismatch`);

      const exported = source.exportSyncBundle();
      requireFixture(exported.status === "Exported", `${fixture.fixture_id} sync export mismatch`);
      requirePresence(exported.bundleB64, fixture.expect.bundle_b64, "bundle_b64", fixture.fixture_id);

      const attempts = fixture.input.import_attempts ?? 1;
      requireFixture(
        Number.isInteger(attempts) && attempts > 0,
        `${fixture.fixture_id} import_attempts must be positive`,
      );
      let imported = null;
      for (let i = 0; i < attempts; i += 1) {
        imported = target.importSyncBundle({ bundleB64: exported.bundleB64 });
      }
      requireFixture(imported !== null, `${fixture.fixture_id} missing sync result`);
      requireFixture(imported.status === fixture.expect.status, `${fixture.fixture_id} sync status mismatch`);
      requireDiagnostics(imported.diag, fixture.expect, fixture.fixture_id);
      requireCount(
        imported.acceptedRecordCount,
        fixture.expect.accepted_record_count,
        "accepted_record_count",
        fixture.fixture_id,
      );
      requireCount(imported.deviceCount, fixture.expect.device_count, "device_count", fixture.fixture_id);
      requireCount(
        imported.lifecycleEventCount,
        fixture.expect.lifecycle_event_count,
        "lifecycle_event_count",
        fixture.fixture_id,
      );
    } finally {
      source.close();
      target.close();
    }
  }
}

async function runStoreSnapshotFixtures() {
  const empty = await createNodeGrainClient({ wasmPath });
  try {
    const snapshot = empty.exportStoreSnapshot();
    requireFixture(snapshot.status === "Empty", "store snapshot empty status mismatch");
    requireFixture(snapshot.snapshotB64 === null, "empty store snapshot must not produce payload");
  } finally {
    empty.close();
  }

  for (const fixture of loadFixtures("store-snapshot")) {
    requireFixture(fixture.workflow === "store_snapshot", `${fixture.fixture_id} workflow mismatch`);
    requireFixture(fixture.strict === true, `${fixture.fixture_id} must be strict`);

    const source = await createNodeGrainClient({ wasmPath });
    const target = await createNodeGrainClient({ wasmPath });
    try {
      requireFixture(
        source.createRootIdentity({ label: fixture.input.root_label ?? "root" }).status === "Created",
        `${fixture.fixture_id} root create mismatch`,
      );
      requireFixture(
        source.addDeviceKey({ label: fixture.input.device_label ?? "device" }).status === "Added",
        `${fixture.fixture_id} device add mismatch`,
      );
      const trustPubB64 = resolveTrustInput(fixture.input);
      requireFixture(typeof trustPubB64 === "string", `${fixture.fixture_id} missing trust material`);
      const accepted = source.scanAccept({ qrString: fixtureQrString(fixture), trustPubB64 });
      requireFixture(accepted.status === "Accepted", `${fixture.fixture_id} scan accept mismatch`);

      const exported = source.exportStoreSnapshot();
      requireFixture(exported.status === "Exported", `${fixture.fixture_id} snapshot export mismatch`);
      requirePresence(exported.snapshotB64, fixture.expect.snapshot_b64, "snapshot_b64", fixture.fixture_id);

      const restored = target.restoreStoreSnapshot({ snapshotB64: exported.snapshotB64 });
      requireFixture(restored.status === fixture.expect.status, `${fixture.fixture_id} snapshot restore mismatch`);
      requireDiagnostics(restored.diag, fixture.expect, fixture.fixture_id);
      requireCount(
        restored.acceptedRecordCount,
        fixture.expect.accepted_record_count,
        "accepted_record_count",
        fixture.fixture_id,
      );
      requireCount(restored.deviceCount, fixture.expect.device_count, "device_count", fixture.fixture_id);
      requireCount(
        restored.lifecycleEventCount,
        fixture.expect.lifecycle_event_count,
        "lifecycle_event_count",
        fixture.fixture_id,
      );

      const lifecycle = target.clientLifecycle();
      requireFixture(lifecycle.status === "Ready", `${fixture.fixture_id} lifecycle status mismatch`);
      requireCount(
        lifecycle.acceptedRecordCount,
        fixture.expect.accepted_record_count,
        "accepted_record_count",
        fixture.fixture_id,
      );
      requireCount(lifecycle.deviceCount, fixture.expect.device_count, "device_count", fixture.fixture_id);
      requireCount(
        lifecycle.lifecycleEventCount,
        fixture.expect.lifecycle_event_count,
        "lifecycle_event_count",
        fixture.fixture_id,
      );
    } finally {
      source.close();
      target.close();
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

function fixtureQrString(fixture) {
  if (typeof fixture.input.qr_string_ref !== "string") {
    throw new Error(`${fixture.fixture_id} missing qr_string_ref`);
  }
  return resolveStringRef(fixture.input.qr_string_ref);
}

function requiredExpectation(value, fieldName, fixtureId) {
  if (value === undefined || value === null) {
    throw new Error(`${fixtureId} missing ${fieldName} expectation`);
  }
  return value;
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

function requirePresence(value, expectation, fieldName, fixtureId) {
  if (expectation === undefined || expectation === null) {
    return;
  }
  if (expectation === "present") {
    requireFixture(typeof value === "string" && value.length > 0, `${fixtureId} expected ${fieldName}`);
  } else if (expectation === "absent") {
    requireFixture(value === null, `${fixtureId} expected no ${fieldName}`);
  } else {
    throw new Error(`${fixtureId} unsupported ${fieldName} expectation`);
  }
}

function requireCount(actual, expectation, fieldName, fixtureId) {
  if (expectation === undefined || expectation === null) {
    return;
  }
  requireFixture(actual === expectation, `${fixtureId} ${fieldName} mismatch`);
}

function requireFixture(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}
