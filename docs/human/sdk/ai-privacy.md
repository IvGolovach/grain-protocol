# SDK AI Privacy Boundary

SDK AI boundary is local deterministic plumbing, not a model runtime.

## Defaults

- no outbound network calls from SDK core
- no vendor-specific model client in SDK core
- no automatic telemetry
- redacted explain payloads by default

## Integrator responsibility

If your application sends data to external models, that is outside SDK core.
Use explicit adapter code in application layer and pass only what is required.

## Recommended policy

- keep sensitive blobs outside candidate payload whenever possible
- pass references/hashes instead of raw plaintext
- log only deterministic diagnostics (`code`, `category`, refs)
