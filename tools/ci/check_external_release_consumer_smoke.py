#!/usr/bin/env python3
"""Smoke-test SDK release assets from a clean external consumer layout."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tempfile
import tomllib
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))
ROOT = SCRIPT_DIR.parents[1]

import check_external_consumer_templates as consumer_templates

CLIENT_RUST_MEMBERS = ("grain-core", "grain-client-core", "grain-client-wasm")
FORBIDDEN_RUST_MEMBERS = {"grain-runner", "grain-core-wasm", "grain-issuer-kit", "uniffi-bindgen"}


@dataclass(frozen=True)
class ExternalReleaseConsumerSmokeResult:
    commit: str
    consumer_root: Path
    checks: tuple[str, ...]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--out-dir", required=True, help="Directory containing SDK release assets")
    parser.add_argument("--expected-commit")
    parser.add_argument("--consumer-root", help="External consumer root. Defaults to a temporary directory.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail when local Swift/Java/Node/Cargo prerequisites are unavailable.",
    )
    parser.add_argument(
        "--layout-only",
        action="store_true",
        help="Only validate extracted external layout and Rust workspace policy; do not run toolchain smokes.",
    )
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def run_command(name: str, command: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    print(f"== {name} ==")
    print("+ " + " ".join(command))
    subprocess.run(command, cwd=cwd, env=env, check=True)


def skip_or_fail(strict: bool, code: str, message: str) -> bool:
    if strict:
        raise SystemExit(f"{code}: {message}")
    print(f"SKIP {code}: {message}")
    return False


def validate_rust_workspace(vendor_root: Path) -> None:
    cargo_path = vendor_root / "core/rust/Cargo.toml"
    require(cargo_path.is_file(), "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_RUST_WORKSPACE_MISSING")
    data = tomllib.loads(cargo_path.read_text(encoding="utf-8"))
    members = data.get("workspace", {}).get("members")
    require(isinstance(members, list), "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_RUST_WORKSPACE_MEMBERS_TYPE")
    require(
        tuple(str(member) for member in members) == CLIENT_RUST_MEMBERS,
        "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_RUST_WORKSPACE_MEMBERS",
    )
    require(
        FORBIDDEN_RUST_MEMBERS.isdisjoint({str(member) for member in members}),
        "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_RUST_INTERNAL_MEMBER",
    )
    for relative in [
        "core/rust/Cargo.lock",
        "core/rust/rust-toolchain.toml",
        "core/rust/grain-core/Cargo.toml",
        "core/rust/grain-client-core/Cargo.toml",
        "core/rust/grain-client-core/src/grain_client_core.udl",
        "core/rust/grain-client-wasm/Cargo.toml",
    ]:
        require(
            (vendor_root / relative).is_file(),
            f"EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_RUST_INPUT_MISSING: {relative}",
        )


def native_library_path(vendor_root: Path) -> Path:
    system = platform.system()
    if system == "Darwin":
        name = "libgrain_client_core.dylib"
    elif system == "Linux":
        name = "libgrain_client_core.so"
    elif system.startswith(("MINGW", "MSYS", "CYGWIN")) or system == "Windows":
        name = "grain_client_core.dll"
    else:
        raise SystemExit(f"EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_UNSUPPORTED_OS: {system}")
    return vendor_root / "core/rust/target/debug" / name


def java_arch() -> str:
    java = shutil.which("java")
    if java is None:
        return ""
    result = subprocess.run(
        [java, "-XshowSettings:properties", "-version"],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    for line in result.stdout.splitlines():
        if "os.arch" not in line or "=" not in line:
            continue
        return line.split("=", 1)[1].strip()
    return ""


def kotlin_rust_target() -> str | None:
    if platform.system() != "Darwin":
        return None
    if platform.machine() != "arm64":
        return None
    if java_arch() in {"x86_64", "amd64"}:
        return "x86_64-apple-darwin"
    return None


def build_rust_client_core(vendor_root: Path, *, target: str | None, strict: bool) -> Path:
    cargo = shutil.which("cargo")
    if cargo is None:
        skip_or_fail(strict, "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_CARGO_MISSING", "cargo command not found")
        return native_library_path(vendor_root)

    if target is not None:
        rustup = shutil.which("rustup")
        if rustup is None:
            skip_or_fail(
                strict,
                "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_RUSTUP_MISSING",
                f"rustup is required to install Rust target {target}",
            )
        else:
            run_command("Rust target for Android JVM from release asset", [rustup, "target", "add", target])

    command = [
        cargo,
        "build",
        "--manifest-path",
        str(vendor_root / "core/rust/Cargo.toml"),
        "-p",
        "grain-client-core",
    ]
    if target is not None:
        command.extend(["--target", target])
    run_command("rust client core from release asset", command)
    if target is None:
        return native_library_path(vendor_root)

    system = platform.system()
    if system == "Darwin":
        name = "libgrain_client_core.dylib"
    elif system == "Linux":
        name = "libgrain_client_core.so"
    elif system.startswith(("MINGW", "MSYS", "CYGWIN")) or system == "Windows":
        name = "grain_client_core.dll"
    else:
        raise SystemExit(f"EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_UNSUPPORTED_OS: {system}")
    return vendor_root / "core/rust/target" / target / "debug" / name


def run_smoke_commands(*, consumer_root: Path, strict: bool) -> tuple[str, ...]:
    vendor_root = consumer_root / "vendor/grain-sdk"
    checks: list[str] = ["extract-layout", "rust-workspace-policy"]
    env = os.environ.copy()
    env.setdefault("COPYFILE_DISABLE", "1")

    cargo = shutil.which("cargo")
    kotlin_target = kotlin_rust_target()
    if cargo is not None:
        swift_library_path = build_rust_client_core(vendor_root, target=None, strict=strict)
        kotlin_library_path = swift_library_path
        if kotlin_target is not None:
            kotlin_library_path = build_rust_client_core(vendor_root, target=kotlin_target, strict=strict)
        checks.append("rust-client-core-build")
    else:
        skip_or_fail(strict, "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_CARGO_MISSING", "cargo command not found")
        kotlin_library_path = native_library_path(vendor_root)

    node = shutil.which("npm")
    if node:
        run_command(
            "web starter from release asset",
            [node, "--prefix", str(vendor_root / "templates/web-wasm-starter"), "run", "check"],
            env=env,
        )
        checks.append("web-starter-smoke")
        run_command(
            "TypeScript SDK external consumer from release asset",
            [
                sys.executable,
                str(ROOT / "tools/ci/check_npm_release_dry_run.py"),
                "--vendor-root",
                str(vendor_root),
                "--fixture",
                str(vendor_root / "fixtures/external-consumers/npm-sdk"),
                "--out-dir",
                str(consumer_root / ".scratch/npm-release-dry-run"),
                "--build",
                "--consumer-smoke",
            ],
            env=env,
        )
        checks.append("typescript-sdk-smoke")
    else:
        skip_or_fail(strict, "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_NPM_MISSING", "npm command not found")

    swift = shutil.which("swift")
    if swift:
        run_command(
            "iOS starter from release asset",
            [
                swift,
                "run",
                "--package-path",
                str(vendor_root / "templates/ios-starter"),
                "--scratch-path",
                str(consumer_root / ".scratch/ios-starter-build"),
                "GrainIOSStarterSmoke",
            ],
            env=env,
        )
        checks.append("ios-starter-smoke")
    else:
        skip_or_fail(strict, "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_SWIFT_MISSING", "swift command not found")

    gradlew = vendor_root / "sdk/kotlin/gradlew"
    if shutil.which("java") and gradlew.is_file():
        gradlew.chmod(gradlew.stat().st_mode | 0o111)
        if not kotlin_library_path.exists():
            if not skip_or_fail(
                strict,
                "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_ANDROID_NATIVE_LIBRARY_MISSING",
                f"native library for Android JVM smoke not found at {kotlin_library_path}",
            ):
                return tuple(checks)
        command = [
            str(gradlew),
            "-p",
            str(vendor_root / "templates/android-starter"),
            "--project-cache-dir",
            str(consumer_root / ".scratch/gradle-cache"),
            "--no-daemon",
            f"-Dgrain.kotlin.buildDir={consumer_root / '.scratch/android-starter-build'}",
        ]
        library_path = kotlin_library_path
        if library_path.exists():
            command.append(f"-Dgrain.kotlin.rustDebugLibrary={library_path}")
        command.append("check")
        run_command("Android starter from release asset", command, env=env)
        checks.append("android-starter-smoke")
    else:
        skip_or_fail(
            strict,
            "EXTERNAL_RELEASE_CONSUMER_SMOKE_ERR_ANDROID_PREREQ_MISSING",
            "java command or packaged sdk/kotlin/gradlew not found",
        )

    return tuple(checks)


def check_external_release_consumer_smoke(
    *,
    release_dir: Path,
    expected_commit: str | None = None,
    consumer_root: Path | None = None,
    strict: bool = False,
    run_commands: bool = True,
) -> ExternalReleaseConsumerSmokeResult:
    result = consumer_templates.check_external_consumer_templates(
        release_dir=release_dir,
        expected_commit=expected_commit,
        consumer_root=consumer_root,
    )
    vendor_root = result.consumer_root / "vendor/grain-sdk"
    validate_rust_workspace(vendor_root)
    checks = ("extract-layout", "rust-workspace-policy")
    if run_commands:
        checks = run_smoke_commands(consumer_root=result.consumer_root, strict=strict)
    return ExternalReleaseConsumerSmokeResult(
        commit=result.commit,
        consumer_root=result.consumer_root,
        checks=checks,
    )


def main() -> int:
    args = parse_args()
    if args.consumer_root:
        result = check_external_release_consumer_smoke(
            release_dir=Path(args.out_dir),
            expected_commit=args.expected_commit,
            consumer_root=Path(args.consumer_root),
            strict=args.strict,
            run_commands=not args.layout_only,
        )
    else:
        with tempfile.TemporaryDirectory(prefix="grain-release-consumer-smoke.") as tmp:
            result = check_external_release_consumer_smoke(
                release_dir=Path(args.out_dir),
                expected_commit=args.expected_commit,
                consumer_root=Path(tmp) / "consumer",
                strict=args.strict,
                run_commands=not args.layout_only,
            )
    print(
        "External release consumer smoke: OK "
        f"({len(result.checks)} checks, commit {result.commit})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
