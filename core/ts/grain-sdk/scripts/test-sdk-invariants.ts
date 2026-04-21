#!/usr/bin/env node

import { readFileSync } from "node:fs";

import { GrainSdk, InMemorySdkStore } from "../src/index.js";
import { SdkError } from "../src/errors.js";
import { buildSetArray } from "../src/primitives.js";
import type { GrainSdkStore, IdentityBundleV1, LedgerEvent } from "../src/index.js";

const checks: Array<{ name: string; pass: boolean; detail?: string }> = [];

function ok(name: string): void {
  checks.push({ name, pass: true });
}

function fail(name: string, detail: string): void {
  checks.push({ name, pass: false, detail });
}

async function run(): Promise<number> {
  const sdk = new GrainSdk();
  await sdk.identity.createRoot();

  try {
    const cidLink = new Uint8Array([0x00, 0x01, 0x02]);
    const pt = new TextEncoder().encode("hello-world");

    const e1 = await sdk.e2e.encrypt(pt, { cid_link_bstr: cidLink });
    const e2 = await sdk.e2e.encrypt(pt, { cid_link_bstr: cidLink });

    if (Buffer.from(e1.cap_id).equals(Buffer.from(e2.cap_id))) {
      fail("SDK-INV-0003 cap_id randomness", "Two independent encryptions produced equal cap_id");
    } else {
      ok("SDK-INV-0003 cap_id randomness");
    }

    await sdk.e2e.putManifest("cid:pt:1", e1.cap_id, e1.chash);
    const resolved = await sdk.e2e.resolveManifest("cid:pt:1");
    if (resolved.status !== "found") {
      fail("SDK-INV-0005 manifest deterministic resolution", `unexpected status: ${resolved.status}`);
    } else {
      ok("SDK-INV-0005 manifest deterministic resolution");
    }

    const ptBack = await sdk.e2e.decrypt(e1.cap_id, e1.envelope_bytes, { cid_link_bstr: cidLink, expected_chash: e1.chash });
    if (!Buffer.from(ptBack).equals(Buffer.from(pt))) {
      fail("SDK-INV-0004 deterministic nonce lifecycle", "decrypt output mismatch");
    } else {
      ok("SDK-INV-0004 deterministic nonce lifecycle");
    }

    // cap single-assignment corruption guard through public API (no direct store bypass)
    try {
      const randomCap = e1.cap_id;
      const differentPt = new TextEncoder().encode("hello-world-mutated");
      await sdk.e2e.encrypt(differentPt, { cid_link_bstr: cidLink, cap_id: randomCap });
      fail("SDK-INV-0006 cap_id single-assignment", "overwrite did not fail");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "SDK_ERR_CAP_OVERWRITE_OR_CORRUPTION") {
        ok("SDK-INV-0006 cap_id single-assignment");
      } else {
        fail("SDK-INV-0006 cap_id single-assignment", `unexpected code: ${code}`);
      }
    }

    const d = await sdk.identity.addDeviceKey("device-a");
    await sdk.identity.revokeDeviceKey(d.device.ak);
    try {
      await sdk.events.append({
        ak: d.device.ak,
        t: "IntakeEvent",
        payload_cid: "cid:intake:revoked",
        body: { mean: { kcal: 1 }, var: { kcal: 0 } }
      });
      fail("SDK-INV-0002 unauthorized append guard", "revoked device append was accepted");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "SDK_ERR_UNAUTHORIZED_AK") {
        ok("SDK-INV-0002 unauthorized append guard");
      } else {
        fail("SDK-INV-0002 unauthorized append guard", `unexpected code: ${code}`);
      }
    }

    await sdk.events.append({
      t: "IntakeEvent",
      payload_cid: "cid:intake:1",
      body: { mean: { kcal: 100 }, var: { kcal: 4 } }
    });
    await sdk.events.append({
      t: "IntakeEvent",
      payload_cid: "cid:intake:2",
      body: { mean: { kcal: 50 }, var: { kcal: 1 } }
    });

    const reduced = await sdk.events.reduce();
    if (!reduced.pass) {
      fail("SDK-INV-0001 strict-by-default reducer", `diag=${JSON.stringify(reduced.diag)}`);
    } else {
      ok("SDK-INV-0001 strict-by-default reducer");
    }

    const badCbor = new Uint8Array([0xbf, 0x61, 0x61, 0x01, 0xff]);
    try {
      sdk.codec.strictValidate(badCbor);
      fail("SDK-INV-0007 canonicalization guard", "invalid CBOR accepted");
    } catch {
      ok("SDK-INV-0007 canonicalization guard");
    }

    try {
      buildSetArray(["b", "a", "a"], (x) => new TextEncoder().encode(x));
      fail("SDK-INV-0008 set-array builder strictness", "duplicate set-array items accepted");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "GRAIN_ERR_SET_ARRAY_DUP") {
        ok("SDK-INV-0008 set-array builder strictness");
      } else {
        fail("SDK-INV-0008 set-array builder strictness", `unexpected code: ${code}`);
      }
    }

    const explained = sdk.codec.explain("GRAIN_ERR_NONCANONICAL");
    if (
      explained.category !== "CANONICAL"
      || explained.nes_ref.length === 0
      || explained.vector_refs.length === 0
    ) {
      fail("SDK-INV-0009 deterministic error model", "explain() missing category/refs");
    } else {
      ok("SDK-INV-0009 deterministic error model");
    }

    const bundleBytes = sdk.transport.bundleExport({
      objects: {
        "cid:obj:1": new TextEncoder().encode("payload-1")
      },
      events: [
        { t: "IntakeEvent", payload_cid: "cid:intake:1" }
      ],
      manifest: [
        { op: "put", cid: "cid:obj:1" }
      ],
      evidence: {
        strict: true
      }
    });
    const imported = sdk.transport.bundleImport(bundleBytes);
    if (imported.schema !== "grain-transport-bundle-v1" || imported.strict !== true || !imported.objects["cid:obj:1"]) {
      fail("SDK-INV-0010 transport bundle determinism", "bundle import/export mismatch");
    } else {
      ok("SDK-INV-0010 transport bundle determinism");
    }

    const qrVector = loadJsonFixture<{ input: { qr_string: string } }>("../../../../../conformance/vectors/qr/POS-QR-001.json");
    const coseVector = loadJsonFixture<{ input: { pub_b64: string } }>("../../../../../conformance/vectors/cose/POS-COSE-001.json");

    try {
      const verified = sdk.transport.verifyGR1({
        qr_string: qrVector.input.qr_string,
        trust: { pub_b64: coseVector.input.pub_b64 }
      });
      if (!verified.pass || verified.diag.length > 0 || verified.cose_bytes.length === 0) {
        fail("SDK-INV-0010 transport verify requires explicit trust", "verifyGR1 did not produce a clean verified result");
      } else {
        ok("SDK-INV-0010 transport verify requires explicit trust");
      }
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      fail("SDK-INV-0010 transport verify requires explicit trust", `unexpected code: ${code}`);
    }

    try {
      sdk.transport.gr1Verify(qrVector.input.qr_string, undefined as never);
      fail("SDK-NEG-0009 verifyGR1 rejects missing trust", "verifyGR1 accepted a decode-only call");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "SDK_ERR_TRANSPORT_VERIFY_TRUST_REQUIRED") {
        ok("SDK-NEG-0009 verifyGR1 rejects missing trust");
      } else {
        fail("SDK-NEG-0009 verifyGR1 rejects missing trust", `unexpected code: ${code}`);
      }
    }

    for (const invalidTrustCase of [
      { label: "garbage", value: "!!!" },
      { label: "url-safe alphabet", value: "YWJj-_==" },
      { label: "whitespace", value: "YWJj\n" },
      { label: "bad padding", value: "YQ=" }
    ]) {
      const checkName = `SDK-NEG-0009 verifyGR1 rejects malformed trust bytes (${invalidTrustCase.label})`;
      try {
        sdk.transport.verifyGR1({
          qr_string: qrVector.input.qr_string,
          trust: { pub_b64: invalidTrustCase.value }
        });
        fail(checkName, `verifyGR1 accepted malformed trust.pub_b64=${JSON.stringify(invalidTrustCase.value)}`);
      } catch (err) {
        const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
        if (code === "SDK_ERR_TRANSPORT_VERIFY_TRUST_INVALID") {
          ok(checkName);
        } else {
          fail(checkName, `unexpected code: ${code}`);
        }
      }
    }

    try {
      sdk.transport.bundleImport(
        new TextEncoder().encode(
          JSON.stringify({
            schema: "grain-transport-bundle-v1",
            strict: true,
            objects: {},
            events: [{ t: [] }],
            manifest: [{ op: 123, cid: "cid:bad" }],
            evidence: {}
          })
        )
      );
      fail("SDK-NEG-0007 transport bundle row schema", "bundleImport accepted malformed rows");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "SDK_ERR_TRANSPORT_BUNDLE_SCHEMA") {
        ok("SDK-NEG-0007 transport bundle row schema");
      } else {
        fail("SDK-NEG-0007 transport bundle row schema", `unexpected code: ${code}`);
      }
    }

    for (const invalidBundleCase of [
      {
        label: "object payload garbage",
        payload: {
          schema: "grain-transport-bundle-v1",
          strict: true,
          objects: { "cid:obj:bad": "!!!" },
          events: [],
          manifest: [],
          evidence: {}
        }
      },
      {
        label: "object payload bad padding",
        payload: {
          schema: "grain-transport-bundle-v1",
          strict: true,
          objects: { "cid:obj:bad": "YQ=" },
          events: [],
          manifest: [],
          evidence: {}
        }
      },
      {
        label: "manifest cap_id url-safe alphabet",
        payload: {
          schema: "grain-transport-bundle-v1",
          strict: true,
          objects: {},
          events: [],
          manifest: [{ op: "put", cid: "cid:obj:1", cap_id_b64: "YWJj-_==" }],
          evidence: {}
        }
      },
      {
        label: "manifest chash whitespace",
        payload: {
          schema: "grain-transport-bundle-v1",
          strict: true,
          objects: {},
          events: [],
          manifest: [{ op: "put", cid: "cid:obj:1", chash_b64: "YWJj\n" }],
          evidence: {}
        }
      }
    ]) {
      const checkName = `SDK-NEG-0007 transport bundle base64 validation (${invalidBundleCase.label})`;
      try {
        sdk.transport.bundleImport(new TextEncoder().encode(JSON.stringify(invalidBundleCase.payload)));
        fail(checkName, `bundleImport accepted invalid base64 (${invalidBundleCase.label})`);
      } catch (err) {
        const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
        if (code === "SDK_ERR_TRANSPORT_BUNDLE_SCHEMA") {
          ok(checkName);
        } else {
          fail(checkName, `unexpected code: ${code}`);
        }
      }
    }

    try {
      sdk.transport.bundleExport({
        events: [
          {
            t: "IntakeEvent",
            payload_cid: "cid:bad:seq",
            seq: 123
          }
        ],
        manifest: [{ op: "put", cid: "cid:obj:1" }],
        evidence: {}
      });
      fail("SDK-NEG-0007 transport bundle export rejects malformed rows", "bundleExport accepted an unsafe row");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "SDK_ERR_TRANSPORT_BUNDLE_SCHEMA") {
        ok("SDK-NEG-0007 transport bundle export rejects malformed rows");
      } else {
        fail("SDK-NEG-0007 transport bundle export rejects malformed rows", `unexpected code: ${code}`);
      }
    }

    try {
      sdk.transport.bundleExport({
        manifest: [
          {
            op: "put",
            cid: "cid:obj:1",
            cap_id_b64: "!!!"
          }
        ],
        evidence: {}
      });
      fail("SDK-NEG-0007 transport bundle export rejects invalid base64", "bundleExport accepted malformed base64 field");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "SDK_ERR_TRANSPORT_BUNDLE_SCHEMA") {
        ok("SDK-NEG-0007 transport bundle export rejects invalid base64");
      } else {
        fail("SDK-NEG-0007 transport bundle export rejects invalid base64", `unexpected code: ${code}`);
      }
    }

    const identityImportSeed = new GrainSdk();
    await identityImportSeed.identity.createRoot("identity-import-seed");
    const validIdentityBundle = await identityImportSeed.identity.exportBundle();

    const identityRejectStore = new InMemorySdkStore();
    await identityRejectStore.identity.save(validIdentityBundle);
    await identityRejectStore.sequence.importSnapshot(validIdentityBundle.seq_state);
    const identityRejectSdk = new GrainSdk(identityRejectStore);
    const identityBeforeReject = stableJson(await identityRejectStore.identity.load());
    const identitySeqBeforeReject = stableJson(await identityRejectStore.sequence.snapshot());

    for (const invalidIdentityCase of [
      {
        label: "root_pub_b64 garbage",
        mutate(bundle: IdentityBundleV1): void {
          bundle.root_pub_b64 = "!!!";
        }
      },
      {
        label: "sync_secret_b64 url-safe alphabet",
        mutate(bundle: IdentityBundleV1): void {
          bundle.sync_secret_b64 = "YWJj-_==";
        }
      },
      {
        label: "device key pub_b64 whitespace",
        mutate(bundle: IdentityBundleV1): void {
          bundle.device_keys[0].pub_b64 = "YWJj\n";
        }
      },
      {
        label: "root_pub_b64 bad padding",
        mutate(bundle: IdentityBundleV1): void {
          bundle.root_pub_b64 = "YQ=";
        }
      }
    ]) {
      const invalidBundle = cloneJson(validIdentityBundle);
      invalidIdentityCase.mutate(invalidBundle);
      const checkName = `SDK-NEG-0005 identity bundle base64 validation (${invalidIdentityCase.label})`;
      try {
        await identityRejectSdk.identity.importBundle(invalidBundle);
        fail(checkName, `identity.importBundle accepted invalid base64 (${invalidIdentityCase.label})`);
      } catch (err) {
        const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
        const identityAfterReject = stableJson(await identityRejectStore.identity.load());
        const identitySeqAfterReject = stableJson(await identityRejectStore.sequence.snapshot());
        if (
          code !== "SDK_ERR_IDENTITY_BUNDLE_INVALID"
          || identityAfterReject !== identityBeforeReject
          || identitySeqAfterReject !== identitySeqBeforeReject
        ) {
          fail(checkName, `invalid identity import changed state or returned unexpected code (${invalidIdentityCase.label}, code=${code})`);
        } else {
          ok(checkName);
        }
      }
    }

    const seqEvents: LedgerEvent[] = [
      {
        t: "IntakeEvent",
        ak: "alpha",
        seq: 2n,
        payload_cid: "cid:intake:2",
        body: {
          nested: { z: 2, a: 1 },
          tags: ["beta", "alpha"]
        }
      },
      {
        t: "IntakeEvent",
        ak: "alpha",
        seq: 1n,
        payload_cid: "cid:intake:1",
        body: {
          nested: { y: 4, x: 3 },
          tags: ["gamma"]
        }
      }
    ];

    try {
      const exportedA = await sdk.events.exportDeterministicCborSeq(seqEvents);
      const exportedB = await sdk.events.exportDeterministicCborSeq([...seqEvents].reverse());

      if (!Buffer.from(exportedA).equals(Buffer.from(exportedB))) {
        fail("SDK-INV-0011 raw CBOR-seq export determinism", "export bytes changed when input order changed");
      } else {
        const actual = sdk.core.execute(
          "parse_cborseq_stream_v1",
          {
            stream_kind: "ledger",
            cborseq_b64: Buffer.from(exportedA).toString("base64")
          },
          true
        );
        const items = actual.out.item_sha256_hex;
        if (!Array.isArray(items) || items.length !== seqEvents.length) {
          fail("SDK-INV-0011 raw CBOR-seq export determinism", "export did not parse as a 2-item CBOR-seq stream");
        } else {
          ok("SDK-INV-0011 raw CBOR-seq export determinism");
        }
      }
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      fail("SDK-INV-0011 raw CBOR-seq export determinism", `unexpected code: ${code}`);
    }

    const lifecycleSdk = new GrainSdk();
    await lifecycleSdk.identity.createRoot();
    const lifecycleDevice = await lifecycleSdk.identity.addDeviceKey("device-b");
    await lifecycleSdk.identity.setActiveAk(lifecycleDevice.device.ak);
    await lifecycleSdk.events.append({
      t: "IntakeEvent",
      payload_cid: "cid:intake:lifecycle",
      body: { mean: { kcal: 1 }, var: { kcal: 0 } }
    });

    const reducedBeforeRevoke = await lifecycleSdk.events.reduce();
    await lifecycleSdk.identity.revokeDeviceKey(lifecycleDevice.device.ak);
    const reducedAfterRevoke = await lifecycleSdk.events.reduce();

    const sumBefore = extractKcal(reducedBeforeRevoke.out.sum_mean);
    const sumAfter = extractKcal(reducedAfterRevoke.out.sum_mean);
    if (sumBefore !== 1 || sumAfter !== 0) {
      fail(
        "SDK-INV-0012 identity lifecycle stays synced with ledger",
        `unexpected sums before/after revoke: ${sumBefore}/${sumAfter}`
      );
    } else {
      ok("SDK-INV-0012 identity lifecycle stays synced with ledger");
    }

    const originalBundle = await lifecycleSdk.identity.exportBundle();
    const replacementSeed = new GrainSdk();
    await replacementSeed.identity.createRoot("replacement-root");
    const replacementBundle = await replacementSeed.identity.exportBundle();

    const importRollbackBase = new InMemorySdkStore();
    await importRollbackBase.identity.save(originalBundle);
    await importRollbackBase.sequence.importSnapshot(originalBundle.seq_state);

    const importRollbackStore = withStoreOverrides(importRollbackBase, {
      sequence: {
        ...importRollbackBase.sequence,
        importSnapshot: async (snapshot: Record<string, string>): Promise<void> => {
          await importRollbackBase.sequence.importSnapshot(snapshot);
          throw new Error("synthetic import snapshot failure");
        }
      }
    });
    const importRollbackSdk = new GrainSdk(importRollbackStore);

    try {
      await importRollbackSdk.identity.importBundle(replacementBundle);
      fail("SDK-INV-0013 identity import rollback", "importBundle accepted a store that fails mid-import");
    } catch {
      const restoredBundle = await importRollbackBase.identity.load();
      const restoredSeq = await importRollbackBase.sequence.snapshot();
      if (
        !restoredBundle
        || stableJson(restoredBundle) !== stableJson(originalBundle)
        || stableJson(restoredSeq) !== stableJson(originalBundle.seq_state)
      ) {
        fail("SDK-INV-0013 identity import rollback", "importBundle left partially imported identity or sequence state");
      } else {
        ok("SDK-INV-0013 identity import rollback");
      }
    }

    const correctionStore = new InMemorySdkStore();
    const correctionSdk = new GrainSdk(correctionStore);
    await correctionSdk.identity.createRoot();
    const revokedDevice = await correctionSdk.identity.addDeviceKey("revoked-device");
    await correctionSdk.identity.revokeDeviceKey(revokedDevice.device.ak);
    const eventsBeforeFailedCorrection = await correctionStore.events.list();

    try {
      await correctionSdk.events.correct("event:target:1", {
        ak: revokedDevice.device.ak,
        t: "IntakeEvent",
        payload_cid: "cid:intake:correction-replacement",
        body: { mean: { kcal: 5 }, var: { kcal: 0 } }
      });
      fail("SDK-INV-0013 correct rollback", "events.correct accepted a replacement that should fail");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      const eventsAfterFailedCorrection = await correctionStore.events.list();
      const correctionCount = eventsAfterFailedCorrection.filter((event) => event.t === "CorrectionEvent").length;
      if (
        code !== "SDK_ERR_UNAUTHORIZED_AK"
        || eventsAfterFailedCorrection.length !== eventsBeforeFailedCorrection.length
        || correctionCount !== 0
      ) {
        fail("SDK-INV-0013 correct rollback", `partial correction state escaped rollback (code=${code})`);
      } else {
        ok("SDK-INV-0013 correct rollback");
      }
    }

    const summary = {
      total: checks.length,
      failed: checks.filter((c) => !c.pass).length,
      checks
    };

    process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
    return summary.failed === 0 ? 0 : 1;
  } catch (err) {
    fail("SDK-INV-9999 internal", err instanceof Error ? err.message : "unknown");
    process.stdout.write(`${JSON.stringify({ total: checks.length, failed: 1, checks }, null, 2)}\n`);
    return 1;
  }
}

run().then((code) => process.exit(code));

function extractKcal(value: unknown): number | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const kcal = (value as Record<string, unknown>).kcal;
  return typeof kcal === "number" ? kcal : null;
}

function loadJsonFixture<T>(relativePath: string): T {
  return JSON.parse(readFileSync(new URL(relativePath, import.meta.url), "utf8")) as T;
}

function stableJson(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map((entry) => stableJson(entry)).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
      .map(([key, entry]) => `${JSON.stringify(key)}:${stableJson(entry)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

function cloneJson<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function withStoreOverrides(base: InMemorySdkStore, overrides: Partial<GrainSdkStore>): GrainSdkStore {
  return {
    atomic: overrides.atomic ?? base.atomic,
    sequence: overrides.sequence ?? base.sequence,
    events: overrides.events ?? base.events,
    objects: overrides.objects ?? base.objects,
    blobs: overrides.blobs ?? base.blobs,
    manifest: overrides.manifest ?? base.manifest,
    identity: overrides.identity ?? base.identity
  };
}
