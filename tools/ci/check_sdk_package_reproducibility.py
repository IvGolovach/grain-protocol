#!/usr/bin/env python3
"""Compare all immutable SDK package files; print no source or payload data."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def compare_packages(first: Path, second: Path) -> dict[str, object]:
    names_a = {path.name for path in first.glob("*.tar.gz")}
    names_b = {path.name for path in second.glob("*.tar.gz")}
    if not names_a or names_a != names_b:
        raise ValueError("SDK_REPRO_ERR_ARTIFACT_SET")
    names = sorted(names_a | {"manifest.json", "SHA256SUMS", "sbom.spdx.json"})
    mismatches = []
    digests = {}
    for name in names:
        left = hashlib.sha256((first / name).read_bytes()).hexdigest()
        right = hashlib.sha256((second / name).read_bytes()).hexdigest()
        digests[name] = left
        if left != right:
            mismatches.append(name)
    if mismatches:
        raise ValueError("SDK_REPRO_ERR_BYTES: " + ", ".join(mismatches))
    return {"schema": "grain.sdk.package.reproducibility.v1", "pass": True,
            "artifact_count": len(names_a), "file_count": len(names), "sha256": digests}


def main() -> int:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--first-dir", type=Path, required=True)
    parser.add_argument("--second-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    result = compare_packages(args.first_dir, args.second_dir)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"SDK package reproducibility: PASS ({result['file_count']} identical files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
