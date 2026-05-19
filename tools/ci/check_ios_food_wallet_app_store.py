#!/usr/bin/env python3
"""Check iOS MealMark App Store/privacy readiness artifacts."""

from __future__ import annotations

import plistlib
import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP_STORE = ROOT / "apps" / "ios-food-wallet" / "AppStore"
APP_ICONSET = APP_STORE / "Assets.xcassets" / "AppIcon.appiconset"


REQUIRED_FILES = [
    "Info.plist",
    "PrivacyInfo.xcprivacy",
    "AppPrivacyAnswers.md",
    "AppReviewNotes.md",
    "PrivacyPolicy.md",
    "StoreKitProducts.md",
]

FORBIDDEN_CLAIMS = [
    "diagnose",
    "treat disease",
    "guaranteed accurate",
    "medical-grade",
    "medical grade",
    "cure",
]


def read_text(name: str) -> str:
    return (APP_STORE / name).read_text(encoding="utf-8")


def fail(message: str) -> int:
    print(f"IOS_FOOD_WALLET_APP_STORE_ERR: {message}", file=sys.stderr)
    return 1


def require_text(name: str, tokens: list[str]) -> int:
    text = read_text(name).lower()
    missing = [token for token in tokens if token.lower() not in text]
    if missing:
        return fail(f"{name} missing required text: {', '.join(missing)}")
    forbidden = [claim for claim in FORBIDDEN_CLAIMS if claim in text]
    if forbidden:
        return fail(f"{name} contains forbidden medical/accuracy claim: {', '.join(forbidden)}")
    return 0


def require_app_icon_assets() -> int:
    contents_path = APP_ICONSET / "Contents.json"
    if not contents_path.is_file():
        return fail("AppIcon.appiconset missing Contents.json")

    try:
        contents = json.loads(contents_path.read_text(encoding="utf-8"))
    except Exception as exc:
        return fail(f"AppIcon.appiconset Contents.json is not valid JSON: {exc}")

    for image in contents.get("images", []):
        filename = image.get("filename")
        if not filename:
            continue
        size = image.get("size", "")
        scale = image.get("scale", "")
        try:
            points = float(size.split("x", 1)[0])
            multiplier = int(scale.removesuffix("x"))
        except Exception:
            return fail(f"AppIcon.appiconset has invalid size/scale for {filename}")
        expected_pixels = round(points * multiplier)
        path = APP_ICONSET / filename
        if not path.is_file():
            return fail(f"AppIcon.appiconset missing {filename}")
        try:
            width, height, color_type = read_png_header(path)
        except ValueError as exc:
            return fail(f"{filename} is not a valid PNG icon: {exc}")
        if (width, height) != (expected_pixels, expected_pixels):
            return fail(f"{filename} must be {expected_pixels}x{expected_pixels}, got {width}x{height}")
        if color_type in {4, 6}:
            return fail(f"{filename} must not contain alpha/transparency")
    return 0


def read_png_header(path: Path) -> tuple[int, int, int]:
    with path.open("rb") as handle:
        header = handle.read(33)
    if len(header) < 33 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("missing PNG signature")
    chunk_length, chunk_type = struct.unpack(">I4s", header[8:16])
    if chunk_length != 13 or chunk_type != b"IHDR":
        raise ValueError("missing IHDR chunk")
    width, height, bit_depth, color_type = struct.unpack(">IIBB", header[16:26])
    if bit_depth != 8:
        raise ValueError(f"expected 8-bit PNG, got {bit_depth}")
    return width, height, color_type


def main() -> int:
    if not APP_STORE.is_dir():
        return fail("apps/ios-food-wallet/AppStore is required")

    for name in REQUIRED_FILES:
        if not (APP_STORE / name).is_file():
            return fail(f"missing {name}")

    with (APP_STORE / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    if info.get("CFBundleDisplayName") != "MealMark":
        return fail("Info.plist CFBundleDisplayName must be MealMark")
    for key in ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"]:
        value = info.get(key)
        if not isinstance(value, str) or len(value.strip()) < 24:
            return fail(f"Info.plist missing useful {key}")
        if "mealmark" not in value.lower():
            return fail(f"Info.plist {key} must use MealMark branding")
    if "not stored" not in info["NSPhotoLibraryUsageDescription"].lower():
        return fail("NSPhotoLibraryUsageDescription must state selected photos are not stored")

    with (APP_STORE / "PrivacyInfo.xcprivacy").open("rb") as handle:
        privacy = plistlib.load(handle)
    if privacy.get("NSPrivacyTracking") is not False:
        return fail("PrivacyInfo.xcprivacy must keep NSPrivacyTracking false")

    checks = [
        ("AppPrivacyAnswers.md", ["Tracking: no", "Raw photo retention: no", "Third-party AI", "StoreKit"]),
        ("AppReviewNotes.md", ["What To Test", "AI And Photos", "restore/manage subscription", "not medical advice"]),
        ("PrivacyPolicy.md", ["does not store raw meal photos", "consent", "StoreKit", "No Medical Claims"]),
        ("StoreKitProducts.md", ["dev.grain.foodwallet.plus.monthly", "dev.grain.foodwallet.plus.yearly", "restore purchases"]),
    ]
    for name, tokens in checks:
        status = require_text(name, tokens)
        if status:
            return status

    status = require_app_icon_assets()
    if status:
        return status

    print("iOS MealMark App Store artifacts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
