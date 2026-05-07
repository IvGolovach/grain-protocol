#!/usr/bin/env python3
"""Guard SDK security review and release train docs."""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_DOC_TOKENS = {
    Path("docs/human/sdk/security-review.md"): (
        "# SDK Security Review",
        "Replay",
        "trust injection",
        "snapshot leakage",
        "pairing misuse",
        "unsafe logs",
        "backup",
        "app-shell divergence",
        "no secret telemetry",
        "custody adapter",
        "release evidence",
    ),
    Path("docs/human/sdk/release-train.md"): (
        "# SDK Release Train",
        "Protocol/core",
        "SDK source",
        "starter-template",
        "registry-ready",
        "app release",
        "Registry, store, and hardware claims require explicit release evidence",
        "source-only",
    ),
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def check_docs(root: Path = ROOT) -> None:
    missing: list[str] = []
    for rel_path, tokens in REQUIRED_DOC_TOKENS.items():
        path = root / rel_path
        if not path.is_file():
            missing.append(f"{rel_path}: missing file")
            continue
        text = path.read_text(encoding="utf-8")
        for token in tokens:
            if token not in text:
                missing.append(f"{rel_path}: missing `{token}`")

    if missing:
        raise SystemExit("RELEASE_TRAIN_DOCS_ERR_MISSING_TOKEN:\n- " + "\n- ".join(missing))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--root", default=str(ROOT))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    check_docs(Path(args.root).resolve())
    print("Release train docs guard: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
