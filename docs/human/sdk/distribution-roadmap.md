# SDK Distribution Roadmap

This page defines what Grain can honestly ship to app developers now, what
registry distribution should look like later, and where thin app UX layers fit.
It is developer guidance, not a release announcement.

## Current Channel: Source-Only Handoff

The current supported channel is source-only. A consumer receives same-SHA
source archives, manifest metadata, checksums, SBOM data, workflow fixtures,
generated binding snapshots, and local trust-bundle inputs from one commit or
release tag.

This is the right channel until registry packaging has its own release policy
and automated proof. It keeps the app team on reviewed source while avoiding
claims that Grain is already published through mobile stores or package
registries.

The source-only packet must include:

- exact commit or release tag
- SDK source archive location
- `manifest.json`, `SHA256SUMS`, and `sbom.spdx.json`
- strict SDK proof or a recorded upstream strict SDK gate
- generated Swift/Kotlin binding snapshot
- Swift, Kotlin, WASM, workflow, and trust-bundle source archives
- known local prerequisites and residual gaps

Do not mix archives from different commits. The SHA in the archive names must
match the commit recorded in the manifest.

## Future Registry Channels

SwiftPM, Maven, and npm are future distribution channels. They should be added
only after the source handoff is boring, repeatable, and guarded by the same
verification posture as the repo itself.

SwiftPM should publish a tagged source package that wraps the generated Swift
client API and platform adapters. It should not expose raw protocol semantics
as the normal app path.

Maven should publish Kotlin/JVM and Android-facing artifacts with the same
client workflow contract, deterministic trust-bundle loading, and no hidden
network trust discovery.

npm should publish the web/WASM lane for browser and mobile-web clients. It
must keep IndexedDB and browser export policy as app-owned custody boundaries,
not as silent SDK defaults.

Before any registry channel is called supported, it needs:

- signed or otherwise auditable release provenance
- same-SHA source and generated binding proof
- registry-package integrity checks
- rollback instructions
- docs that say exactly which runtime and storage adapters are included
- negative language for channels that are still not published

## Not Yet Published

Do not claim production distribution through Swift Package Index, Maven Central,
npm, CocoaPods, App Store, Play Store, PWA install channels, robot fleets,
glasses stores, or hardware vendor programs until those channels exist and have
their own release evidence.

The current release assets prove source custody and reproducible handoff. They
do not prove store review, platform certification, hosted update policy, device
fleet rollout, or hardware secure-element claims.

## Thin UX Layers

Future app work should stay thin. The phone, glasses, and robot surfaces should
adapt sensors, local storage, trust inputs, and user decisions into the shared
Grain workflow instead of reimplementing parsing, verification, identity, sync,
or protocol semantics.

Phone UX should focus on scan or paste, preview, accept, list, export, restore,
and clear error recovery. Camera, local notification, share sheet, backup, and
account-linking choices belong to the app shell.

Glasses UX should focus on frame capture, glanceable preview, explicit accept
or dismiss, and deferred detail review on a paired phone. The glasses layer
should not silently accept records or fetch trust material from the network.

Robot UX should focus on sensor ingestion, operator review, local trust-bundle
selection, auditable accept decisions, and durable export through an
operator-approved channel. A robot adapter can hold custody hardware, but Grain
should still receive explicit trust inputs and return explicit workflow results.

The stable app contract remains:

1. scan or ingest `GR1:`
2. resolve a local trust anchor
3. preview
4. accept
5. persist the returned snapshot
6. restore on launch
7. export only through an app-owned channel

## Developer Rules

- Start from source-only handoff until a registry channel has release evidence.
- Treat Grain SDKs as workflow APIs, not raw protocol toolkits for app code.
- Keep app shells responsible for sensors, UI state, platform storage, user
  consent, network policy, and account policy.
- Keep protocol semantics, verification, diagnostics, pairing, sync, and
  snapshot mutation in the shared SDK/core layer.
- Document every distribution claim next to the evidence that proves it.
