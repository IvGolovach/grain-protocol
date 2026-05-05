# Grain SDK

The production SDK code lives in `core/ts/grain-sdk`.
The optional AI sidecar lives in `core/ts/grain-sdk-ai`.
This top-level `sdk/` path also holds cross-platform client workflow contracts,
generated-binding lane documentation, and platform package wrappers.

SDK is an adoption layer:
- developer-friendly API
- safe defaults
- still MUST pass conformance suite for protocol-critical behavior

Primary implementation:
- `core/ts/grain-sdk`
- `core/ts/grain-sdk-ai`

Portable client SDK lanes:
- `sdk/workflows`: app-facing scan workflow contracts and fixtures
- `sdk/generated`: documentation for generated Swift/Kotlin binding output and the WASM workflow export boundary
- `sdk/swift`: Swift Package Manager wrapper over generated client workflow bindings
- `sdk/kotlin`: Kotlin/JVM wrapper over generated client workflow bindings
- `sdk/wasm`: WASM/mobile-web wrapper over generated client workflow bindings

Reference scanner shells live under `examples/`. They show paste-first iOS,
Android/Kotlin, and browser/mobile-web clients that call the public workflow
SDKs and keep camera or sensor adapters outside protocol-critical logic.

## Compatibility

Use the matrix in `docs/human/sdk/version-matrix.md` before mixing generated
bindings, wrappers, and Rust crates from different commits or release tags.
The short rule is: ship Swift, Kotlin, WASM, and `grain-client-core` from the
same repo SHA unless the matrix explicitly says a cross-version pairing is
compatible.

Generated SDKs are client-workflow conformant only after they pass
`sdk/workflows/**` through their public wrapper APIs. Passing protocol vectors
alone is not enough.

## Verify all SDK lanes

```bash
scripts/sdk/verify_all_sdks.sh
```

For release-grade local proof, require every platform prerequisite:

```bash
scripts/sdk/verify_all_sdks.sh --strict
```

The strict path expects Swift 6, Java/Kotlin tooling, Node/npm, Cargo, and the
`wasm32-wasip1` Rust target to be available. GitHub CI installs the WASM target
for the required `wasm-smoke` and `sdk-platform` lanes.

Set `SDK_KOTLIN_GRADLE_OFFLINE=1` only after warming Gradle caches when you need
the Kotlin and scanner-example checks to prove offline dependency resolution.

## Package SDK artifacts

```bash
scripts/sdk/package_client_sdks.sh
```

Artifacts are written under `artifacts/sdk-release/<commit>/`, which is ignored
by git. The script packages source SDKs, generated binding snapshots, workflow
fixtures, a manifest, and `SHA256SUMS`. Build caches and local package-manager
directories are excluded from the archives. By default it refuses a dirty
working tree and runs strict SDK verification before packaging.

## Workflow shape

Every platform wrapper exposes the same product-level operations:

- prepare local identity and device lifecycle with `createRootIdentity`,
  `addDeviceKey`, `setActiveDevice`, `revokeDeviceKey`, and `clientLifecycle`
- preview a scan with explicit app-supplied trust material using `scanPreview`
- accept and save verified scans using `scanAccept`
- preview or accept through explicit trust anchor IDs using the platform
  trust-provider overloads
- list saved accepted scans using `listAcceptedScans`
- export portable evidence/state with `exportSyncBundle`
- pair/sync clients with `createPairingEnvelope`, `acceptPairingEnvelope`, and
  `importSyncBundle`
- persist client runtime state with `exportStoreSnapshot` and
  `restoreStoreSnapshot`

Trust setup is intentionally outside the protocol core. Production apps should
pass a `trustAnchorID` plus a platform `TrustProvider`; the wrapper resolves
that anchor to `trustPubB64` and fails closed with `SDK_ERR_TRUST_ANCHOR_*`
when the anchor is missing. Rust core and generated wrappers do not perform
hidden trust lookup, network discovery, or fallback trust. Raw `trustPubB64`
methods remain available for fixtures and already-resolved trust material.

Store snapshots are opaque SDK state, not a raw mutation API. Apps should save
the returned `snapshotB64` string in their platform storage layer and restore it
into a fresh client on launch. Snapshot payloads can include identity material,
so production adapters should place them behind the platform security boundary
appropriate for the device.
