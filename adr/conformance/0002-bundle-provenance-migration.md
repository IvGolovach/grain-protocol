# ADR 0002: Bundle-to-Git Provenance Migration

Status: Accepted
Date: 2026-02-20

## Context

Work products were initially delivered as a local filesystem bundle.
Audit evidence referenced `commit: null` / `no-git-bundle`, which is insufficient for reproducibility and release governance.

## Decision

Migrate to private GitHub repository with:
- logical reconstructed commits (C0..C4),
- protected `main` branch,
- required CI checks,
- deterministic evidence artifacts keyed by commit SHA,
- signed release tags.

## Consequences

Positive:
- reproducible provenance and release gates,
- clear audit trail from commit SHA to evidence artifact.

Tradeoff:
- reconstructed history is not original chronological execution history.
This is explicitly documented in `MIGRATION.md`.
