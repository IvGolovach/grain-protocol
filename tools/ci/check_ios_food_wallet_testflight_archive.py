#!/usr/bin/env python3
"""Validate a MealMark iOS archive before TestFlight upload."""

from __future__ import annotations

import argparse
import ipaddress
import plistlib
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


DEFAULT_BUNDLE_ID = "dev.grain.foodwallet"
APP_NAME = "FoodWallet.app"
DISTRIBUTION_AUTHORITIES = ("Apple Distribution:", "iPhone Distribution:")
DEVELOPMENT_AUTHORITIES = ("Apple Development:", "iPhone Developer:")


def fail(message: str) -> int:
    print(f"IOS_FOOD_WALLET_TESTFLIGHT_ARCHIVE_ERR: {message}", file=sys.stderr)
    return 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", help="Path to MealMark .xcarchive")
    parser.add_argument("--expected-bundle-id", default=DEFAULT_BUNDLE_ID)
    parser.add_argument(
        "--allow-empty-broker",
        action="store_true",
        help="Allow an archive without a broker URL. This disables photo/barcode remote analysis.",
    )
    parser.add_argument(
        "--allow-development-signing",
        action="store_true",
        help="Permit Apple Development signing for local diagnostics only.",
    )
    return parser.parse_args()


def load_plist(path: Path) -> dict:
    with path.open("rb") as handle:
        payload = plistlib.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"{path} is not a plist dictionary")
    return payload


def app_bundle_path(archive: Path) -> Path:
    app_path = archive / "Products" / "Applications" / APP_NAME
    if app_path.is_dir():
        return app_path
    matches = sorted((archive / "Products" / "Applications").glob("*.app"))
    if len(matches) == 1:
        return matches[0]
    raise FileNotFoundError(f"could not locate {APP_NAME} in {archive}")


def broker_url_is_public_https(value: str) -> tuple[bool, str]:
    parsed = urlparse(value)
    if parsed.scheme.lower() != "https":
        return False, "broker URL must use https"
    if not parsed.hostname:
        return False, "broker URL must include a host"

    host = parsed.hostname.lower()
    if host in {"localhost", "127.0.0.1", "::1"} or host.endswith(".local"):
        return False, "broker URL must not point at localhost or .local"
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return True, ""
    if ip.is_private or ip.is_loopback or ip.is_link_local:
        return False, "broker URL must not point at a private or loopback IP"
    return True, ""


def codesign_authorities(app_path: Path) -> list[str]:
    result = subprocess.run(
        ["/usr/bin/codesign", "-dv", "--verbose=2", str(app_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stdout.strip() or "codesign inspection failed")
    authorities: list[str] = []
    for line in result.stdout.splitlines():
        if line.startswith("Authority="):
            authorities.append(line.split("=", 1)[1])
    return authorities


def codesign_entitlements(app_path: Path) -> dict:
    result = subprocess.run(
        ["/usr/bin/codesign", "-d", "--entitlements", ":-", str(app_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip() or "codesign entitlements failed")
    payload = result.stdout
    xml_start = payload.find(b"<?xml")
    if xml_start > 0:
        payload = payload[xml_start:]
    if not payload.strip():
        return {}
    parsed = plistlib.loads(payload)
    if not isinstance(parsed, dict):
        raise RuntimeError("codesign entitlements are not a plist dictionary")
    return parsed


def embedded_profile(app_path: Path) -> dict:
    profile_path = app_path / "embedded.mobileprovision"
    if not profile_path.is_file():
        raise FileNotFoundError("archive app missing embedded.mobileprovision")
    result = subprocess.run(
        ["/usr/bin/security", "cms", "-D", "-i", str(profile_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip() or "mobileprovision decode failed")
    parsed = plistlib.loads(result.stdout)
    if not isinstance(parsed, dict):
        raise RuntimeError("embedded.mobileprovision is not a plist dictionary")
    return parsed


def validate_distribution_profile(app_path: Path) -> tuple[bool, str]:
    entitlements = codesign_entitlements(app_path)
    if entitlements.get("get-task-allow") is True:
        return False, "archive entitlement get-task-allow must be false for TestFlight"

    profile = embedded_profile(app_path)
    if profile.get("ProvisionedDevices"):
        return False, "archive provisioning profile must not contain provisioned devices"
    if profile.get("ProvisionsAllDevices") is True:
        return False, "archive provisioning profile must not be an enterprise profile"

    profile_entitlements = profile.get("Entitlements")
    if isinstance(profile_entitlements, dict):
        application_id = profile_entitlements.get("application-identifier")
        if isinstance(application_id, str) and "*" in application_id:
            return False, "archive provisioning profile must not use a wildcard app identifier"
    return True, ""


def archive_build_summary(archive_info: dict, app_info: dict, broker_url: str | None) -> str:
    version = app_info.get("CFBundleShortVersionString", "<unknown>")
    build = app_info.get("CFBundleVersion", "<unknown>")
    bundle = app_info.get("CFBundleIdentifier", "<unknown>")
    broker = broker_url or "<empty>"
    return f"bundle={bundle} version={version} build={build} broker={broker}"


def main() -> int:
    args = parse_args()
    archive = Path(args.archive).expanduser().resolve()
    if not archive.is_dir() or archive.suffix != ".xcarchive":
        return fail(f"archive is not a .xcarchive directory: {archive}")

    archive_info_path = archive / "Info.plist"
    if not archive_info_path.is_file():
        return fail(f"archive missing Info.plist: {archive_info_path}")

    try:
        archive_info = load_plist(archive_info_path)
        app_path = app_bundle_path(archive)
        app_info = load_plist(app_path / "Info.plist")
    except Exception as exc:
        return fail(str(exc))

    bundle_id = app_info.get("CFBundleIdentifier")
    if bundle_id != args.expected_bundle_id:
        return fail(f"expected bundle id {args.expected_bundle_id}, got {bundle_id!r}")

    display_name = app_info.get("CFBundleDisplayName")
    if display_name != "MealMark":
        return fail(f"CFBundleDisplayName must be MealMark, got {display_name!r}")

    if "GRAIN_FOOD_BROKER_DEV_TOKEN" in app_info:
        return fail("archive Info.plist must not contain a broker dev token")

    broker_url = app_info.get("GRAIN_FOOD_ANALYSIS_BROKER_URL")
    if isinstance(broker_url, str):
        broker_url = broker_url.strip()
    else:
        broker_url = ""
    if not broker_url:
        if not args.allow_empty_broker:
            return fail("archive broker URL is empty; set GRAIN_FOOD_ANALYSIS_BROKER_URL to a public HTTPS broker")
    else:
        ok, reason = broker_url_is_public_https(broker_url)
        if not ok:
            return fail(reason)

    try:
        authorities = codesign_authorities(app_path)
    except Exception as exc:
        return fail(str(exc))
    has_distribution = any(authority.startswith(DISTRIBUTION_AUTHORITIES) for authority in authorities)
    has_development = any(authority.startswith(DEVELOPMENT_AUTHORITIES) for authority in authorities)
    if not has_distribution:
        if not (args.allow_development_signing and has_development):
            return fail(
                "archive is not signed with Apple Distribution/iPhone Distribution; "
                f"authorities={authorities!r}"
            )
    else:
        try:
            ok, reason = validate_distribution_profile(app_path)
        except Exception as exc:
            return fail(str(exc))
        if not ok:
            return fail(reason)

    print("iOS MealMark TestFlight archive: PASS")
    print(archive_build_summary(archive_info, app_info, broker_url or None))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
