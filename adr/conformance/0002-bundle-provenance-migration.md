# ADR 0002: Repository Provenance Baseline

Status: Accepted
Date: 2026-02-20

## Context

Release governance requires a stable commit-based provenance model.
Audit evidence must resolve cleanly from commit SHA to deterministic artifacts and signed release tags.

## Decision

Standardize repository provenance around:
- protected Git history,
- protected `main` branch,
- required CI checks,
- deterministic evidence artifacts keyed by commit SHA,
- signed release tags,
- a repository provenance note for release and audit review.

## Consequences

Positive:
- reproducible provenance and release gates,
- clear audit trail from commit SHA to evidence artifact.

Tradeoff:
- publication preparation normalizes earlier internal working records into a consistent commit-based baseline.
- `MIGRATION.md` summarizes the provenance model reviewers should apply.
