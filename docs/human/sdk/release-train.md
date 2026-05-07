# SDK Release Train

Grain release work moves in separate trains. Do not promote one train by
borrowing evidence from another.

## Trains

Protocol/core releases prove the wire format, vectors, Rust core, and
conformance behavior.

SDK source releases prove Swift, Kotlin, WASM, generated bindings, workflow
contracts, trust schema inputs, source archives, checksums, SBOM, and the
source-only handoff.

starter-template releases prove example app shells can build against the source
SDK and keep custody, trust, logging, telemetry, and preview-before-accept
boundaries intact.

registry-ready releases prove npm, Maven, SwiftPM, package-index, or equivalent
publication metadata and consumer install paths.

app release trains prove App Store, Play Store, PWA, glasses, robot, kiosk,
fleet, or hardware-specific behavior in the consuming app repo.

## Evidence Language

Registry, store, and hardware claims require explicit release evidence. Until
that evidence exists, the current channel is source-only.

Use precise wording:

- "Source SDK handoff" for same-SHA archives and local verification.
- "Registry-ready" only after registry package metadata and install proof pass.
- "Store-ready" only after the app repo has store-specific review evidence.
- "Hardware custody" only after the custody adapter and platform hardware path
  have separate review evidence.

If a train has not passed, say what remains instead of implying publication.
