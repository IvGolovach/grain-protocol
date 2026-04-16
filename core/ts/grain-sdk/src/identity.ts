import type { GrainSdkStore } from "./store.js";
import type { DeviceKey, IdentityBundleV1, LedgerEvent } from "./types.js";
import { SdkError } from "./errors.js";
import { randomBytes32, encodeB64, sha256Hex, decodeB64 } from "./utils.js";

export class IdentityManager {
  private readonly store: GrainSdkStore;

  constructor(store: GrainSdkStore) {
    this.store = store;
  }

  async createRoot(label = "root"): Promise<{ root_kid: string; active_ak: string }> {
    const existing = await this.store.identity.load();
    if (existing) {
      throw new SdkError("SDK_ERR_IDENTITY_EXISTS", "Root identity already exists");
    }

    const rootPub = randomBytes32();
    const rootKid = deriveKid(rootPub);
    const syncSecret = randomBytes32();

    const bundle: IdentityBundleV1 = {
      bundle_v: 1,
      root_kid: rootKid,
      root_pub_b64: encodeB64(rootPub),
      active_ak: rootKid,
      sync_secret_b64: encodeB64(syncSecret),
      device_keys: [
        {
          ak: rootKid,
          label,
          pub_b64: encodeB64(rootPub)
        }
      ],
      revoked_aks: [],
      seq_state: {}
    };

    await this.store.identity.save(bundle);
    return { root_kid: rootKid, active_ak: rootKid };
  }

  async addDeviceKey(label = "device"): Promise<{ device: DeviceKey; grant_event: LedgerEvent }> {
    const pub = randomBytes32();
    const pubB64 = encodeB64(pub);
    const ak = deriveKid(pub);
    let grantEvent: LedgerEvent | null = null;

    await this.store.atomic(async () => {
      const bundle = await this.requireBundle();
      const nextBundle = cloneIdentityBundle(bundle);
      const rootKid = nextBundle.root_kid;

      if (nextBundle.device_keys.some((k) => k.ak === ak)) {
        throw new SdkError("SDK_ERR_DEVICE_EXISTS", "Derived device key already exists");
      }

      const seq = await this.store.sequence.reserveNextSeq(rootKid);
      nextBundle.seq_state[rootKid] = seq.toString();
      nextBundle.device_keys.push({ ak, label, pub_b64: pubB64 });

      grantEvent = {
        t: "DeviceKeyGrant",
        ak: rootKid,
        seq,
        payload_cid: `grant:${ak}`,
        body: { grant_ak: ak }
      };

      await this.store.identity.save(nextBundle);
      await this.store.events.append(grantEvent);
    });

    if (!grantEvent) {
      throw new SdkError("SDK_ERR_INTERNAL", "Device grant event was not created");
    }
    return { device: { ak, label, pub_b64: pubB64 }, grant_event: grantEvent };
  }

  async revokeDeviceKey(ak: string): Promise<{ revoked_ak: string; revoke_event: LedgerEvent }> {
    let revokeEvent: LedgerEvent | null = null;

    await this.store.atomic(async () => {
      const bundle = await this.requireBundle();
      const nextBundle = cloneIdentityBundle(bundle);
      const rootKid = nextBundle.root_kid;

      if (ak === rootKid) {
        throw new SdkError("SDK_ERR_REVOKE_ROOT_FORBIDDEN", "Root key cannot be revoked in v0.1");
      }
      if (!nextBundle.device_keys.some((k) => k.ak === ak)) {
        throw new SdkError("SDK_ERR_DEVICE_UNKNOWN", "Device key not found");
      }
      if (!nextBundle.revoked_aks.includes(ak)) {
        nextBundle.revoked_aks.push(ak);
        nextBundle.revoked_aks.sort();
      }

      if (nextBundle.active_ak === ak) {
        nextBundle.active_ak = rootKid;
      }

      const seq = await this.store.sequence.reserveNextSeq(rootKid);
      nextBundle.seq_state[rootKid] = seq.toString();
      revokeEvent = {
        t: "DeviceKeyRevoke",
        ak: rootKid,
        seq,
        payload_cid: `revoke:${ak}`,
        body: { revoke_ak: ak }
      };

      await this.store.identity.save(nextBundle);
      await this.store.events.append(revokeEvent);
    });

    if (!revokeEvent) {
      throw new SdkError("SDK_ERR_INTERNAL", "Device revoke event was not created");
    }
    return { revoked_ak: ak, revoke_event: revokeEvent };
  }

  async setActiveAk(ak: string): Promise<void> {
    const bundle = await this.requireBundle();
    if (!isAuthorized(bundle, ak)) {
      throw new SdkError("SDK_ERR_UNAUTHORIZED_AK", `AK is not authorized: ${ak}`);
    }
    bundle.active_ak = ak;
    await this.store.identity.save(bundle);
  }

  async exportBundle(): Promise<IdentityBundleV1> {
    return this.requireBundle();
  }

  async importBundle(bundle: IdentityBundleV1): Promise<void> {
    if (bundle.bundle_v !== 1) {
      throw new SdkError("SDK_ERR_IDENTITY_BUNDLE_VERSION", "Unsupported identity bundle version");
    }

    if (!bundle.root_kid || !bundle.root_pub_b64 || !bundle.sync_secret_b64) {
      throw new SdkError("SDK_ERR_IDENTITY_BUNDLE_INVALID", "Identity bundle missing required fields");
    }

    if (!bundle.device_keys.some((d) => d.ak === bundle.root_kid)) {
      throw new SdkError("SDK_ERR_IDENTITY_BUNDLE_INVALID", "Identity bundle missing root key in device_keys");
    }

    // Validate binary payloads early to keep fail-closed behavior deterministic.
    decodeB64(bundle.root_pub_b64);
    decodeB64(bundle.sync_secret_b64);

    const nextBundle = cloneIdentityBundle(bundle);
    await this.store.atomic(async () => {
      await this.store.sequence.importSnapshot(nextBundle.seq_state);
      await this.store.identity.save(nextBundle);
    });
  }

  async getState(): Promise<{ root_kid: string; active_ak: string; authorized_aks: string[]; revoked_aks: string[] }> {
    const bundle = await this.requireBundle();
    const authorized = bundle.device_keys.map((k) => k.ak).filter((ak) => isAuthorized(bundle, ak)).sort();
    return {
      root_kid: bundle.root_kid,
      active_ak: bundle.active_ak,
      authorized_aks: authorized,
      revoked_aks: [...bundle.revoked_aks].sort()
    };
  }

  async requireAuthorizedAk(ak?: string): Promise<string> {
    const bundle = await this.requireBundle();
    const resolved = ak ?? bundle.active_ak;
    if (!isAuthorized(bundle, resolved)) {
      throw new SdkError("SDK_ERR_UNAUTHORIZED_AK", `AK is not authorized: ${resolved}`);
    }
    return resolved;
  }

  async getRootKid(): Promise<string> {
    const bundle = await this.requireBundle();
    return bundle.root_kid;
  }

  async getSyncSecret(): Promise<Uint8Array> {
    const bundle = await this.requireBundle();
    return decodeB64(bundle.sync_secret_b64);
  }
  private async requireBundle(): Promise<IdentityBundleV1> {
    const bundle = await this.store.identity.load();
    if (!bundle) {
      throw new SdkError("SDK_ERR_IDENTITY_MISSING", "Identity root is not initialized");
    }
    return bundle;
  }
}

function deriveKid(pub: Uint8Array): string {
  return sha256Hex(pub).slice(0, 32);
}

function isAuthorized(bundle: IdentityBundleV1, ak: string): boolean {
  if (ak === bundle.root_kid) {
    return true;
  }
  if (bundle.revoked_aks.includes(ak)) {
    return false;
  }
  return bundle.device_keys.some((k) => k.ak === ak);
}

function cloneIdentityBundle(bundle: IdentityBundleV1): IdentityBundleV1 {
  return JSON.parse(JSON.stringify(bundle)) as IdentityBundleV1;
}
