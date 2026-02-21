#!/usr/bin/env python3
"""Generate deterministic vector manifest with sha256 per file."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib


def _sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--vectors-root", required=True)
    p.add_argument("--pattern", default="*.json")
    p.add_argument("--out", required=True)
    return p.parse_args()


def main() -> int:
    args = _parse_args()
    root = pathlib.Path(args.vectors_root)
    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    items = []
    for p in sorted(root.rglob(args.pattern)):
        if not p.is_file():
            continue
        vector_id = p.stem
        try:
            obj = json.loads(p.read_text(encoding="utf-8"))
            vector_id = str(obj.get("vector_id", vector_id))
        except Exception:
            pass
        items.append(
            {
                "id": vector_id,
                "path": str(p),
                "sha256": _sha256(p),
            }
        )

    out.write_text(json.dumps(items, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(items)} entries to {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
