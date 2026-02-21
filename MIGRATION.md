# Provenance Migration (Bundle -> Git)

This repository history was reconstructed from a local filesystem bundle.

Important:
- Commit chronology in this repository is **logical reconstruction**, not original execution-time chronology.
- Protocol semantics are unchanged; frozen-core rules remain defined by `spec/NES-v0.1.md` and `spec/FREEZE-v0.1.md`.
- Provenance after migration is commit-based and CI-anchored.

Reconstruction stages:
1. C0: protocol freeze + spec + conformance baseline import
2. C1: TOR-01 Wave A court hardening material
3. C2: TOR-02 Rust reference core
4. C3: TOR-03 TS C01 smoke runner
5. C4: GitHub hardening + provenance CI pipeline

This file exists to prevent timeline ambiguity in external audits.
