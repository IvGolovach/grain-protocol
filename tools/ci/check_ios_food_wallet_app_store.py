#!/usr/bin/env python3
"""Check iOS MealMark App Store/privacy readiness artifacts."""

from __future__ import annotations

import plistlib
import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROJECT_YML = ROOT / "apps" / "ios-food-wallet" / "project.yml"
APP_STORE = ROOT / "apps" / "ios-food-wallet" / "AppStore"
APP_ICONSET = APP_STORE / "Assets.xcassets" / "AppIcon.appiconset"
STOREKIT_FILE = "MealMark.storekit"
STOREKIT_PRODUCTS = {
    "dev.grain.foodwallet.plus.monthly": "P1M",
    "dev.grain.foodwallet.plus.yearly": "P1Y",
}


REQUIRED_FILES = [
    "Info.plist",
    STOREKIT_FILE,
    "PrivacyInfo.xcprivacy",
    "AppPrivacyAnswers.md",
    "AppReviewNotes.md",
    "PrivacyPolicy.md",
    "StoreKitProducts.md",
    "TestFlightReleaseGuide.md",
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


def require_project_yml() -> int:
    if not PROJECT_YML.is_file():
        return fail("apps/ios-food-wallet/project.yml is required")

    text = PROJECT_YML.read_text(encoding="utf-8")
    tokens = [
        "CURRENT_PROJECT_VERSION",
        "MARKETING_VERSION",
        "PRODUCT_BUNDLE_IDENTIFIER: dev.grain.foodwallet",
        "AppStore/MealMark.storekit",
        "buildPhase: none",
        "storeKitConfiguration: AppStore/MealMark.storekit",
        "archive:",
        "config: Release",
    ]
    missing = [token for token in tokens if token not in text]
    if missing:
        return fail(f"project.yml missing App Store/TestFlight wiring: {', '.join(missing)}")
    if "GRAIN_FOOD_BROKER_DEV_TOKEN" in text:
        return fail("project.yml must not embed the local broker dev token setting")
    return 0


def require_storekit_config() -> int:
    path = APP_STORE / STOREKIT_FILE
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return fail(f"{STOREKIT_FILE} is not valid JSON: {exc}")

    version = payload.get("version")
    if not isinstance(version, dict) or version.get("major", 0) < 2:
        return fail(f"{STOREKIT_FILE} must declare StoreKit config version 2 or newer")
    if payload.get("products") != [] or payload.get("nonRenewingSubscriptions") != []:
        return fail(f"{STOREKIT_FILE} should contain subscriptions only")

    groups = payload.get("subscriptionGroups")
    if not isinstance(groups, list) or len(groups) != 1:
        return fail(f"{STOREKIT_FILE} must contain exactly one subscription group")
    group = groups[0]
    if not isinstance(group, dict) or group.get("name") != "MealMark Plus":
        return fail(f"{STOREKIT_FILE} subscription group must be MealMark Plus")

    subscriptions = group.get("subscriptions")
    if not isinstance(subscriptions, list) or len(subscriptions) != len(STOREKIT_PRODUCTS):
        return fail(f"{STOREKIT_FILE} must contain monthly and yearly Plus subscriptions")

    seen: dict[str, str] = {}
    for subscription in subscriptions:
        if not isinstance(subscription, dict):
            return fail(f"{STOREKIT_FILE} contains an invalid subscription entry")
        product_id = subscription.get("productID")
        if product_id not in STOREKIT_PRODUCTS:
            return fail(f"{STOREKIT_FILE} contains unexpected product ID {product_id!r}")
        if subscription.get("type") != "RecurringSubscription":
            return fail(f"{product_id} must be a recurring subscription")
        expected_period = STOREKIT_PRODUCTS[product_id]
        if subscription.get("recurringSubscriptionPeriod") != expected_period:
            return fail(f"{product_id} must use period {expected_period}")
        if subscription.get("subscriptionGroupID") != group.get("id"):
            return fail(f"{product_id} must reference the MealMark Plus subscription group")
        if not subscription.get("referenceName"):
            return fail(f"{product_id} missing referenceName")
        if not subscription.get("displayPrice"):
            return fail(f"{product_id} missing local displayPrice")
        localizations = subscription.get("localizations")
        if not isinstance(localizations, list) or not any(
            loc.get("locale") == "en_US"
            and loc.get("displayName")
            and loc.get("description")
            for loc in localizations
            if isinstance(loc, dict)
        ):
            return fail(f"{product_id} missing en_US display name and description")
        seen[product_id] = subscription["recurringSubscriptionPeriod"]

    missing_products = [product_id for product_id in STOREKIT_PRODUCTS if product_id not in seen]
    if missing_products:
        return fail(f"{STOREKIT_FILE} missing products: {', '.join(missing_products)}")
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

    status = require_project_yml()
    if status:
        return status

    status = require_storekit_config()
    if status:
        return status

    with (APP_STORE / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    if info.get("CFBundleDisplayName") != "MealMark":
        return fail("Info.plist CFBundleDisplayName must be MealMark")
    if "GRAIN_FOOD_BROKER_DEV_TOKEN" in info:
        return fail("Info.plist must not embed the local broker dev token setting")
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
    accessed = privacy.get("NSPrivacyAccessedAPITypes")
    if not isinstance(accessed, list) or not any(
        entry.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
        and "CA92.1" in entry.get("NSPrivacyAccessedAPITypeReasons", [])
        for entry in accessed
        if isinstance(entry, dict)
    ):
        return fail("PrivacyInfo.xcprivacy must declare UserDefaults required-reason API use")

    checks = [
        (
            "AppPrivacyAnswers.md",
            [
                "Tracking: no",
                "Raw photo retention: no",
                "Third-party AI",
                "StoreKit",
                "lightweight server",
                "StoreKit entitlement sync",
                "Photos or Videos",
                "Health & Fitness",
                "Other User Content",
            ],
        ),
        (
            "AppReviewNotes.md",
            [
                "Build Access",
                "What To Test",
                "AI And Photos",
                "Account required: no",
                "restore/manage subscription",
                "not medical advice",
            ],
        ),
        (
            "PrivacyPolicy.md",
            [
                "does not store raw meal photos",
                "consent",
                "StoreKit",
                "App Privacy Updates",
                "No Medical Claims",
            ],
        ),
        (
            "StoreKitProducts.md",
            [
                "MealMark.storekit",
                "MealMark Plus",
                "dev.grain.foodwallet.plus.monthly",
                "dev.grain.foodwallet.plus.yearly",
                "restore purchases",
                "manage subscription",
            ],
        ),
        (
            "TestFlightReleaseGuide.md",
            [
                "App Store Connect Setup",
                "MealMark.storekit",
                "xcodebuild archive",
                "GRAIN_IOS_DISTRIBUTION_TEAM",
                "GRAIN_FOOD_BROKER_DEV_TOKEN",
                "Release Blockers",
            ],
        ),
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
