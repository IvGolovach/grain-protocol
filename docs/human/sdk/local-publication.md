# Local Publication Dry-Runs

Grain can prove local packaging behavior without publishing anything.

Use this path when you want source artifacts, metadata, checksums, and dry-run
results for app developers, but you do not have registry or app-store release
accounts in scope.

## What This Produces

- same-SHA source archives
- `manifest.json`
- `SHA256SUMS`
- `sbom.spdx.json`
- generated binding snapshots
- Swift, Kotlin, WASM, workflow, trust, custody, device, starter-template, and
  reference-example source inputs
- registry dry-run metadata

It does not publish to Swift Package Index, npm, Maven Central, TestFlight, App
Store, Play Console, or any private registry.

## Commands

From a prepared checkout:

```bash
scripts/sdk/verify_all_sdks.sh --strict --out-dir artifacts/sdk-verify-local-reference
scripts/sdk/package_client_sdks.sh --out-dir artifacts/sdk-release-local-reference
scripts/sdk/check_registry_dry_runs.sh --out-dir artifacts/sdk-registry-dry-runs-local-reference
```

The registry dry-run command records SwiftPM package description, Maven local
dry-run, and npm pack dry-run metadata when the local tools are available. The
metadata must say credentials are not required and publication did not happen.

## When CI Has Already Proved Strict SDKs

CI may package with:

```bash
scripts/sdk/package_client_sdks.sh \
  --skip-verify \
  --verified-by sdk-platform \
  --out-dir artifacts/sdk-release
```

That is still source packaging. The manifest must record the upstream strict SDK
gate. It is not a registry publish.

## What To Tell A Consumer

Give the consumer one commit or release tag and the matching source packet.
They should not mix Swift, Kotlin, WASM, generated bindings, workflow contracts,
device contracts, starter templates, or reference examples from different
commits.

Real registry publication is later work. It needs separate release policy,
credentials, rollback instructions, and evidence for each channel.
