# Grain Device Adapter Contract

`device_adapter_v1.schema.json` defines the thin platform edge between Grain and local reference apps for iPhone, Android, glasses, robot, browser, and similar devices.

The contract names six edges:

- `ScanInput`: camera QR, manual paste, or local handoff input passed into the public SDK.
- `DeviceCapabilities`: required local capabilities for a certifiable adapter.
- `SecureLocalStore`: adapter-owned local persistence for SDK state.
- `ExportSink`: safe export/debug output with counts and redacted summaries only.
- `DiagnosticSink`: safe diagnostic event delivery.
- `TrustProvider`: local trust anchors injected into the SDK.

The boundary is intentionally local. Grain owns trust verification, accept/idempotency, diagnostics, snapshot format, and export semantics. Device apps own platform input, local persistence, and display state.

Adapters must enforce no accounts, no network trust discovery, no platform-store packaging, no publication credentials, and no secret exports. In practice this means no App Store, TestFlight, Play Console, registry, hosted account, fallback trust lookup, raw snapshot, trust key, token, seed, or credential field can be part of the adapter contract.
