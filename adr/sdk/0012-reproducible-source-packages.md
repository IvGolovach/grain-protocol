# ADR 0012: Reproducible SDK Source Packages

Status: Accepted

Date: 2026-10-25

## Context

Two source-package runs at the same clean commit produced identical file
contents but different bytes in all eight archives. Host gzip timestamps,
staging tar metadata and wall-clock manifest/SBOM timestamps changed the hashes.
Package integrity and external consumer checks did not establish reproducibility.

## Decision

- Write source archives with the Python standard library, using sorted relative
  paths, commit timestamp for tar/gzip, uid/gid zero, empty owner names, 0755
  directories/executable files and 0644 other files. Preserve file contents and
  executable intent. Omit host atime/ctime, gzip filename and macOS metadata.
- Reject symlinks, special files, absolute paths and traversal. Keep existing
  secret/cache exclusions and package validation; no integrity gate is removed.
- Derive manifest `created_at` and SPDX creation time from the exact source
  commit timestamp in UTC. They identify reproducible source time, not workflow
  execution time. Real run times remain in CI run evidence.
- Compare all eight archives, manifest, checksums and SBOM in `sdk-platform`
  after the strict gate. Packaging twice reuses that completed gate without
  falsely marking an unverified run as strict. Metadata-variation tests build
  from separate roots with different creation order, permissions and mtimes.
- Keep source-only distribution, public schemas, required context names,
  protected full-ci approval, and release authorization unchanged.

## Compatibility and limits

New archive bytes/hashes change; old release bytes are never rewritten.
Existing extraction paths, generated bindings and file contents remain valid.
Consumers must treat the metadata timestamp as source time. Runtime evidence
is separate and may vary. Verification source/mode are part of package inputs;
different provenance inputs are not expected to yield identical manifests.

The guarantee is for the same clean commit, dependency/toolchain inputs and
verification metadata in the supported environment. It is not a claim about
arbitrary Python/zlib/toolchain versions, compiled binaries, registry delivery,
hardware custody or production application behavior. Existing RC interop
evidence reproducibility remains a separate check.

## Verification

Archive tests cover distinct roots, long UTF-8 paths, empty directories,
executable intent, exclusions, overlapping input roots, gzip headers, traversal,
symlinks and invalid epochs. Metadata tests require commit time in UTC.
Comparison tests reject missing/different archives and changed manifest/SBOM.
CI repeats actual source packaging and compares all immutable package files
before the existing external developer handoff.
