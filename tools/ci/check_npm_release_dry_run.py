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
DEFAULT_FIXTURE = ROOT / "fixtures/external-consumers/npm-sdk"
PACKAGES = {
    "grain-ts-core": ROOT / "core/ts/grain-ts-core",
    "grain-sdk-ts": ROOT / "core/ts/grain-sdk",
    "grain-sdk-ai-ts": ROOT / "core/ts/grain-sdk-ai",
}
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
    parser.add_argument("--fixture", default=str(DEFAULT_FIXTURE))
    parser.add_argument("--out-dir", help="Output directory for optional build/pack metadata.")
    parser.add_argument("--build", action="store_true", help="Build local packages and run npm pack --dry-run.")
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"NPM_RELEASE_DRY_RUN_ERR_FILE_MISSING: {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(data, dict), f"NPM_RELEASE_DRY_RUN_ERR_JSON_OBJECT: {path}")
    return data


def validate_package_exports(package_name: str, package_dir: Path, *, require_dist: bool) -> None:
    package_json = load_json(package_dir / "package.json")
    require(package_json.get("name") == package_name, f"NPM_RELEASE_DRY_RUN_ERR_PACKAGE_NAME: {package_name}")
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


def validate_fixture(fixture: Path) -> None:
    package_json = load_json(fixture / "package.json")
    require(package_json.get("private") is True, "NPM_RELEASE_DRY_RUN_ERR_FIXTURE_PRIVATE")
    dependencies = package_json.get("dependencies")
    require(isinstance(dependencies, dict), "NPM_RELEASE_DRY_RUN_ERR_FIXTURE_DEPS")
    require(set(PACKAGES).issubset(set(dependencies)), "NPM_RELEASE_DRY_RUN_ERR_FIXTURE_DEP_SET")
    for name in PACKAGES:
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


def build_and_pack(out_dir: Path) -> dict[str, Any]:
    require(shutil.which("npm") is not None, "NPM_RELEASE_DRY_RUN_ERR_NPM_MISSING")
    out_dir.mkdir(parents=True, exist_ok=True)
    packages: list[dict[str, Any]] = []

    for name, path in PACKAGES.items():
        if (path / "package-lock.json").is_file():
            run(["npm", "ci", "--prefix", str(path)], cwd=ROOT)
        run(["npm", "--prefix", str(path), "run", "build", "--silent"], cwd=ROOT)
        validate_package_exports(name, path, require_dist=True)
        raw = run(["npm", "pack", "--dry-run", "--json", "--pack-destination", str(out_dir)], cwd=path)
        pack = json.loads(raw)
        require(isinstance(pack, list) and pack, f"NPM_RELEASE_DRY_RUN_ERR_PACK_JSON: {name}")
        info = pack[0]
        require(info.get("name") == name, f"NPM_RELEASE_DRY_RUN_ERR_PACK_NAME: {name}")
        packages.append(
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
        "packages": packages,
    }
    (out_dir / "npm-release-dry-run.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )
    return result


def main() -> int:
    args = parse_args()
    fixture = Path(args.fixture).resolve()
    validate_fixture(fixture)
    for name, path in PACKAGES.items():
        validate_package_exports(name, path, require_dist=False)

    if args.build:
        out_dir = Path(args.out_dir).resolve() if args.out_dir else Path(tempfile.mkdtemp(prefix="grain-npm-dry-run."))
        result = build_and_pack(out_dir)
        print(f"npm release dry-run: OK ({len(result['packages'])} packages)")
    else:
        print("npm release dry-run metadata: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
