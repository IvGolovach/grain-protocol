#!/usr/bin/env python3
"""Fail if SDK core or AI sidecar introduce outbound network usage."""

from __future__ import annotations

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
SDK_ROOTS = [
    ROOT / "core" / "ts" / "grain-sdk" / "src",
    ROOT / "core" / "ts" / "grain-sdk-ai" / "src",
    ROOT / "sdk" / "swift" / "Sources",
]

FORBIDDEN = [
    "fetch(",
    "axios",
    "undici",
    "node:http",
    "node:https",
    "http://",
    "https://",
    "URLSession",
    "URLRequest",
    "NWConnection",
    "Network.framework",
]

FORBIDDEN_PACKAGE_DEPENDENCIES = [
    "@huggingface",
    "transformers",
    "@xenova/transformers",
    "sentence-transformers",
    "onnxruntime",
    "tensorflow",
    "torch",
    "axios",
    "undici",
    "safetensors",
]

ALLOWLIST_FILES = {
    # No allowlist entries for now; keep explicit for future audited exceptions.
}


def should_scan(path: Path) -> bool:
    return path.is_file() and path.suffix in {".ts", ".js", ".swift"}


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
            text = path.read_text(encoding="utf-8")
            for pattern in FORBIDDEN:
                if pattern in text:
                    violations.append(f"{rel}: {pattern}")

    package_paths = [
        ROOT / "core" / "ts" / "grain-sdk" / "package.json",
        ROOT / "core" / "ts" / "grain-sdk-ai" / "package.json",
    ]
    for package_path in package_paths:
        if not package_path.exists():
            continue
        package = json.loads(package_path.read_text(encoding="utf-8"))
        dependencies = {
            **package.get("dependencies", {}),
            **package.get("optionalDependencies", {}),
            **package.get("peerDependencies", {}),
        }
        for dependency in dependencies:
            dep_lower = dependency.lower()
            for forbidden in FORBIDDEN_PACKAGE_DEPENDENCIES:
                if forbidden in dep_lower:
                    violations.append(f"{package_path.relative_to(ROOT)}: forbidden runtime dependency {dependency}")

    if violations:
        raise SystemExit("SDK no-network guard violations:\n- " + "\n- ".join(violations))

    print("SDK no-network guard: OK (TS core, TS AI sidecar, Swift sources)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
