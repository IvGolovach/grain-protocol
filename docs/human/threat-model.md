# Threat Model (short)

Grain assumes hostile inputs and hostile networks.

## Attackers we assume
- malicious issuers producing misleading signed content
- spoofed / fake QR codes
- replay of old valid artifacts
- server-side observer for sync (honest-but-curious or malicious)
- network attacker (MITM) on transport channels
- compromised device key (attacker can sign as that device)

## Attackers we do not assume
- broken cryptography primitives (handled as future “crypto break” events)
- perfect endpoint security (compromised devices are in-scope, but cannot be fully prevented)

## What Grain protects
- integrity (bytes not modified)
- authorship (who signed)
- deterministic merge semantics (no arrival-order ambiguity)
- privacy from servers via E2E + capability addressing (when cap_id is random)

## What Grain does not protect
- truthfulness of content (a signature can be a lie)
- availability (DoS is mitigated with strict limits but not eliminated)
- compromised root key (recovery requires new ledger genesis in v0.1)
