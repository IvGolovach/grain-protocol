#!/usr/bin/env python3
"""Validate the repo-local npm external consumer fixture and optional pack dry-run."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_RELATIVE = Path("fixtures/external-consumers/npm-sdk")
DEFAULT_FIXTURE = ROOT / FIXTURE_RELATIVE
PACKAGE_RELATIVE_PATHS = {
    "grain-ts-core": Path("core/ts/grain-ts-core"),
    "grain-sdk-ts": Path("core/ts/grain-sdk"),
    "grain-sdk-ai-ts": Path("core/ts/grain-sdk-ai"),
}
PACKAGES = {name: ROOT / relative for name, relative in PACKAGE_RELATIVE_PATHS.items()}
PUBLIC_IMPORT_TOKENS = {
    "grain-sdk-ts",
    "grain-sdk-ts/errors",
    "grain-sdk-ai-ts",
}
FORBIDDEN_IMPORT_TOKENS = (
    "core/ts/",
    "dist/src/",
    "../",
    "../../",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument(
        "--vendor-root",
        default=str(ROOT),
        help="Root containing core/ts packages and the external npm fixture.",
    )
    parser.add_argument("--fixture")
    parser.add_argument("--out-dir", help="Output directory for optional build/pack metadata.")
    parser.add_argument("--build", action="store_true", help="Build local packages and run npm pack --dry-run.")
    parser.add_argument(
        "--consumer-smoke",
        action="store_true",
        help="After --build, install/typecheck/runtime-smoke the fixture from a scratch external layout.",
    )
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"NPM_RELEASE_DRY_RUN_ERR_FILE_MISSING: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data, dict), f"NPM_RELEASE_DRY_RUN_ERR_JSON_OBJECT: {path}")
    return data


def package_paths(vendor_root: Path) -> dict[str, Path]:
    return {name: vendor_root / relative for name, relative in PACKAGE_RELATIVE_PATHS.items()}


def validate_package_exports(package_name: str, package_dir: Path, *, require_dist: bool) -> None:
    package_json = load_json(package_dir / "package.json")
    require(package_json.get("name") == package_name, f"NPM_RELEASE_DRY_RUN_ERR_PACKAGE_NAME: {package_name}")
    files = package_json.get("files")
    require(
        isinstance(files, list) and "dist" in {str(item) for item in files},
        f"NPM_RELEASE_DRY_RUN_ERR_PACKAGE_FILES: {package_name}",
    )
    exports = package_json.get("exports")
    require(isinstance(exports, dict) and exports, f"NPM_RELEASE_DRY_RUN_ERR_EXPORTS: {package_name}")
    for export_name, target in exports.items():
        require(isinstance(target, dict), f"NPM_RELEASE_DRY_RUN_ERR_EXPORT_TARGET: {package_name}:{export_name}")
        for key in ("types", "default"):
            value = target.get(key)
            require(isinstance(value, str) and value.startswith("./dist/"), f"NPM_RELEASE_DRY_RUN_ERR_EXPORT_PATH: {package_name}:{export_name}:{key}")
            if require_dist:
                if "*" in value:
                    pattern = value.removeprefix("./")
                    require(
                        any(package_dir.glob(pattern)),
                        f"NPM_RELEASE_DRY_RUN_ERR_EXPORT_FILE: {package_name}:{value}",
                    )
                else:
                    require((package_dir / value).is_file(), f"NPM_RELEASE_DRY_RUN_ERR_EXPORT_FILE: {package_name}:{value}")


def validate_fixture(fixture: Path, packages: dict[str, Path] | None = None) -> None:
    packages = packages or PACKAGES
    package_json = load_json(fixture / "package.json")
    require(package_json.get("private") is True, "NPM_RELEASE_DRY_RUN_ERR_FIXTURE_PRIVATE")
    dependencies = package_json.get("dependencies")
    require(isinstance(dependencies, dict), "NPM_RELEASE_DRY_RUN_ERR_FIXTURE_DEPS")
    require(set(packages).issubset(set(dependencies)), "NPM_RELEASE_DRY_RUN_ERR_FIXTURE_DEP_SET")
    for name in packages:
        value = dependencies.get(name)
        require(isinstance(value, str) and value.startswith("file:../../../core/ts/"), f"NPM_RELEASE_DRY_RUN_ERR_FIXTURE_DEP: {name}")

    for relative in ("tsconfig.json", "src/import-smoke.ts", "src/runtime-smoke.mjs"):
        require((fixture / relative).is_file(), f"NPM_RELEASE_DRY_RUN_ERR_FIXTURE_FILE: {relative}")

    source = (fixture / "src/import-smoke.ts").read_text(encoding="utf-8")
    runtime = (fixture / "src/runtime-smoke.mjs").read_text(encoding="utf-8")
    combined = source + "\n" + runtime
    for token in PUBLIC_IMPORT_TOKENS:
        require(token in combined, f"NPM_RELEASE_DRY_RUN_ERR_FIXTURE_IMPORT: {token}")
    for token in FORBIDDEN_IMPORT_TOKENS:
        require(token not in combined, f"NPM_RELEASE_DRY_RUN_ERR_FIXTURE_INTERNAL_IMPORT: {token}")


def run(command: list[str], *, cwd: Path) -> str:
    proc = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if proc.returncode != 0:
        raise SystemExit(
            "NPM_RELEASE_DRY_RUN_ERR_COMMAND_FAILED: "
            + " ".join(command)
            + f"\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
        )
    return proc.stdout


def build_and_pack(out_dir: Path, packages: dict[str, Path] | None = None) -> dict[str, Any]:
    packages = packages or PACKAGES
    require(shutil.which("npm") is not None, "NPM_RELEASE_DRY_RUN_ERR_NPM_MISSING")
    out_dir.mkdir(parents=True, exist_ok=True)
    package_results: list[dict[str, Any]] = []

    for name, path in packages.items():
        if (path / "package-lock.json").is_file():
            run(["npm", "ci", "--prefix", str(path)], cwd=path)
        run(["npm", "--prefix", str(path), "run", "build", "--silent"], cwd=path)
        validate_package_exports(name, path, require_dist=True)
        raw = run(["npm", "pack", "--dry-run", "--json", "--pack-destination", str(out_dir)], cwd=path)
        pack = json.loads(raw)
        require(isinstance(pack, list) and pack, f"NPM_RELEASE_DRY_RUN_ERR_PACK_JSON: {name}")
        info = pack[0]
        require(info.get("name") == name, f"NPM_RELEASE_DRY_RUN_ERR_PACK_NAME: {name}")
        pack_files = info.get("files", [])
        require(isinstance(pack_files, list), f"NPM_RELEASE_DRY_RUN_ERR_PACK_FILES: {name}")
        pack_paths = {
            str(item.get("path"))
            for item in pack_files
            if isinstance(item, dict) and isinstance(item.get("path"), str)
        }
        require(any(path.startswith("dist/") for path in pack_paths), f"NPM_RELEASE_DRY_RUN_ERR_PACK_DIST: {name}")
        package_results.append(
            {
                "name": name,
                "version": info.get("version"),
                "filename": info.get("filename"),
                "files": len(info.get("files", [])),
            }
        )

    result = {
        "schema": "grain.npm-release-dry-run.v1",
        "publication": "none",
        "packages": package_results,
    }
    return result


def write_result(out_dir: Path, result: dict[str, Any]) -> None:
    (out_dir / "npm-release-dry-run.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )


def relative_to_vendor(path: Path, vendor_root: Path) -> Path:
    try:
        return path.resolve().relative_to(vendor_root.resolve())
    except ValueError as exc:
        raise SystemExit(f"NPM_RELEASE_DRY_RUN_ERR_FIXTURE_OUTSIDE_VENDOR_ROOT: {path}") from exc


def copy_external_consumer_tree(vendor_root: Path, fixture: Path, target_root: Path) -> Path:
    if target_root.exists():
        shutil.rmtree(target_root)
    target_root.mkdir(parents=True)
    ignore = shutil.ignore_patterns("node_modules", "build", ".build", ".gradle", ".kotlin", "target", "pkg")

    for relative in PACKAGE_RELATIVE_PATHS.values():
        source = vendor_root / relative
        require(source.is_dir(), f"NPM_RELEASE_DRY_RUN_ERR_PACKAGE_DIR: {source}")
        (target_root / relative).parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, target_root / relative, ignore=ignore)

    fixture_relative = relative_to_vendor(fixture, vendor_root)
    (target_root / fixture_relative).parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(fixture, target_root / fixture_relative, ignore=ignore)
    return target_root / fixture_relative


def run_consumer_smoke(*, vendor_root: Path, fixture: Path, out_dir: Path) -> dict[str, Any]:
    require(shutil.which("npm") is not None, "NPM_RELEASE_DRY_RUN_ERR_NPM_MISSING")
    scratch_vendor = out_dir / "external-npm-consumer-smoke" / "vendor" / "grain-sdk"
    scratch_fixture = copy_external_consumer_tree(vendor_root, fixture, scratch_vendor)
    run(
        [
            "npm",
            "install",
            "--prefix",
            str(scratch_fixture),
            "--package-lock=false",
            "--install-links=true",
            "--ignore-scripts",
            "--no-audit",
            "--no-fund",
        ],
        cwd=scratch_fixture,
    )
    run(["npm", "--prefix", str(scratch_fixture), "run", "typecheck", "--silent"], cwd=scratch_fixture)
    run(["npm", "--prefix", str(scratch_fixture), "run", "runtime", "--silent"], cwd=scratch_fixture)
    return {
        "fixture": str(relative_to_vendor(fixture, vendor_root)),
        "layout": "external-scratch-copy",
        "typecheck": "pass",
        "runtime": "pass",
    }


def main() -> int:
    args = parse_args()
    vendor_root = Path(args.vendor_root).resolve()
    packages = package_paths(vendor_root)
    fixture = Path(args.fixture).resolve() if args.fixture else vendor_root / FIXTURE_RELATIVE
    validate_fixture(fixture, packages)
    for name, path in packages.items():
        validate_package_exports(name, path, require_dist=False)

    if args.consumer_smoke and not args.build:
        raise SystemExit("NPM_RELEASE_DRY_RUN_ERR_CONSUMER_SMOKE_REQUIRES_BUILD")

    if args.build:
        out_dir = Path(args.out_dir).resolve() if args.out_dir else Path(tempfile.mkdtemp(prefix="grain-npm-dry-run."))
        result = build_and_pack(out_dir, packages)
        if args.consumer_smoke:
            result["consumer_smoke"] = run_consumer_smoke(
                vendor_root=vendor_root,
                fixture=fixture,
                out_dir=out_dir,
            )
        write_result(out_dir, result)
        print(f"npm release dry-run: OK ({len(result['packages'])} packages)")
    else:
        print("npm release dry-run metadata: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
