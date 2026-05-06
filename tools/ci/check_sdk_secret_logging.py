#!/usr/bin/env python3
"""Guard public SDK/example sources from logging portable secret material."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SDK_ROOTS = [
    ROOT / "sdk" / "swift" / "Sources" / "GrainClient",
    ROOT / "sdk" / "swift" / "Sources" / "GrainClientIOSAdapters",
    ROOT / "sdk" / "kotlin" / "src" / "main" / "kotlin" / "dev" / "grain",
    ROOT / "sdk" / "wasm" / "src",
    ROOT / "examples" / "ios-scanner" / "Sources" / "GrainIOSScanner",
    ROOT / "examples" / "android-scanner" / "src" / "main" / "kotlin",
    ROOT / "examples" / "wasm-scanner" / "src",
]

SOURCE_SUFFIXES = {".swift", ".kt", ".mjs", ".js", ".ts"}
LOG_TOKENS = [
    "print(",
    "println(",
    "debugPrint(",
    "NSLog(",
    "os_log(",
    "console.log(",
    "console.debug(",
    "console.info(",
    "console.warn(",
    "console.error(",
    "Log.",
    "Logger.",
    "Timber.",
]
SENSITIVE_TOKENS = [
    "bundleB64",
    "bundle_b64",
    "coseB64",
    "cose_b64",
    "envelopeB64",
    "envelope_b64",
    "identityBundle",
    "identity_bundle",
    "snapshotB64",
    "snapshot_b64",
    "syncBundle",
    "sync_bundle",
    "syncSecret",
    "sync_secret_b64",
    "trustPubB64",
    "trust_pub_b64",
    "trustMaterial",
    "trust_material",
]

ALLOWLIST_FILES = {
    # Test-only logging lives outside the scanned roots. Keep production/example
    # exceptions explicit if one is ever needed.
}


def should_scan(path: Path) -> bool:
    if path.suffixes[-2:] == [".d", ".ts"]:
        return False
    return path.is_file() and path.suffix in SOURCE_SUFFIXES


def main() -> int:
    violations: list[str] = []
    for root in SDK_ROOTS:
        if not root.exists():
            continue
        for path in sorted(root.rglob("*")):
            if not should_scan(path):
                continue
            rel = str(path.relative_to(ROOT))
            if rel in ALLOWLIST_FILES:
                continue
            for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                if any(log_token in line for log_token in LOG_TOKENS) and any(
                    sensitive in line for sensitive in SENSITIVE_TOKENS
                ):
                    violations.append(f"{rel}:{line_no}: {line.strip()}")

    if violations:
        raise SystemExit(
            "SDK secret logging guard violations:\n- " + "\n- ".join(violations)
        )

    print("SDK secret logging guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
