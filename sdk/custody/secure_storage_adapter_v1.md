# Secure Storage Adapter v1

This contract is the app-owned custody boundary for Grain clients. The SDK can
call an adapter, but it does not choose the platform policy, backup policy, or
hardware claim.

## Required Operations

Adapters expose these operations:

```text
put(key, bytes, policy) -> stored | rejected
get(key) -> bytes | missing | rejected
delete(key) -> deleted | missing | rejected
list(prefix) -> key metadata
export(key, channel) -> bytes | rejected
import(key, bytes, channel) -> stored | rejected
```

Every result must be explicit. Missing storage, malformed state, wrong policy,
or unavailable hardware fails closed. Adapters must not silently fall back to
cloud backup, network recovery, platform CA trust, TOFU, analytics upload, or
plain local files.

## Platform Notes

Keychain adapters own access group, biometric gate, device-only policy, iCloud
Keychain policy, and export behavior.

Keystore adapters own alias policy, hardware-backed requirement, biometric gate,
backup exclusion, and account migration behavior.

IndexedDB adapters are local browser storage. They can hold snapshots and demo
state, but they must not claim hardware-backed custody.

Robot, TPM, HSM, secure enclave, MDM, kiosk, or fleet adapters are operator
policy. A hardware custody claim requires separate release evidence and review.

## Logging

Adapter logs may include stable error codes, redacted policy names, safe anchor
IDs, and operation names. They must not include portable snapshots, identity
bundles, pairing envelopes, sync bundles, COSE payloads, trust public material,
or raw storage bytes.
