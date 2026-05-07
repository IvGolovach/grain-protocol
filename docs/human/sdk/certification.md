# SDK Certification

Certification is a local source validation report for an external Grain client.
It proves that the client is using the reviewed SDK surfaces and that the local
reference paths still pass. It is not a store, registry, or hardware custody
certificate.

## Run It

From the repo root:

```bash
CLIENT_NAME=grain-local-reference-apps \
CLIENT_OWNER=grain-maintainers \
OUT_DIR=artifacts/external-client-certification-local-reference \
scripts/sdk/certify_external_client.sh
```

The script writes a JSON report and validates it with
`tools/ci/check_external_client_certification.py`.

## What The Report Covers

- client workflow fixtures
- public SDK API compatibility
- no network trust discovery in SDK paths
- explicit trust-provider boundary
- no secret logging policy
- starter template smoke
- iOS reference app source check
- Android reference app source check
- device adapter contract
- safe diagnostic telemetry policy
- trust governance policy
- local source artifacts and dry-run boundaries

## What It Does Not Cover

- TestFlight
- App Store
- Play Console
- npm publish
- Maven Central publish
- paid Apple Developer Program distribution
- production signing-key custody
- hardware secure-element certification
- device farm or camera automation proof
- hosted trust registry operation

Those are separate release or platform-integration programs.

## CI Role

`scripts/sdk/verify_all_sdks.sh --strict` runs the same local reference app,
device contract, dry-run, and certification path on the SDK platform runner.
PR validation must not require store credentials or registry secrets.
