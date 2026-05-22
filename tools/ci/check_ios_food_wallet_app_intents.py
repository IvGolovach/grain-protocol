#!/usr/bin/env python3
"""Check MealMark App Intents for release-safe shortcuts."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INTENTS_DIR = ROOT / "apps" / "ios-food-wallet" / "Sources" / "FoodWalletAppIntents"
INTENTS_FILE = INTENTS_DIR / "FoodWalletIntents.swift"

FORBIDDEN_TOKENS = [
    'foodName = "Apple"',
    "QuickLogFoodIntent",
    "StartFoodCaptureIntent",
]


def fail(message: str) -> int:
    print(f"IOS_FOOD_WALLET_APP_INTENTS_ERR: {message}", file=sys.stderr)
    return 1


def main() -> int:
    if not INTENTS_FILE.is_file():
        return fail(f"missing {INTENTS_FILE.relative_to(ROOT)}")

    text = INTENTS_FILE.read_text(encoding="utf-8")
    if "AppIntentsPackage" not in text:
        return fail("FoodWalletAppIntents must declare an AppIntentsPackage marker")

    forbidden = [token for token in FORBIDDEN_TOKENS if token in text]
    if forbidden:
        return fail("release shortcuts must not expose placeholder flows: " + ", ".join(forbidden))

    shortcut_blocks = re.findall(r"AppShortcut\s*\((.*?)\n\s*\)", text, flags=re.DOTALL)
    if not shortcut_blocks:
        return fail("at least one AppShortcut is required")

    for block in shortcut_blocks:
        if r"\(.applicationName)" not in block:
            return fail("every AppShortcut phrase must include the application name token")

    open_today = any("OpenFoodWalletIntent(destination: .today)" in block for block in shortcut_blocks)
    if not open_today:
        return fail("release shortcuts must include the truthful Open Today route")

    if ".capture" in text:
        return fail("FoodWalletDestination must not expose capture until shortcut routing exists")

    print("iOS MealMark App Intents: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
