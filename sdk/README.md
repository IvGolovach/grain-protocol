# Grain SDK

The production SDK code lives in `core/ts/grain-sdk`.
The optional AI sidecar lives in `core/ts/grain-sdk-ai`.
This top-level `sdk/` path also holds cross-platform client workflow contracts
and generated-binding lane documentation.

SDK is an adoption layer:
- developer-friendly API
- safe defaults
- still MUST pass conformance suite for protocol-critical behavior

Primary implementation:
- `core/ts/grain-sdk`
- `core/ts/grain-sdk-ai`

Portable client SDK lanes:
- `sdk/workflows`: app-facing scan workflow contracts and fixtures
- `sdk/generated`: documentation for generated Swift/Kotlin binding output
