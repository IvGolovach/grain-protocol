#!/usr/bin/env node

import { GrainSdk } from "../src/index.js";
import { SdkError } from "../src/errors.js";
import { buildSetArray } from "../src/primitives.js";

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
