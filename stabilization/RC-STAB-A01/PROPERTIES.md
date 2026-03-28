# RC Stabilization Properties

The stabilization window enforces cross-implementation semantic properties.

## P0 properties (must always pass)
1. Reducer order independence
- Permuting equivalent event sets yields identical reduction output.

2. Reducer idempotence
- Duplicating equivalent events does not change normalized result.

3. Conflict elimination invariants
- `(ak,seq)` conflicts follow ignore-all semantics deterministically.

4. Manifest order independence
- Resolution outcome does not depend on delivery order.

5. Quarantine exclusion
- Quarantined objects never contribute semantics.

## Execution commands
- Rust properties:
```bash
cargo test --manifest-path core/rust/Cargo.toml -p grain-core --test properties
```

- TypeScript full-engine properties:
```bash
npm --prefix runner/typescript run test:properties
```

## Evidence requirement
Property results must be serialized into stabilization artifacts:
- `properties-report.md`
- `stabilization-evidence.json` (`properties` section)
