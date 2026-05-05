# SDK Workflow Fixtures

`sdk/workflows/**` is the client workflow conformance layer for generated SDKs.

Protocol conformance answers whether Grain bytes, diagnostics, and runner outputs obey the frozen protocol contract. Client workflow conformance answers whether every generated SDK exposes the same safe app workflow over that protocol.

The first workflow is `scan_preview`:

- decode a GR1 scan string;
- optionally verify it against explicit trust material;
- return `Verified`, `Untrusted`, or `Rejected`;
- never mutate local client storage.

Fixtures live under `sdk/workflows/fixtures/<workflow>/`. They may reference protocol vectors with JSON pointers, but they are not protocol vectors themselves and must not be consumed by the protocol runner.
