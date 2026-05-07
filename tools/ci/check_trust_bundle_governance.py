#!/usr/bin/env python3
"""Validate production trust bundle governance metadata."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CHECKSUM_RE = re.compile(r"^[0-9a-f]{64}$")
ALLOWED_ANCHOR_STATES = {"active", "revoked", "retired"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def require_string(value: Any, message: str) -> str:
    require(isinstance(value, str) and value.strip() == value and bool(value), message)
    return value


def canonical_anchor_checksum(bundle: dict[str, Any]) -> str:
    payload = {
        "bundle_v": bundle.get("bundle_v"),
        "anchors": bundle.get("anchors"),
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def validate_bundle(bundle: dict[str, Any], path: Path) -> None:
    require(bundle.get("bundle_v") == 1, f"TRUST_BUNDLE_GOV_ERR_VERSION: {path}")
    governance = bundle.get("governance")
    require(isinstance(governance, dict), f"TRUST_BUNDLE_GOV_ERR_GOVERNANCE: {path}")
    for field in ("bundle_id", "revision", "checksum_sha256", "signature_ref", "reviewed_by"):
        require_string(governance.get(field), f"TRUST_BUNDLE_GOV_ERR_GOVERNANCE: {path}: {field}")
    checksum_sha256 = str(governance["checksum_sha256"])
    require(
        CHECKSUM_RE.fullmatch(checksum_sha256) is not None,
        f"TRUST_BUNDLE_GOV_ERR_GOVERNANCE: {path}: checksum_sha256",
    )
    require(governance.get("fail_closed") is True, f"TRUST_BUNDLE_GOV_ERR_GOVERNANCE: {path}: fail_closed")

    anchors = bundle.get("anchors")
    require(isinstance(anchors, list) and anchors, f"TRUST_BUNDLE_GOV_ERR_ANCHORS: {path}")
    seen: set[str] = set()
    for anchor in anchors:
        require(isinstance(anchor, dict), f"TRUST_BUNDLE_GOV_ERR_ANCHOR: {path}")
        anchor_id = require_string(anchor.get("id"), f"TRUST_BUNDLE_GOV_ERR_ANCHOR_ID: {path}")
        require(anchor_id not in seen, f"TRUST_BUNDLE_GOV_ERR_DUPLICATE_ANCHOR: {path}: {anchor_id}")
        seen.add(anchor_id)
        state = anchor.get("state")
        require(
            state in ALLOWED_ANCHOR_STATES,
            f"TRUST_BUNDLE_GOV_ERR_ANCHOR_STATE: {path}: {anchor_id}",
        )
        trust_pub_b64 = require_string(anchor.get("trust_pub_b64"), f"TRUST_BUNDLE_GOV_ERR_TRUST_PUB: {path}")
        try:
            decoded = base64.b64decode(trust_pub_b64, validate=True)
        except ValueError as exc:
            raise SystemExit(f"TRUST_BUNDLE_GOV_ERR_TRUST_PUB: {path}") from exc
        require(bool(decoded), f"TRUST_BUNDLE_GOV_ERR_TRUST_PUB: {path}")
    require(
        checksum_sha256 == canonical_anchor_checksum(bundle),
        f"TRUST_BUNDLE_GOV_ERR_CHECKSUM_MISMATCH: {path}",
    )


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"TRUST_BUNDLE_GOV_ERR_JSON: {path}: {exc}") from exc
    require(isinstance(data, dict), f"TRUST_BUNDLE_GOV_ERR_OBJECT: {path}")
    return data


def default_bundle_paths(root: Path) -> list[Path]:
    candidates = root / "sdk" / "trust" / "governed"
    if not candidates.exists():
        return []
    return sorted(candidates.glob("*.json"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("paths", nargs="*", help="Production trust bundle JSON files")
    parser.add_argument("--root", default=str(ROOT))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    paths = [Path(item) for item in args.paths] or default_bundle_paths(root)
    for path in paths:
        target = path if path.is_absolute() else root / path
        validate_bundle(load_json(target), target.relative_to(root) if target.is_relative_to(root) else target)
    print(f"Trust bundle governance guard: OK ({len(paths)} governed bundles)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
