# Overview

Grain is infrastructure for **verifiable physical events**.
Food is the first production profile in v0.1.

## The shortest mental model

1. A domain object is serialized into canonical bytes.
2. Those bytes get a stable content ID (`CID`).
3. Signed events reference those CIDs in an append-only ledger.
4. Independent implementations must produce the same verdict and output for the same valid input.
5. Private sync uses capability addressing plus manifest resolution, not a central truth server.

The core rules are general-purpose. The shipped schema profile is food-first.

## What lives where

- `spec/*`: normative rules and machine-readable schemas.
- `conformance/*`: executable release gate; vectors are the interoperability court.
- `core/rust/*`: reference executor.
- `runner/typescript/*`: independent strict implementation used for drift detection.
- `core/ts/grain-sdk/*`: safer app-facing orchestration layer.

## What Grain gives you

- Stable bytes for objects and signatures.
- Content IDs for objects that need to be shared or verified later.
- Signed events in an append-only ledger.
- Private sync with capability addressing and manifest resolution.
- Offline QR transport through `GR1:`.
- Byte-level conformance evidence from strict vectors.

## Important terms

- `strict mode`: fail-closed execution path used for conformance and release verification.
- `CID`: content ID derived from canonical bytes.
- `ledger`: signed append-only event set reduced deterministically.
- `manifest`: private lookup structure for capability-addressed ciphertext.
- `C01`: small TypeScript smoke profile for byte-path regressions; the full strict suite is still the compatibility bar.

## What Grain does not provide

- a global registry as canonical truth
- truth guarantees
- a platform, social graph, or central DB

## Where to go next

- New to the repo: `docs/human/start-here.md`
- Want one first success: `docs/human/quickstart.md`
- Building an app: `docs/human/sdk/start-here.md`
- Running verification and evidence flows: `docs/human/portability-pack.md`
- Want the system map: `docs/human/architecture.md`
- Want the longer product direction: `docs/human/future-vision.md`
- Want the explicit scope boundary: `spec/SCOPE-v0.1.md`
