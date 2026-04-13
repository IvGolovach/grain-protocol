import { createGrainSdkAiHost, type GrainSdkAiHost } from "./ai-host.js";
import { CanonicalizationToolkit } from "./codec.js";
import { TsCoreEngine } from "./engine.js";
import { E2ePrimitives } from "./e2e.js";
import { EvidenceBuilder } from "./evidence.js";
import { EventLifecycle } from "./events.js";
import { IdentityManager } from "./identity.js";
import { InMemorySdkStore } from "./memory-store.js";
import { ManifestManager } from "./manifest.js";
import type { GrainSdkStore } from "./store.js";
import { TransportToolkit } from "./transport.js";

export class GrainSdk {
  readonly #store: GrainSdkStore;
  public readonly core: TsCoreEngine;
  public readonly codec: CanonicalizationToolkit;
  public readonly identity: IdentityManager;
  public readonly events: EventLifecycle;
  public readonly manifest: ManifestManager;
  public readonly e2e: E2ePrimitives;
  public readonly transport: TransportToolkit;
  public readonly evidence: EvidenceBuilder;

  constructor(store: GrainSdkStore = new InMemorySdkStore()) {
    this.#store = store;
    this.core = new TsCoreEngine();
    this.codec = new CanonicalizationToolkit(this.core);
    this.identity = new IdentityManager(this.#store);
    this.manifest = new ManifestManager(this.#store, this.identity, this.core);
    this.events = new EventLifecycle(this.#store, this.identity, this.core);
    this.e2e = new E2ePrimitives(this.#store, this.identity, this.manifest, this.core);
    this.transport = new TransportToolkit(this.core);
    this.evidence = new EvidenceBuilder(this.#store);
  }

  createAiHost(): GrainSdkAiHost {
    return createGrainSdkAiHost(this.core, this.#store);
  }
}
