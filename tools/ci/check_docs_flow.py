#!/usr/bin/env python3
"""Ensure onboarding quickstart keeps runnable path before deep spec links."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUICKSTART = ROOT / "docs" / "human" / "quickstart.md"
EXPECTED = ROOT / "docs" / "human" / "_expected" / "quickstart-output.json"


def main() -> int:
    text = QUICKSTART.read_text(encoding="utf-8")

    first_bash = text.find("```bash")
    if first_bash < 0:
        raise SystemExit("Quickstart flow check failed: missing runnable bash block.")

    spec_pos = text.find("spec/")
    llm_pos = text.find("docs/llm/")

    ref_positions = [p for p in [spec_pos, llm_pos] if p >= 0]
    if ref_positions and first_bash > min(ref_positions):
        raise SystemExit(
            "Quickstart flow check failed: protocol references appear before first runnable command block."
        )

    required_tokens = [
        "Run the demo pipeline",
        "grain-runner -- demo --strict",
        "Expected deterministic output",
    ]
    missing = [tok for tok in required_tokens if tok not in text]
    if missing:
        raise SystemExit(f"Quickstart flow check failed: missing required markers: {missing}")

    if not EXPECTED.exists():
        raise SystemExit("Quickstart flow check failed: missing docs/human/_expected/quickstart-output.json")

    print("Quickstart flow check: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
