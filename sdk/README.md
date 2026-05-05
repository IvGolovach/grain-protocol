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
