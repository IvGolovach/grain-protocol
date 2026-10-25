#!/usr/bin/env node

import { createHash, createPrivateKey, createPublicKey, sign } from "node:crypto";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { encodeCanonical, parseOne, STRICT_DAG_CBOR_OPTIONS } from "grain-ts-core/cbor";
import type { CborNode } from "grain-ts-core/types";

import { GrainSdk, InMemorySdkStore } from "../src/index.js";
import { SdkError } from "../src/errors.js";
import { buildSetArray } from "../src/primitives.js";
import type { GrainSdkStore, IdentityBundleV1, LedgerEvent } from "../src/index.js";

const ED25519_PKCS8_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");

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
      const tampered = signedServingOfferWithMismatchedIssuerKid(sdk);
      sdk.transport.verifyGR1({
        qr_string: tampered.qr_string,
        trust: { pub_b64: tampered.pub_b64 }
      });
      fail("SDK-NEG-0029 verifyGR1 rejects ServingOffer issuer_kid mismatch", "verifyGR1 accepted a signed offer for a different issuer_kid");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "GRAIN_ERR_SCHEMA") {
        ok("SDK-NEG-0029 verifyGR1 rejects ServingOffer issuer_kid mismatch");
      } else {
        fail("SDK-NEG-0029 verifyGR1 rejects ServingOffer issuer_kid mismatch", `unexpected code: ${code}`);
      }
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
      },
      {
        label: "root_pub_b64 does not derive root_kid",
        mutate(bundle: IdentityBundleV1): void {
          bundle.root_pub_b64 = Buffer.from(new Uint8Array(32).fill(7)).toString("base64");
        }
      },
      {
        label: "device ak does not derive from pub_b64",
        mutate(bundle: IdentityBundleV1): void {
          bundle.device_keys[0].ak = "0".repeat(32);
        }
      },
      {
        label: "duplicate device key ak",
        mutate(bundle: IdentityBundleV1): void {
          bundle.device_keys.push(cloneJson(bundle.device_keys[0]));
        }
      },
      {
        label: "active key is not authorized",
        mutate(bundle: IdentityBundleV1): void {
          bundle.active_ak = "f".repeat(32);
        }
      },
      {
        label: "seq_state is not a u64 decimal",
        mutate(bundle: IdentityBundleV1): void {
          bundle.seq_state[bundle.root_kid] = "1.5";
        }
      },
      {
        label: "seq_state has non-canonical leading zeros",
        mutate(bundle: IdentityBundleV1): void {
          bundle.seq_state[bundle.root_kid] = "007";
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
      // Stream framing alone does not check the canonical ordering inside each item.
      let offset = 0;
      for (const _event of seqEvents) {
        const parsed = parseOne(exportedA.subarray(offset), STRICT_DAG_CBOR_OPTIONS);
        assert.equal(parsed.node.kind, "m");
        offset += parsed.used;
      }
      assert.equal(offset, exportedA.length);

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

    try {
      const entries: Array<[string, number]> = [
        ["a".repeat(24), 24], ["é", 2], ["aaaa", 4], ["z", 1],
        ["b".repeat(23), 23], ["zz", 3]
      ];
      const expectedKeys = ["z", "zz", "é", "aaaa", "b".repeat(23), "a".repeat(24)];
      const event: LedgerEvent = {
        t: "IntakeEvent", ak: "canonical-test", seq: 1n, payload_cid: "canonical-test",
        body: { nested: [Object.fromEntries(entries)] }
      };
      const bytes = await sdk.events.exportDeterministicCborSeq([event]);
      const reversed = await sdk.events.exportDeterministicCborSeq([
        { ...event, body: { nested: [Object.fromEntries([...entries].reverse())] } }
      ]);
      assert.deepEqual(bytes, reversed);
      const parsed = parseOne(bytes, STRICT_DAG_CBOR_OPTIONS);
      assert.equal(parsed.used, bytes.length);
      assert.equal(parsed.node.kind, "m");
      if (parsed.node.kind !== "m") throw new Error("expected event map");
      const keys = parsed.node.entries.map(({ key }) => key.kind === "t" ? Buffer.from(key.bytes).toString("utf8") : "");
      assert.deepEqual(keys, ["t", "ak", "seq", "body", "payload_cid"]);
      const body = parsed.node.entries.find(({ key }) => key.kind === "t" && Buffer.from(key.bytes).toString("utf8") === "body")?.value;
      if (body?.kind !== "m") throw new Error("expected body map");
      const nested = body.entries[0]?.value;
      if (nested?.kind !== "a" || nested.items[0]?.kind !== "m") throw new Error("expected nested map");
      assert.deepEqual(nested.items[0].entries.map(({ key }) => key.kind === "t" ? Buffer.from(key.bytes).toString("utf8") : ""), expectedKeys);
      assert.deepEqual(nested.items[0].entries.map(({ value }) => value.kind === "u" ? Number(value.value) : null), [1, 3, 2, 4, 23, 24]);
      ok("SDK-REG-0004 raw CBOR-seq orders nested UTF-8 keys canonically");
    } catch (err) {
      fail("SDK-REG-0004 raw CBOR-seq orders nested UTF-8 keys canonically", String(err));
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

    const conflictStore = new InMemorySdkStore();
    await conflictStore.identity.save(originalBundle);
    await conflictStore.sequence.importSnapshot(originalBundle.seq_state);
    const conflictSdk = new GrainSdk(conflictStore);
    try {
      await conflictSdk.identity.importBundle(replacementBundle);
      fail("SDK-NEG-0006 identity import rejects replacement root", "importBundle accepted a different root over an existing identity");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      const conflictBundle = await conflictStore.identity.load();
      if (code !== "SDK_ERR_IDENTITY_CONFLICT" || stableJson(conflictBundle) !== stableJson(originalBundle)) {
        fail("SDK-NEG-0006 identity import rejects replacement root", `unexpected code or state mutation: ${code}`);
      } else {
        ok("SDK-NEG-0006 identity import rejects replacement root");
      }
    }

    const toctouBase = new InMemorySdkStore();
    await toctouBase.identity.save(originalBundle);
    await toctouBase.sequence.importSnapshot(originalBundle.seq_state);
    let insideAtomicImport = false;
    let toctouSavedReplacement = false;
    const toctouStore = withStoreOverrides(toctouBase, {
      atomic: async (mutation) => {
        insideAtomicImport = true;
        try {
          return await toctouBase.atomic(mutation);
        } finally {
          insideAtomicImport = false;
        }
      },
      identity: {
        load: async () => (insideAtomicImport ? originalBundle : null),
        save: async (bundle: IdentityBundleV1) => {
          toctouSavedReplacement = true;
          await toctouBase.identity.save(bundle);
        }
      }
    });
    const toctouSdk = new GrainSdk(toctouStore);
    try {
      await toctouSdk.identity.importBundle(replacementBundle);
      fail("SDK-NEG-0006 identity import checks existing root inside atomic", "importBundle accepted stale pre-atomic root state");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      const toctouBundle = await toctouBase.identity.load();
      if (code !== "SDK_ERR_IDENTITY_CONFLICT" || toctouSavedReplacement || stableJson(toctouBundle) !== stableJson(originalBundle)) {
        fail("SDK-NEG-0006 identity import checks existing root inside atomic", `unexpected code or state mutation: ${code}`);
      } else {
        ok("SDK-NEG-0006 identity import checks existing root inside atomic");
      }
    }

    const emptyLabelSeed = new GrainSdk();
    await emptyLabelSeed.identity.createRoot("");
    await emptyLabelSeed.identity.addDeviceKey("");
    const emptyLabelBundle = await emptyLabelSeed.identity.exportBundle();
    const emptyLabelImportSdk = new GrainSdk();
    try {
      await emptyLabelImportSdk.identity.importBundle(emptyLabelBundle);
      const importedEmptyLabelBundle = await emptyLabelImportSdk.identity.exportBundle();
      const labels = importedEmptyLabelBundle.device_keys.map((device) => device.label);
      if (!labels.includes("")) {
        fail("SDK-REG-0001 identity bundle accepts empty labels", "import/export lost an empty device label");
      } else {
        ok("SDK-REG-0001 identity bundle accepts empty labels");
      }
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      fail("SDK-REG-0001 identity bundle accepts empty labels", `unexpected code: ${code}`);
    }

    try {
      const importSdk = new GrainSdk();
      const { root_kid: root } = await importSdk.identity.createRoot();
      const old = await importSdk.identity.exportBundle();
      const first = await importSdk.identity.addDeviceKey("first");
      await importSdk.identity.importBundle(old);
      await importSdk.identity.setActiveAk(root);
      const second = await importSdk.identity.addDeviceKey("second");
      assert.equal(second.grant_event.ak, first.grant_event.ak);
      assert.notEqual(second.grant_event.payload_cid, first.grant_event.payload_cid);
      assert.equal(second.grant_event.seq, first.grant_event.seq + 1n);
      assert.deepEqual((await importSdk.identity.exportBundle()).seq_state, { [root]: "2" });
      ok("SDK-REG-0002 stale identity import preserves sequence");
    } catch (err) {
      fail("SDK-REG-0002 stale identity import preserves sequence", String(err));
    }

    try {
      const importSdk = new GrainSdk();
      const { root_kid: root } = await importSdk.identity.createRoot();
      const old = await importSdk.identity.exportBundle();
      await importSdk.identity.addDeviceKey("first");
      await importSdk.identity.importBundle(old);
      await importSdk.identity.importBundle(old);
      const restarted = new GrainSdk();
      await restarted.identity.importBundle(await importSdk.identity.exportBundle());
      assert.equal((await restarted.identity.addDeviceKey("after restart")).grant_event.seq, 2n);
      assert.deepEqual(old.seq_state, {});
      assert.equal((await restarted.identity.exportBundle()).seq_state[root], "2");
      ok("SDK-REG-0002 imported sequence survives export and restart");
    } catch (err) {
      fail("SDK-REG-0002 imported sequence survives export and restart", String(err));
    }

    try {
      const importSdk = new GrainSdk();
      const { root_kid: root } = await importSdk.identity.createRoot();
      const old = await importSdk.identity.exportBundle();
      const { device } = await importSdk.identity.addDeviceKey("local-device");
      const current = await importSdk.identity.exportBundle();
      current.seq_state[root] = "9";
      current.seq_state[device.ak] = "9";
      await importSdk.identity.importBundle(current);
      old.seq_state = { [root]: "11", "incoming-only": "11" };
      await importSdk.identity.importBundle(old);
      const merged = await importSdk.identity.exportBundle();
      assert.deepEqual(merged.seq_state, { [root]: "11", [device.ak]: "9", "incoming-only": "11" });
      assert.equal(merged.device_keys.length, 2);
      await importSdk.identity.setActiveAk(device.ak);
      await assert.rejects(importSdk.identity.setActiveAk("incoming-only"), { code: "SDK_ERR_UNAUTHORIZED_AK" });
      assert.equal((await importSdk.identity.addDeviceKey("next")).grant_event.seq, 12n);
      old.seq_state = {};
      await importSdk.identity.importBundle(old);
      assert.equal((await importSdk.identity.exportBundle()).seq_state[root], "12");
      ok("SDK-REG-0002 identity import keeps per-author maxima and retained authorization");
    } catch (err) {
      fail("SDK-REG-0002 identity import keeps per-author maxima and retained authorization", String(err));
    }

    for (const operation of ["event", "manifest-put", "manifest-del"] as const) {
      const check = `SDK-REG-0002 identity import preserves live ${operation} counters`;
      try {
        const allocate = async (client: GrainSdk, label: string): Promise<bigint> => {
          if (operation === "event") {
            return (await client.events.append({ t: "IntakeEvent", payload_cid: label, body: {} })).event.seq;
          }
          if (operation === "manifest-put") {
            return (await client.manifest.put(label, new Uint8Array(16), new Uint8Array(32))).seq;
          }
          return (await client.manifest.del(label)).seq;
        };
        const importSdk = new GrainSdk();
        const { root_kid: root } = await importSdk.identity.createRoot();
        const old = await importSdk.identity.exportBundle();
        assert.equal(await allocate(importSdk, "first"), 1n);
        await importSdk.identity.importBundle(old);
        assert.equal((await importSdk.identity.exportBundle()).seq_state[root], "1");
        await importSdk.identity.setActiveAk(root);
        assert.equal(await allocate(importSdk, "second"), 2n);
        await importSdk.identity.importBundle(old);
        const restarted = new GrainSdk();
        await restarted.identity.importBundle(await importSdk.identity.exportBundle());
        assert.equal(await allocate(restarted, "third"), 3n);
        ok(check);
      } catch (err) {
        fail(check, String(err));
      }
    }

    for (const history of ["grant", "revoke"] as const) {
      const check = `SDK-REG-0003 identity import retains local ${history} history`;
      try {
        const store = new InMemorySdkStore();
        const client = new GrainSdk(store);
        const { root_kid: root } = await client.identity.createRoot();
        const beforeGrant = await client.identity.exportBundle();
        const { device } = await client.identity.addDeviceKey("local");
        await client.identity.setActiveAk(device.ak);
        const old = history === "grant" ? beforeGrant : await client.identity.exportBundle();
        if (history === "revoke") await client.identity.revokeDeviceKey(device.ak);
        const events = await store.events.list();
        await client.identity.importBundle(old);
        const merged = await client.identity.exportBundle();
        assert(merged.device_keys.some((key) => key.ak === device.ak));
        assert.equal(merged.active_ak, history === "grant" ? device.ak : root);
        assert.equal(merged.revoked_aks.includes(device.ak), history === "revoke");
        assert.deepEqual(await store.events.list(), events);
        await client.identity.importBundle(old);
        assert(stableJson(await client.identity.exportBundle()) === stableJson(merged));
        const restarted = new GrainSdk();
        await restarted.identity.importBundle(merged);
        if (history === "revoke") {
          await assert.rejects(restarted.identity.setActiveAk(device.ak), { code: "SDK_ERR_UNAUTHORIZED_AK" });
        } else {
          await restarted.identity.setActiveAk(device.ak);
        }
        assert.equal((await restarted.identity.addDeviceKey("next")).grant_event.seq, history === "grant" ? 2n : 3n);
        ok(check);
      } catch (err) {
        fail(check, String(err));
      }
    }

    try {
      const source = new GrainSdk();
      const { root_kid: root } = await source.identity.createRoot();
      const { device: common } = await source.identity.addDeviceKey("common");
      const store = new InMemorySdkStore();
      const target = new GrainSdk(store);
      await target.identity.importBundle(await source.identity.exportBundle());
      await target.identity.setActiveAk(common.ak);
      const { device: local } = await target.identity.addDeviceKey("local");
      const events = await store.events.list();
      await source.identity.revokeDeviceKey(common.ak);
      const { device: remote } = await source.identity.addDeviceKey("remote");
      const incoming = await source.identity.exportBundle();
      await target.identity.importBundle(incoming);
      const merged = await target.identity.exportBundle();
      assert.equal(merged.device_keys.length, 4);
      assert(merged.device_keys.some((key) => key.ak === local.ak));
      assert(merged.device_keys.some((key) => key.ak === remote.ak));
      assert(merged.revoked_aks.includes(common.ak));
      assert.equal(merged.active_ak, root);
      assert.equal(merged.seq_state[root], "3");
      assert.deepEqual(await store.events.list(), events);
      await target.identity.importBundle(incoming);
      assert(stableJson(await target.identity.exportBundle()) === stableJson(merged));
      ok("SDK-REG-0003 identity import merges new devices and revocations");
    } catch (err) {
      fail("SDK-REG-0003 identity import merges new devices and revocations", String(err));
    }

    try {
      const store = new InMemorySdkStore();
      const client = new GrainSdk(store);
      await client.identity.createRoot();
      await client.identity.addDeviceKey("device");
      const before = await client.identity.exportBundle();
      const counters = await store.sequence.snapshot();
      const incoming = structuredClone(before);
      const secret = Buffer.from(incoming.sync_secret_b64, "base64");
      secret[0] ^= 1;
      incoming.sync_secret_b64 = secret.toString("base64");
      await assert.rejects(client.identity.importBundle(incoming), { code: "SDK_ERR_IDENTITY_CONFLICT" });
      assert(stableJson(await client.identity.exportBundle()) === stableJson(before));
      assert.deepEqual(await store.sequence.snapshot(), counters);
      ok("SDK-REG-0003 identity import rejects changed sync secret without mutation");
    } catch (err) {
      fail("SDK-REG-0003 identity import rejects changed sync secret without mutation", String(err));
    }

    const importRollbackBase = new InMemorySdkStore();
    await importRollbackBase.identity.save(originalBundle);
    await importRollbackBase.sequence.importSnapshot(originalBundle.seq_state);
    await lifecycleSdk.identity.addDeviceKey("rollback-device");
    const sameRootReplacementBundle = await lifecycleSdk.identity.exportBundle();

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
      await importRollbackSdk.identity.importBundle(sameRootReplacementBundle);
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

    try {
      await sdk.events.exportDeterministicCborSeq([
        {
          t: "IntakeEvent",
          ak: "alpha",
          seq: 3n,
          payload_cid: "cid:intake:fractional",
          body: { confidence_score: 0.5 }
        }
      ]);
      fail("SDK-NEG-0007 raw CBOR-seq export rejects fractional numbers", "exportDeterministicCborSeq accepted a fractional JSON number");
    } catch (err) {
      const code = err instanceof SdkError ? err.code : "SDK_ERR_INTERNAL";
      if (code === "SDK_ERR_CBORSEQ_UNSUPPORTED_NUMBER") {
        ok("SDK-NEG-0007 raw CBOR-seq export rejects fractional numbers");
      } else {
        fail("SDK-NEG-0007 raw CBOR-seq export rejects fractional numbers", `unexpected code: ${code}`);
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

function signedServingOfferWithMismatchedIssuerKid(sdk: GrainSdk): { qr_string: string; pub_b64: string } {
  const seed = new Uint8Array(32).fill(7);
  const privateKey = createPrivateKey({
    key: Buffer.concat([ED25519_PKCS8_PREFIX, Buffer.from(seed)]),
    format: "der",
    type: "pkcs8"
  });
  const publicDer = Buffer.from(createPublicKey(privateKey).export({ format: "der", type: "spki" }));
  const publicKey = new Uint8Array(publicDer.subarray(publicDer.length - 32));
  const protectedKid = kidForPublicKey(publicKey);
  const payloadIssuerKid = new Uint8Array(16).fill(0x42);
  const payload = encodeCanonical({
    kind: "m",
    entries: [
      textEntry("t", { kind: "t", bytes: utf8("ServingOffer") }),
      textEntry("v", { kind: "u", value: 1n }),
      textEntry("var", { kind: "m", entries: [] }),
      textEntry("mean", { kind: "m", entries: [] }),
      textEntry("serving_g", { kind: "u", value: 250n }),
      textEntry("issuer_kid", { kind: "b", value: payloadIssuerKid })
    ]
  });
  const cose = signCosePayload(privateKey, payload, protectedKid);
  return {
    qr_string: sdk.transport.gr1Encode(cose),
    pub_b64: Buffer.from(publicKey).toString("base64")
  };
}

function signCosePayload(privateKey: ReturnType<typeof createPrivateKey>, payload: Uint8Array, kid: Uint8Array): Uint8Array {
  const protectedBstr = encodeCanonical({
    kind: "m",
    entries: [
      { key: { kind: "u", value: 1n }, keyBytes: new Uint8Array(), value: { kind: "n", value: -19n } },
      { key: { kind: "u", value: 4n }, keyBytes: new Uint8Array(), value: { kind: "b", value: kid } }
    ]
  });
  const sigStructure = encodeCanonical({
    kind: "a",
    items: [
      { kind: "t", bytes: utf8("Signature1") },
      { kind: "b", value: protectedBstr },
      { kind: "b", value: new Uint8Array() },
      { kind: "b", value: payload }
    ]
  });
  const signature = sign(null, Buffer.from(sigStructure), privateKey);
  return encodeCanonical({
    kind: "a",
    items: [
      { kind: "b", value: protectedBstr },
      { kind: "m", entries: [] },
      { kind: "b", value: payload },
      { kind: "b", value: new Uint8Array(signature) }
    ]
  });
}

function kidForPublicKey(publicKey: Uint8Array): Uint8Array {
  return new Uint8Array(createHash("sha256").update(publicKey).digest().subarray(0, 16));
}

function textEntry(key: string, value: CborNode): { key: CborNode; keyBytes: Uint8Array; value: CborNode } {
  return {
    key: { kind: "t", bytes: utf8(key) },
    keyBytes: new Uint8Array(),
    value
  };
}

function utf8(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}
