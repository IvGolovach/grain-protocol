# ADR 0006: Food Wallet App Contract

Status: Accepted

Date: 2026-05-17

## Context

The Food Profile pilot proves that Grain can reduce food intake events, but app
teams still need a small product-shaped contract before building full iOS or
Android clients. Without that contract, future apps would either reimplement
protocol details in UI code or treat photos, AI estimates, QR offers, trust
labels, and safe exports as unrelated local conventions.

The first app should be useful to a normal person who tracks food, while still
demonstrating the protocol value: verified serving offers, self-issued/manual
records, estimated photo-derived drafts, explicit untrusted states, and safe
summaries that do not leak raw photos or protocol material.

## Decision

1. Add `sdk/food/contract/food_wallet_v1.schema.json` as an app-facing Food
   Wallet contract. This is an SDK/domain contract, not a protocol change.
2. Keep the trust vocabulary explicit:
   - `verified`
   - `self_issued`
   - `estimated`
   - `untrusted`
3. Keep the source class vocabulary reducer-friendly:
   - `attested`
   - `measured`
   - `estimated`
4. Require a draft/confirmation boundary before app-facing food estimates become
   appendable intake events.
5. Treat raw photos as transient app/provider input. Grain SDK helpers and safe
   reports must not persist raw photo bytes, base64 photos, raw QR payloads,
   trust material, snapshots, identity bundles, sync bundles, COSE payloads, or
   private keys.
6. Keep AI/model support as a replaceable sidecar adapter. The sidecar may
   produce estimates and advice, but it must not write the ledger directly.
7. Add Swift and Kotlin Food Wallet facades plus starter templates that are thin
   app-development helpers, not store publication packages or backend/account
   systems.
8. Add repo-native checks for contract drift, local pilot reports, Swift/Kotlin
   smoke coverage, starter templates, source package cleanliness, and full SDK
   verification composition.

## Consequences

- App developers can start from meal estimates, drafts, confirmations, safe
  summaries, and trust labels instead of QR/COSE/DAG-CBOR internals.
- Food Wallet remains local-first and source-level. It does not certify App
  Store, Play Store, backend, account, privacy policy, or model-provider
  readiness.
- No frozen protocol semantics, CDDL, NES text, or protocol conformance vectors
  are changed.
- The SDK contract adds new source files and checks, but same-SHA source release
  packaging remains the current distribution model.

## Invariants touched

- `SDK-INV-0032` (Food Wallet app contract and no-raw-photo boundary)
- `SDK-AI-008` (Food photo/advice adapter remains read-only and transient)

## Compatibility

This is non-breaking for the frozen protocol. It adds optional SDK/domain
surfaces and same-SHA source artifacts.
