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

Food Graph follows the same AI boundary: deterministic SDK plumbing only, no
hosted-model runtime. Graph suggestions are advisory annotations. They must be
derived from already-confirmed app data or transient adapter input, and they
must not persist raw photos, embeddings, vectors, model artifacts, or network
provider payloads.

## Recommended policy

- keep sensitive blobs outside candidate payload whenever possible
- pass references/hashes instead of raw plaintext
- log only deterministic diagnostics (`code`, `category`, refs)
