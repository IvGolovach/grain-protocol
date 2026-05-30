#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

SWIFT_SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/grain-swift-build.XXXXXX")"
trap 'rm -rf "$SWIFT_SCRATCH"' EXIT

BEFORE_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
GENERATED_PATHS=(
  "sdk/swift/Sources/GrainClientFFI/grain_client_core.swift"
  "sdk/swift/Sources/grain_client_coreFFI/include/grain_client_coreFFI.h"
)
BEFORE_GENERATED="$(git hash-object "${GENERATED_PATHS[@]}")"

scripts/sdk/sync_swift_bindings.sh
AFTER_GENERATED="$(git hash-object "${GENERATED_PATHS[@]}")"
if [[ "$AFTER_GENERATED" != "$BEFORE_GENERATED" ]]; then
  echo "SDK_SWIFT_ERR_GENERATED_DRIFT: run scripts/sdk/sync_swift_bindings.sh and commit the result" >&2
  exit 1
fi

cargo build --manifest-path core/rust/Cargo.toml -p grain-client-core
swift build --package-path sdk/swift --scratch-path "$SWIFT_SCRATCH"
swift run --package-path sdk/swift --scratch-path "$SWIFT_SCRATCH" GrainClientIOSAdaptersSmoke
swift run --package-path sdk/swift --scratch-path "$SWIFT_SCRATCH" GrainClientFixtureRunner
swift run --package-path sdk/swift --scratch-path "$SWIFT_SCRATCH" GrainFoodWalletSmoke
swift run --package-path sdk/swift --scratch-path "$SWIFT_SCRATCH" GrainFoodGraphSmoke

AFTER_STATUS="$(git status --porcelain=v1 --untracked-files=all)"
if [[ "$AFTER_STATUS" != "$BEFORE_STATUS" ]]; then
  echo "SDK_SWIFT_ERR_DIRTY_WORKTREE: Swift package check changed git status" >&2
  diff <(printf '%s\n' "$BEFORE_STATUS") <(printf '%s\n' "$AFTER_STATUS") >&2 || true
  exit 1
fi

echo "swift package check: PASS"
