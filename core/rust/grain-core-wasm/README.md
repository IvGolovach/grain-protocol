# grain-core-wasm

WASM portability crate for read/verify path execution.

Exports:
- `grain_alloc(len)`
- `grain_dealloc(ptr, len)`
- `grain_run_vector(ptr, len)`

Input for `grain_run_vector`:
- UTF-8 JSON vector payload bytes.

Output:
- packed `u64` with `(ptr << 32) | len` to JSON bytes containing:
  - `accepted`
  - `diag`
  - `out`

This crate does not define new semantics. It delegates to `grain-core::execute_operation`.
