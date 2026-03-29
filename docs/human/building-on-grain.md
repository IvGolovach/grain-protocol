# Building On Grain

This page is for app builders. It shows the shortest path from "I want to use Grain" to "I have a small working app".

## Start with the smallest win

If you want the easiest first step, read [Minimal app example](./sdk/minimal-app-example.md).

That example does four things:
- creates an in-memory SDK
- creates a root identity
- appends one event
- reduces the event list into a deterministic result

For that first app, `payload_cid` can simply be a stable identifier for the source payload.
If you later store the payload as its own canonical Grain object, then using that real CID is the stronger pattern.

## What you can count on

- Signed data can be checked for integrity and authorship.
- The same valid event set produces the same reducer output every time.
- Private sync uses capabilities, which are secret references, plus manifest resolution.

## What you should not expect

- Grain does not tell you whether the content is true.
- Private data is not visible to the server in plaintext.
- Grain does not guess outside strict conformance rules.

## A simple app path

1. Decode the transport payload. `GR1:` is the QR transport prefix.
2. Verify the COSE signature under the narrow profile.
3. Add the normalized event to your local ledger store.
4. Run the reducer to get the same totals every time.

If you want shipped v0.1 reducer behavior today, stay on the existing `IntakeEvent` path.
If you want to preserve an app-defined event type, treat that as a store/forward lane unless you have added explicit semantics on top.

If you are building with the SDK, go to [SDK Start Here](./sdk/start-here.md).
If you are mapping a domain object into Grain, use [Domain Adapters](./domain-adapters.md).
If you want the deeper protocol rules, read the conformance spec after your first run.

## Read later

Most app builders do not need the full `NES` (`Normative Encoding & Semantics`) document on day one.
Start with:
- `conformance/SPEC.md`

Then go deeper if you need protocol detail:
- `spec/NES-v0.1.md`
- `spec/profiles/*`
