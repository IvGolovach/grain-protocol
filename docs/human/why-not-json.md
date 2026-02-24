# Why Not JSON?

Short answer: Grain needs deterministic bytes, not just equivalent objects.

JSON alone is insufficient for this protocol because:
- key ordering is not guaranteed,
- duplicate keys are ambiguous across parsers,
- number handling differs by language/runtime,
- Unicode normalization and escaping can drift,
- signature/hash inputs become unstable across implementations.

Grain uses strict DAG-CBOR to guarantee one canonical byte form for one valid object meaning (within v0.1 profile).
