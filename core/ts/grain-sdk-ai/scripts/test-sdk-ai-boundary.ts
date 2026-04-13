#!/usr/bin/env node
import { GrainSdk } from "grain-sdk-ts";
import { createGrainSdkAi } from "../src/index.js";
import { encodeB64 } from "../src/sdk-utils.js";

const checks: Array<{ name: string; pass: boolean; detail?: string }> = [];

function ok(name: string): void {
  checks.push({ name, pass: true });
}

function fail(name: string, detail: string): void {
  checks.push({ name, pass: false, detail });
}

function summarize(): number {
  const out = {
    total: checks.length,
    failed: checks.filter((x) => !x.pass).length,
    checks
  };
  process.stdout.write(`${JSON.stringify(out, null, 2)}\n`);
  return out.failed === 0 ? 0 : 1;
}

async function run(): Promise<number> {
  const sdk = new GrainSdk();
  const ai = createGrainSdkAi(sdk);
  await sdk.identity.createRoot();

  if ("ai" in (sdk as unknown as Record<string, unknown>)) {
    fail("SDK-AI-000 sidecar stays optional", "public sdk.ai still exists");
  } else {
    ok("SDK-AI-000 sidecar stays optional");
  }

  if ("store" in (sdk as unknown as Record<string, unknown>)) {
    fail("SDK-AI-001 no public sdk.store", "public sdk.store still exists");
  } else {
    ok("SDK-AI-001 no public sdk.store");
  }

  const candidate = {
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "Claim",
    payload_format: "structured_v1",
    payload: {
      profile_id: "claim_v1",
      data: {
        amount: "42",
        tags: ["gamma", "alpha", "beta"]
      },
      numeric_fields: {
        "/amount": "u63"
      },
      set_array_fields: ["/tags"]
    }
  } as const;

  const r1 = await ai.accept(candidate);
  const r2 = await ai.accept(candidate);
  if (r1.status !== "accepted" || r2.status !== "accepted") {
    fail("SDK-AI-002 deterministic accept", "expected accepted status for deterministic case");
  } else if (
    r1.cid !== r2.cid
    || Buffer.from(r1.canonical_bytes).toString("hex") !== Buffer.from(r2.canonical_bytes).toString("hex")
  ) {
    fail("SDK-AI-002 deterministic accept", "same candidate produced different bytes/cid");
  } else {
    ok("SDK-AI-002 deterministic accept");
  }

  if (r1.status === "accepted") {
    if (!r1.normalization_applied.includes("set_array_sorted:/tags")) {
      fail("SDK-AI-006 set-array normalization trace", "expected normalization record for unsorted set-array");
    } else {
      ok("SDK-AI-006 set-array normalization trace");
    }
  }

  const numberReject = await ai.accept({
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "Claim",
    payload_format: "structured_v1",
    payload: {
      data: { amount: 42 },
      numeric_fields: { "/amount": "u63" }
    }
  });
  if (numberReject.status !== "rejected" || numberReject.error.code !== "SDK_ERR_AI_NUMERIC_NOT_DECIMAL_STRING") {
    fail("SDK-AI-005 numeric fields reject JS number", "expected SDK_ERR_AI_NUMERIC_NOT_DECIMAL_STRING");
  } else {
    ok("SDK-AI-005 numeric fields reject JS number");
  }

  const dupReject = await ai.accept({
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "CustomSetOnly",
    payload_format: "structured_v1",
    payload: {
      data: { tags: ["alpha", "alpha"] },
      set_array_fields: ["/tags"]
    }
  });
  if (dupReject.status !== "rejected" || dupReject.error.code !== "GRAIN_ERR_SET_ARRAY_DUP") {
    fail("SDK-AI-006 set-array duplicates reject", "expected GRAIN_ERR_SET_ARRAY_DUP");
  } else {
    ok("SDK-AI-006 set-array duplicates reject");
  }

  const profileMissing = await ai.accept({
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "UnknownType",
    payload_format: "structured_v1",
    payload: {
      data: { any: "value" }
    }
  });
  if (profileMissing.status !== "rejected" || profileMissing.error.code !== "SDK_ERR_AI_PROFILE_MISSING") {
    fail("SDK-AI-005 explicit profile required", "expected SDK_ERR_AI_PROFILE_MISSING for unknown target without field maps");
  } else {
    ok("SDK-AI-005 explicit profile required");
  }

  const quarantine = await ai.accept({
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "Claim",
    payload_format: "structured_v1",
    payload: { data: { claim_id: "q1" } },
    critical_extensions: ["ext/unknown-critical"]
  });
  if (quarantine.status !== "quarantined" || quarantine.error.code !== "SDK_ERR_AI_QUARANTINED_UNKNOWN_CRITICAL") {
    fail("SDK-AI-007 unknown critical quarantine", "expected deterministic quarantine");
  } else {
    ok("SDK-AI-007 unknown critical quarantine");
    const blocked = await ai.applyAccepted((quarantine as unknown as { token: unknown }).token);
    if (blocked.status !== "rejected" || blocked.error.code !== "SDK_ERR_ACCEPT_TOKEN_FORGED") {
      fail("SDK-AI-007 quarantined cannot apply", "quarantined path must not be applicable");
    } else {
      ok("SDK-AI-007 quarantined cannot apply");
    }
  }

  if (r1.status === "accepted") {
    const applied = await ai.applyAccepted(r1.token);
    if (applied.status !== "applied") {
      fail("SDK-AI-001 apply accepted token", "expected apply to succeed");
    } else {
      ok("SDK-AI-001 apply accepted token");
    }

    const replay = await ai.applyAccepted(r1.token);
    if (replay.status !== "rejected" || replay.error.code !== "SDK_ERR_ACCEPT_TOKEN_UNKNOWN") {
      fail("SDK-AI-002 replay reject", "expected consumed token to reject as unknown");
    } else {
      ok("SDK-AI-002 replay reject");
    }
  }

  const forged = await ai.applyAccepted({ id: "fake-token", issued_at_ms: 0 });
  if (forged.status !== "rejected" || forged.error.code !== "SDK_ERR_ACCEPT_TOKEN_FORGED") {
    fail("SDK-AI-001 forged token reject", "expected forged token reject");
  } else {
    ok("SDK-AI-001 forged token reject");
  }

  {
    let now = 1_000;
    const expirySdk = new GrainSdk();
    const expiryAi = createGrainSdkAi(expirySdk, {
      token_ttl_ms: 600_000,
      now_ms: () => now
    });
    await expirySdk.identity.createRoot();
    const accepted = await expiryAi.accept({
      candidate_version: 1,
      kind: "object",
      target_schema_major: 1,
      target_type: "Claim",
      payload_format: "structured_v1",
      payload: {
        profile_id: "claim_v1",
        data: { amount: "1", tags: ["ttl"] }
      }
    });
    if (accepted.status !== "accepted") {
      fail("SDK-AI-002 token expiry setup", "accept failed in expiry setup");
    } else {
      now += 601_000;
      const expired = await expiryAi.applyAccepted(accepted.token);
      if (expired.status !== "rejected" || expired.error.code !== "SDK_ERR_ACCEPT_TOKEN_EXPIRED") {
        fail("SDK-AI-002 token expiry", "expected SDK_ERR_ACCEPT_TOKEN_EXPIRED");
      } else {
        ok("SDK-AI-002 token expiry");
      }
    }
  }

  {
    const capSdk = new GrainSdk();
    const capAi = createGrainSdkAi(capSdk, {
      max_pending_tokens: 1
    });
    await capSdk.identity.createRoot();
    const first = await capAi.accept({
      candidate_version: 1,
      kind: "object",
      target_schema_major: 1,
      target_type: "Claim",
      payload_format: "structured_v1",
      payload: {
        profile_id: "claim_v1",
        data: { amount: "1", tags: ["cap-1"] }
      }
    });
    const second = await capAi.accept({
      candidate_version: 1,
      kind: "object",
      target_schema_major: 1,
      target_type: "Claim",
      payload_format: "structured_v1",
      payload: {
        profile_id: "claim_v1",
        data: { amount: "2", tags: ["cap-2"] }
      }
    });
    if (first.status !== "accepted") {
      fail("SDK-AI-002 token cap setup", "first accept failed");
    } else if (second.status !== "rejected" || second.error.code !== "SDK_ERR_ACCEPT_TOKEN_CAP_REACHED") {
      fail("SDK-AI-002 token cap reached", "expected SDK_ERR_ACCEPT_TOKEN_CAP_REACHED");
    } else {
      ok("SDK-AI-002 token cap reached");
    }
  }

  const dagBytes = new Uint8Array([0xa1, 0x61, 0x61, 0x01]);
  const dagAccepted = await ai.accept({
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "Claim",
    payload_format: "dagcbor_b64",
    payload: encodeB64(dagBytes)
  });
  if (dagAccepted.status !== "accepted") {
    fail("SDK-AI-002 dagcbor accept path", "expected valid dagcbor bytes to pass");
  } else {
    ok("SDK-AI-002 dagcbor accept path");
  }

  const privacy = await ai.accept({
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "CustomBytesOnly",
    payload_format: "structured_v1",
    payload: {
      data: {
        secret_blob: "not-base64-!!!"
      },
      bytes_fields: ["/secret_blob"]
    }
  });
  if (privacy.status !== "rejected") {
    fail("SDK-AI-004 redaction default", "expected reject for invalid base64 bytes field");
  } else {
    const serialized = JSON.stringify(privacy.error);
    if (serialized.includes("not-base64-!!!")) {
      fail("SDK-AI-004 redaction default", "error explain leaked raw candidate bytes");
    } else {
      ok("SDK-AI-004 redaction default");
    }
  }

  const sensitive = await ai.accept({
    candidate_version: 1,
    kind: "object",
    target_schema_major: 1,
    target_type: "CustomBytesOnly",
    payload_format: "structured_v1",
    payload: {
      data: {
        secret_blob: "still-not-base64-@@@"
      },
      bytes_fields: ["/secret_blob"]
    }
  }, { include_sensitive: true });
  if (sensitive.status !== "rejected") {
    fail("SDK-AI-004 sensitive mode bounded", "expected reject in sensitive mode case");
  } else {
    const details = sensitive.error.sensitive_details;
    if (!details || typeof details.candidate_sha256_16 !== "string") {
      fail("SDK-AI-004 sensitive mode bounded", "expected bounded sensitive_details hash");
    } else if (JSON.stringify(details).includes("still-not-base64-@@@")) {
      fail("SDK-AI-004 sensitive mode bounded", "sensitive mode leaked raw candidate payload");
    } else if (sensitive.error.redaction_policy.includes_raw_candidate_bytes || sensitive.error.redaction_policy.includes_plaintext_private_bytes) {
      fail("SDK-AI-004 sensitive mode bounded", "redaction policy incorrectly allows raw bytes");
    } else {
      ok("SDK-AI-004 sensitive mode bounded");
    }
  }

  return summarize();
}

run().then((code) => process.exit(code));
