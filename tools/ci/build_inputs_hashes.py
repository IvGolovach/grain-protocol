#!/usr/bin/env python3
"""Build toolchain/lock hash JSON for interop evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(allow_abbrev=False)
    p.add_argument("--out", required=True)
    return p.parse_args()


def main() -> int:
    args = parse_args()

    root = Path(__file__).resolve().parents[2]
    rust_toolchain = root / "core/rust/rust-toolchain.toml"
    cargo_lock = root / "core/rust/Cargo.lock"
    ts_core_lock = root / "core/ts/grain-ts-core/package-lock.json"
    node_lock = root / "runner/typescript/package-lock.json"
    sdk_node_lock = root / "core/ts/grain-sdk/package-lock.json"

    node_version = subprocess.check_output(["node", "-v"], text=True).strip()

    data = {
        "rust_toolchain_toml_sha256": sha256_file(rust_toolchain),
        "cargo_lock_sha256": sha256_file(cargo_lock),
        "ts_core_node_package_lock_sha256": sha256_file(ts_core_lock),
        "node_package_lock_sha256": sha256_file(node_lock),
        "sdk_node_package_lock_sha256": sha256_file(sdk_node_lock),
        "node_version": node_version,
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")

    print("Inputs hashes: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
