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

What does not live here:
- runner CLI and suite harnesses
- SDK orchestration and app-facing helpers

Build it directly when you are working on the shared engine:

```bash
npm ci --prefix core/ts/grain-ts-core
npm --prefix core/ts/grain-ts-core run build
```
