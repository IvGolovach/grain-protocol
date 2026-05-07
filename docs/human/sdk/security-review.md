# SDK Security Review

Use this checklist before a Grain SDK source handoff becomes a broader app,
registry, store, hardware, or fleet claim.

## Review Scope

Review these risks for each app shell:

- Replay of an old QR, pairing envelope, sync bundle, snapshot, or evidence
  export.
- trust injection through a missing, swapped, malformed, or network-fetched
  local trust bundle.
- snapshot leakage through logs, crash reports, email, clipboard, backups,
  analytics, or unauthenticated sync.
- pairing misuse where a paired device can accept or export without the app's
  intended user or operator policy.
- unsafe logs that include portable secrets instead of stable error codes,
  safe anchor IDs, policy names, and redacted diagnostics.
- Backup leakage through iCloud, Android backup, browser profile sync, MDM,
  fleet backup, or robot storage.
- app-shell divergence between phone, glasses, browser, robot, and kiosk
  clients.

## Required Evidence

Record this evidence before promotion:

- The exact Grain commit or release tag.
- Client workflow fixture proof for preview, accept, pairing, sync, and
  snapshot restore paths.
- No-network trust-provider proof for local trust bundle loading.
- no secret telemetry proof for logs, diagnostics, examples, and schemas.
- custody adapter decision for Keychain, Keystore, IndexedDB, TPM, HSM,
  MDM, or another app-owned custody path.
- release evidence for any registry, store, hardware custody, or robot fleet
  claim.

Until that evidence exists, describe the app as using a source-only SDK handoff.
