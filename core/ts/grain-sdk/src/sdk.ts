import { CanonicalizationToolkit } from "./codec.ts";
import { TsCoreEngine } from "./engine.ts";
import { E2ePrimitives } from "./e2e.ts";
import { EvidenceBuilder } from "./evidence.ts";
import { EventLifecycle } from "./events.ts";
import { IdentityManager } from "./identity.ts";
import { InMemorySdkStore } from "./memory-store.ts";
import { ManifestManager } from "./manifest.ts";
import type { GrainSdkStore } from "./store.ts";
import { TransportToolkit } from "./transport.ts";

export class GrainSdk {
  public readonly core: TsCoreEngine;
  public readonly codec: CanonicalizationToolkit;
  public readonly identity: IdentityManager;
  public readonly events: EventLifecycle;
  public readonly manifest: ManifestManager;
  public readonly e2e: E2ePrimitives;
  public readonly transport: TransportToolkit;
  public readonly evidence: EvidenceBuilder;
  public readonly store: GrainSdkStore;

  constructor(store: GrainSdkStore = new InMemorySdkStore()) {
    this.store = store;
    this.core = new TsCoreEngine();
    this.codec = new CanonicalizationToolkit(this.core);
    this.identity = new IdentityManager(this.store);
    this.manifest = new ManifestManager(this.store, this.identity, this.core);
    this.events = new EventLifecycle(this.store, this.identity, this.core);
    this.e2e = new E2ePrimitives(this.store, this.identity, this.manifest, this.core);
    this.transport = new TransportToolkit(this.core);
    this.evidence = new EvidenceBuilder(this.store);
  }
}
