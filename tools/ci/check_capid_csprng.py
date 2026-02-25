#!/usr/bin/env python3
"""Fail-closed static audit for cap_id CSPRNG policy."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

E2E_TS = ROOT / "core" / "ts" / "grain-sdk" / "src" / "e2e.ts"
UTILS_TS = ROOT / "core" / "ts" / "grain-sdk" / "src" / "utils.ts"
NES = ROOT / "spec" / "NES-v0.1.md"
E2E_PROFILE = ROOT / "spec" / "profiles" / "e2e-profile.md"

SCAN_PATHS = [
    ROOT / "core" / "ts" / "grain-sdk" / "src",
    ROOT / "runner" / "typescript" / "src",
    ROOT / "core" / "rust" / "grain-core" / "src",
]

FORBIDDEN_PATTERNS = [
    "Math.random(",
    "cap_id_from_cid",
    "deterministic_cap_id",
    "cap_id = sha256(",
    "cap_id=sha256(",
]


def ensure_contains(path: Path, needle: str, reason: str) -> None:
    text = path.read_text(encoding="utf-8")
    if needle not in text:
        raise SystemExit(f"{path}: missing required pattern for {reason}: {needle}")


def main() -> int:
    # Required generation path in SDK.
    ensure_contains(E2E_TS, "opts.cap_id ? new Uint8Array(opts.cap_id) : randomBytes32()", "cap_id default generation")
    ensure_contains(UTILS_TS, "randomBytes(32)", "CSPRNG call site")
    ensure_contains(UTILS_TS, "SDK_ERR_CSPRNG_UNAVAILABLE", "fail-closed CSPRNG error")

    # Spec-level policy anchors must stay explicit.
    ensure_contains(NES, "cap_id MUST be generated using a cryptographically secure random number generator (CSPRNG).", "NES CSPRNG rule")
    ensure_contains(E2E_PROFILE, "cap_id MUST be generated using a cryptographically secure random number generator (CSPRNG).", "E2E profile CSPRNG rule")

    violations: list[str] = []
    for base in SCAN_PATHS:
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix not in (".ts", ".rs"):
                continue
            text = path.read_text(encoding="utf-8")
            for pattern in FORBIDDEN_PATTERNS:
                if pattern in text:
                    violations.append(f"{path}:{pattern}")

    if violations:
        raise SystemExit(f"Forbidden deterministic cap_id patterns detected: {violations}")

    print("cap_id CSPRNG audit: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
