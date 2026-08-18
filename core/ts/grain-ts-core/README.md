# grain-ts-core

Shared TypeScript protocol core for Grain.

This package holds the pure TypeScript protocol engine that both
`runner/typescript` and `core/ts/grain-sdk` depend on.

What lives here:
- protocol data types
- vector parsing
- canonical CBOR helpers
- deterministic operation execution
- shared protocol expectations
- complete Typed Object Validation v1 for optional
  `dagcbor_validate.object_type` context

What does not live here:
- runner CLI and suite harnesses
- SDK orchestration and app-facing helpers

Build it directly when you are working on the shared engine:

```bash
npm ci --prefix core/ts/grain-ts-core
npm --prefix core/ts/grain-ts-core run build
```

`object_type` selects a v0.1 CDDL production for validation. It is runner
metadata and must never be added to encoded object bytes.
