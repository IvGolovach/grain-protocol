#!/usr/bin/env python3
"""Compute deterministic evidence.sha256 over canonical file concatenation order."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--base-dir", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--file", action="append", required=True)
    return p.parse_args()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    args = parse_args()
    base_dir = Path(args.base_dir)
    out_path = Path(args.out)

    ordered = sorted(dict.fromkeys(args.file))

    file_hashes: list[tuple[str, str]] = []
    blob_parts: list[bytes] = []

    for rel in ordered:
        p = base_dir / rel
        if not p.exists():
            raise SystemExit(f"Missing evidence file for hashing: {p}")
        file_bytes = p.read_bytes()
        file_hashes.append((rel, sha256_file(p)))
        blob_parts.append(rel.encode("utf-8") + b"\n" + file_bytes + b"\n--\n")

    evidence_hash = sha256_bytes(b"".join(blob_parts))

    lines = [f"evidence_sha256 {evidence_hash}"]
    for rel, h in file_hashes:
        lines.append(f"{h} {rel}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print("Evidence hash: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
