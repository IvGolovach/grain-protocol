# SDK Workflow Fixtures

`sdk/workflows/**` is the client workflow conformance layer for generated SDKs.

Protocol conformance answers whether Grain bytes, diagnostics, and runner outputs obey the frozen protocol contract. Client workflow conformance answers whether every generated SDK exposes the same safe app workflow over that protocol.

The first workflow is `scan_preview`:

- decode a GR1 scan string;
- optionally verify it against explicit trust material;
- return `Verified`, `Untrusted`, or `Rejected`;
- never mutate local client storage.

The second workflow is `scan_accept`:

- decode and verify a GR1 scan string against explicit trust material;
- atomically persist a verified accepted scan record;
- return `Accepted`, `AlreadyAccepted`, or `Rejected`;
- prove duplicate-scan idempotency by repeating the public accept workflow in fixtures;
- never persist rejected scans.

Trust-provider fixtures add `trust_anchor_id` to prove that platform wrappers
can resolve app trust through explicit anchor IDs and fail closed when no anchor
material exists. They must not use hidden fallback trust or network lookup.

The lifecycle workflows are:

- `device_lifecycle`: create a portable identity, add a device key, activate it, revoke it, and report lifecycle counts;
- `pairing`: create an app-transferred pairing envelope, preview it, accept it, and prove replay idempotency;
- `sync_bundle`: export identity, accepted scans, and lifecycle events, import them into another client, and prove repeated import idempotency.

The platform persistence bridge is `store_snapshot`: export an opaque
`snapshotB64` string from one client, persist it in platform storage, and
restore it into a fresh client without exposing raw store mutation APIs.

Fixtures live under `sdk/workflows/fixtures/<workflow>/`. They may reference protocol vectors with JSON pointers, but they are not protocol vectors themselves and must not be consumed by the protocol runner.
