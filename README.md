# Grain Protocol

Portable, verifiable records for real-world events.

Grain is a protocol and a conformance suite. A Grain record is an event signed
with Ed25519, encoded as canonical DAG-CBOR and addressed by its content hash.
Anyone holding the author's public key can check two things offline: who wrote
the record, and that not one byte changed afterwards. Food is the first
production profile in v0.1. Other domains add their own event types without
touching the core.

Grain is not an app, a hosted platform or a global registry.

## What Grain guarantees, and what it does not

Guarantees:
- one canonical byte encoding per protocol object, and one CID for it
- offline verification through CID + COSE_Sign1 (Ed25519 only)
- deterministic ledger rules: root-only grants, retroactive revoke, conflict ignore-all
- private sync through E2E-encrypted, capability-addressed objects
- a strict conformance suite that any implementation can run

Does not guarantee:
- that a record's content is true; a signature proves authorship, not facts
- that any server or vendor is the source of truth
- interoperability outside Strict Conformance Mode

## Status

| Area | State |
| --- | --- |
| Protocol v0.1 (`spec/`) | Frozen core. Additive changes only, each with an ADR and vectors |
| Conformance suite (`conformance/`) | 212 strict vectors; the release gate |
| Implementations | Rust (`core/rust`) and TypeScript (`core/ts/grain-ts-core`) pass all vectors with zero divergence. Both have the same author, so the strong interoperability claim in `spec/INTEROP-CLAIM.md` is **not** made |
| Signed records | TypeScript [Signed Ledger](docs/human/sdk/signed-ledger.md) for any event type (Node). Rust + Swift [Signed Food Ledger](docs/human/sdk/signed-food-ledger.md) for iOS food entries. Kotlin and WASM cannot sign yet |
| Reducer model (`GrainSdk`, generated Swift/Kotlin/WASM workflows) | Unsigned. Models authorization, sync and storage state with placeholder keys. Not evidence |
| Scanner reference apps, issuer kit, starter templates | Local reference code for development, not products |
| Distribution | Source only. No npm, SwiftPM or Maven packages are published. The Swift package links the Rust core through `unsafeFlags`, which SwiftPM restricts for remote dependencies |
| Releases | Latest tag `repo-v0.4.4` (May 2026). `main` is ahead of it |
| Maintainers | One (@IvGolovach). No protocol stewards are appointed; see `GOVERNANCE.md` |

## Try it

```bash
./scripts/bootstrap   # pinned toolchains via mise
./scripts/demo        # one-command demo
./scripts/verify      # full developer verification
```

Sign and verify a record in Node:

```ts
import { ed25519SignerFromSeed, InMemorySignedLedgerStore, SignedLedgerWriter, verifySignedLedgerTransfer } from "grain-sdk-ts";

const root = ed25519SignerFromSeed(rootSeed); // your key custody supplies the seed
const ledger = await SignedLedgerWriter.open({ trustedRootPublicKey: root.publicKey, store: new InMemorySignedLedgerStore() });
await ledger.initialize(root);
await ledger.append(root, { operationId: "note-1", t: "FieldNote", body: { text: "fence repaired", observed_at_ms: Date.now() } });

const result = verifySignedLedgerTransfer(await ledger.exportTransfer(), rootPublicKeyBase64);
```

## Where to go next

- New here: `docs/human/start-here.md`, then `docs/human/quickstart.md`
- Build an app: `docs/human/sdk/start-here.md` (which path signs, which only models state)
- Implement Grain in another language: `docs/human/implementing-grain.md`, `conformance/SPEC.md`, `conformance/contract/runner_v1.md`
- Understand the design: `docs/human/design-in-one-page.md`, `docs/human/threat-model.md`
- Maintain the repo: `docs/human/maintainer-start-here.md`, `CONTRIBUTING.md`
- Release-grade verification: `./scripts/certify`, `docs/human/portability-pack.md`
- Public protocol vs private products: `COMMERCIAL_BOUNDARY.md`
- Where this could go: `docs/human/future-vision.md` (direction, not commitments)

## If docs disagree

1. `spec/NES-v0.1.md` (normative MUST/SHOULD/MAY)
2. `spec/schemas/grain-v0.1.cddl` (machine-readable schemas)
3. `conformance/vectors/` (conformance criterion; release gate)
4. `spec/profiles/` (CBOR/COSE/E2E/QR and domain profiles)
5. `spec/FREEZE-v0.1.md`, `spec/FREEZE-CONFIRMATION-v0.1.md`, `spec/SCOPE-v0.1.md`, `spec/INTEROP-v0.1.md`, `spec/RC-POLICY.md`, `spec/INTEROP-CLAIM.md`, `spec/rc/**`
6. `docs/llm/`
7. `adr/`
8. `core/rust/`, `core/ts/grain-ts-core/`, `runner/typescript/`, `core/` and `sdk/`

A pull request that changes core protocol rules needs an ADR
(`adr/0000-template.md`). Such changes are usually breaking.

## Verification details

If you generate evidence, use the exact Node version pinned in `.nvmrc`.
Evidence records `node -v`, so a floating `22.x` changes `inputs-hashes.json`
and the final evidence hash. `./scripts/certify --fuzz-smoke` adds a fuzz smoke
run. `./scripts/ops/run_verification_pack_v1.sh` is a compatibility alias.

Passing the full suite in Strict Conformance Mode is the conformance criterion
for Grain v0.1.

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
