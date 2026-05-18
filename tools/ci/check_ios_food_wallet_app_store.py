#!/usr/bin/env python3
"""Check iOS Food Wallet App Store/privacy readiness artifacts."""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APP_STORE = ROOT / "apps" / "ios-food-wallet" / "AppStore"


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


def main() -> int:
    if not APP_STORE.is_dir():
        return fail("apps/ios-food-wallet/AppStore is required")

    for name in REQUIRED_FILES:
        if not (APP_STORE / name).is_file():
            return fail(f"missing {name}")

    with (APP_STORE / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    for key in ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"]:
        value = info.get(key)
        if not isinstance(value, str) or len(value.strip()) < 24:
            return fail(f"Info.plist missing useful {key}")
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

    print("iOS Food Wallet App Store artifacts: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
