#!/usr/bin/env python3
"""Guard the real-app distribution and custody guidance docs."""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]

RULES = {
    Path("docs/human/sdk/distribution-roadmap.md"): {
        "all_of": [
            "# SDK Distribution Roadmap",
            "## Current Channel: Source-Only Handoff",
            "## Future Registry Channels",
            "SwiftPM",
            "Maven",
            "npm",
            "## Not Yet Published",
            "## Thin UX Layers",
            "phone",
            "glasses",
            "robot",
            "source-only",
        ],
    },
    Path("docs/human/sdk/custody-threat-model.md"): {
        "all_of": [
            "# SDK Custody Threat Model",
            "## Trust Boundary",
            "Keychain",
            "Keystore",
            "IndexedDB",
            "snapshot export",
            "local trust bundle",
            "no secret logging",
            "## Platform Custody Rules",
            "## Misuse Cases",
            "## App Handoff Checklist",
        ],
    },
    Path("docs/superpowers/plans/2026-05-05-real-app-sdk-roadmap.md"): {
        "all_of": [
            "Distribution and custody hardening",
            "docs/human/sdk/distribution-roadmap.md",
            "docs/human/sdk/custody-threat-model.md",
            "source-only now",
        ],
    },
}


def missing_all_of(text: str, tokens: Iterable[str]) -> list[str]:
    return [token for token in tokens if token not in text]


def main() -> int:
    missing: list[str] = []

    for relative_path, rule in RULES.items():
        path = ROOT / relative_path
        if not path.exists():
            missing.append(f"{relative_path}: missing file")
            continue

        text = path.read_text(encoding="utf-8")
        for token in missing_all_of(text, rule.get("all_of", [])):
            missing.append(f"{relative_path}: missing `{token}`")

    if missing:
        raise SystemExit("Real-app docs check failed:\n" + "\n".join(missing))

    print("real-app docs: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
