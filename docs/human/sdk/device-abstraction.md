# Device Abstraction

Grain apps should stay thin. The device layer adapts local platform facts into
the same SDK workflow instead of reimplementing protocol work.

The contract lives under `sdk/device`. It names the edges each platform app must
own and the behavior the SDK keeps out of the app shell.

## App-Owned Edges

- scan input: camera, paste, NFC, glasses frame, robot sensor, or browser input
  returns a `GR1:` string
- capabilities: the app reports which local features exist, such as camera,
  secure storage, export channel, and diagnostics sink
- secure local store: the app persists opaque `snapshotB64` bytes and restores
  them on launch
- export sink: the app moves identity, pairing, sync, or accepted-scan exports
  only through its own authenticated channel
- diagnostic sink: the app records statuses, counts, scan IDs, anchor IDs, and
  diagnostic codes
- trust provider: the app resolves a stable local trust anchor ID to explicit
  public trust material

## SDK-Owned Work

- `GR1:` parsing and validation
- COSE and DAG-CBOR protocol verification
- trust verification once explicit trust material is supplied
- preview statuses and canonical diagnostics
- accept/idempotency and rollback semantics
- snapshot import/export format
- identity, device lifecycle, pairing, and sync workflows

## Hard Boundaries

The device abstraction must not add:

- account requirements
- hidden network trust discovery
- fallback trust
- TestFlight, App Store, Play Console, npm, or Maven publication assumptions
- registry credentials
- raw protocol runner calls in app code
- secret logging

If a platform cannot provide a capability, it should report that explicitly.
The SDK should fail closed rather than fetching trust, guessing storage policy,
or silently accepting a record.

## Local Proof

Run the local reference app and SDK checks:

```bash
scripts/sdk/run_local_scanner_flow.sh --strict
python3 tools/ci/check_device_adapter_contract.py
scripts/sdk/check_ios_reference_app.sh
scripts/sdk/check_android_reference_app.sh
scripts/sdk/verify_all_sdks.sh --strict --out-dir artifacts/sdk-verify-local-reference
```

Those checks prove the contract shape and source-level app behavior. They do
not certify hardware secure elements, production account policy, fleet rollout,
or store distribution.
