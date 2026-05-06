# Generated SDK Bindings

This directory documents the generated binding lane. Generated Swift, Kotlin,
and future platform sources are produced by:

```bash
scripts/sdk/generate_client_bindings.sh --out-dir artifacts/sdk/generated-bindings
```

The repository does not commit generated binding output from this harness. The
check path generates into a temporary directory and verifies that no tracked or
untracked repository files are changed:

```bash
scripts/sdk/check_generated_bindings.sh
```

Platform packages should wrap the generated workflow API instead of exposing raw
protocol runner operations to app developers. The WASM/mobile-web lane uses a
separate `grain-client-wasm` workflow export over the same Rust client core.

## Release Handoff

SDK release packages include `grain-generated-bindings-<sha>.tar.gz` as a
same-SHA generated binding snapshot. That snapshot is for audit, reproduction,
and future wrapper development. It is not the normal app API.

App developers should consume `grain-swift-client-<sha>.tar.gz`,
`grain-kotlin-client-<sha>.tar.gz`, or `grain-wasm-client-<sha>.tar.gz` from
the same package directory and keep them paired with the matching
`grain-client-core` commit in `manifest.json`.

For the full handoff checklist, see
`docs/human/sdk/source-sdk-handoff.md`.
