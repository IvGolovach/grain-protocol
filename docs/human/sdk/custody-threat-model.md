# SDK Custody Threat Model

This page records the custody boundary for real Grain apps. It is meant to keep
phone, glasses, browser, and robot clients thin while making storage and trust
responsibilities explicit.

## Trust Boundary

Grain verifies signed payloads and returns explicit workflow results. The app
owns platform custody. That means the app chooses where secrets, snapshots,
trust bundles, exported evidence, account state, and recovery material live.

The SDK must not create hidden network trust lookup, fallback platform CA trust,
TOFU, remote account recovery, analytics upload, or implicit cloud backup. A
local trust bundle is an input chosen by the app or operator, not something the
SDK discovers by itself.

The sensitive values are:

- `snapshotB64`
- identity bundles
- sync bundles
- pairing envelopes
- trust public material and local trust bundle contents
- generated diagnostics that include record, identity, sync, or pairing data
- snapshot export files and handoff archives

The baseline rule is no secret logging. Logs can include stable error codes,
safe anchor IDs, policy names, and redacted diagnostics, but not raw secrets,
snapshots, pairing material, or exported bundles.

## Platform Custody Rules

Keychain custody is the default Apple path for durable local secrets. App code
must decide access group, biometric policy, iCloud Keychain policy, device-only
policy, and export behavior. Grain should receive adapter calls and return
workflow state, not own those platform choices.

Keystore custody is the default Android path for durable local secrets. App code
must decide alias policy, hardware-backed requirements, biometric policy, backup
exclusion, and account migration behavior.

IndexedDB custody is the practical browser/mobile-web path for snapshots and
non-hardware-backed state. App code must treat it as local browser storage, not
as hardware custody. If browser clients need stronger guarantees, they need a
separate platform-specific custody design.

Robot, kiosk, and scanner deployments may use TPM, HSM, secure enclave, MDM, or
fleet storage. Those are app or operator responsibilities. The SDK can define an
adapter contract, but it must not claim hardware custody certification unless a
separate review proves it.

Snapshot export is a portability feature, not proof of device custody. Exported
snapshots must move through an encrypted/authenticated app channel and should
carry enough metadata for the receiver to reject stale or wrong-context inputs.

Local trust bundle files are configuration inputs. They should be versioned,
reviewed, signed or checksummed by the app release process, and loaded without
network fallback.

## Misuse Cases

- App logs `snapshotB64`, identity bundles, sync bundles, pairing envelopes, or
  trust material while debugging a failed scan.
- App treats a source-only SDK handoff as a published SwiftPM, Maven, npm, App
  Store, Play Store, PWA, glasses, or robot-fleet release.
- App accepts a scan before preview because the camera or sensor adapter calls
  directly into persistence.
- App downloads trust anchors from the network when a local trust bundle is
  missing.
- App treats IndexedDB as hardware-backed custody.
- App exports snapshots through email, clipboard, analytics, crash-report, or
  unauthenticated sync channels.
- App stores all custody and trust decisions in UI code instead of a small
  platform adapter with tests.
- App lets phone, glasses, and robot clients diverge on verification semantics.

## Thin UX Guidance

Phone UX should let the user scan or paste, preview, accept, restore, list, and
export. The phone app owns Keychain or Keystore policy and should show clear
state when local trust material is missing.

Glasses UX should capture frames, show a minimal preview, and require explicit
accept or defer the decision to a paired phone. It should avoid silent accept
and should never fetch trust material as a side effect of looking at a code.

Robot UX should separate sensor ingestion from operator acceptance. It should
record which local trust bundle was used, which operator or policy accepted the
record, and which export channel moved the snapshot.

Browser UX should be honest that IndexedDB is local browser storage. It can be
good enough for demos and some apps, but stronger custody requires a separate
native or hardware-backed path.

## App Handoff Checklist

Before calling a real app ready for broader testing, answer these questions in
the app repo:

- Where are secrets stored: Keychain, Keystore, IndexedDB, TPM/HSM, or another
  app-owned adapter?
- Is snapshot export encrypted/authenticated by an app channel?
- Is the local trust bundle pinned, versioned, and loaded without network
  fallback?
- Can a missing, malformed, revoked, or wrong anchor fail closed?
- Do logs and crash reports preserve the no secret logging rule?
- Does the app preview before accept?
- Can the app restore snapshots on launch without re-verifying from a hidden
  network source?
- Are phone, glasses, browser, and robot clients using the same SDK workflow
  contract rather than separate protocol implementations?
