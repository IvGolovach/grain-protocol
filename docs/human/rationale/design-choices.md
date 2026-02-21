# Design choices (rationale)

This document is explanatory (non-normative). Normative rules are in `spec/NES-v0.1.md`.

## Why strict DAG-CBOR
- deterministic canonical bytes enable byte-level interoperability and stable content IDs
- reject non-canonical prevents malleability

## Why CIDv1 + sha2-256
- broad ecosystem support
- stable multiformat framing
- minimal algorithm matrix in v0.1

## Why narrow COSE profile (Ed25519 only)
- fewer interop footguns
- deterministic verification behavior across languages

## Why root-only grant/revoke
- avoids delegated authority conflicts in v0.1
- simplifies deterministic authorization rules

## Why retroactive revoke
- avoids dependence on trusted time / wall-clock ordering
- authorization becomes order-independent set semantics

## Why deterministic nonce
- avoids catastrophic AEAD nonce reuse
- crash-safe, stateless across Rust/TS/Swift

## Why cap_id must be random
- deterministic cap_id enables correlation and breaks privacy-by-default

## Why GR1 prefix is fixed
- physical world artifacts require stable identifiers
- incompatible transports must use new prefixes

