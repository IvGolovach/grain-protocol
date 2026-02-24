#!/usr/bin/env node
import { createHash } from "node:crypto";

import { GrainSdk } from "../src/index.ts";
import { SdkError } from "../src/errors.ts";

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

    // cap single-assignment corruption guard
    try {
      const randomCap = e1.cap_id;
      const badCipher = new TextEncoder().encode("bad-cipher");
      const badChash = new Uint8Array(createHash("sha256").update(Buffer.from(badCipher)).digest());
      await sdk.store.blobs.put(randomCap, badCipher, badChash);
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
