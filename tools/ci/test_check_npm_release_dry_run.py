#!/usr/bin/env python3
"""Focused tests for the npm release dry-run checker."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools" / "ci" / "check_npm_release_dry_run.py"


def load_module():
    spec = importlib.util.spec_from_file_location("check_npm_release_dry_run", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise AssertionError("Could not load check_npm_release_dry_run.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class NpmReleaseDryRunTests(unittest.TestCase):
    def test_repo_fixture_and_package_exports_pass_static_check(self) -> None:
        module = load_module()
        module.validate_fixture(module.DEFAULT_FIXTURE)
        for name, path in module.PACKAGES.items():
            module.validate_package_exports(name, path, require_dist=False)

    def test_vendor_root_fixture_layout_passes_static_check(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            vendor_root = Path(tmp) / "vendor" / "grain-sdk"
            fixture = vendor_root / "fixtures/external-consumers/npm-sdk"
            (fixture / "src").mkdir(parents=True)
            for name, relative in module.PACKAGE_RELATIVE_PATHS.items():
                package_dir = vendor_root / relative
                package_dir.mkdir(parents=True)
                (package_dir / "package.json").write_text(
                    json.dumps(
                        {
                            "name": name,
                            "version": "0.0.0",
                            "files": ["dist"],
                            "exports": {
                                ".": {
                                    "types": "./dist/src/index.d.ts",
                                    "default": "./dist/src/index.js",
                                }
                            },
                        }
                    )
                    + "\n",
                    encoding="utf-8",
                )

            (fixture / "package.json").write_text(
                json.dumps(
                    {
                        "private": True,
                        "dependencies": {
                            "grain-ts-core": "file:../../../core/ts/grain-ts-core",
                            "grain-sdk-ts": "file:../../../core/ts/grain-sdk",
                            "grain-sdk-ai-ts": "file:../../../core/ts/grain-sdk-ai",
                        },
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            (fixture / "tsconfig.json").write_text("{}\n", encoding="utf-8")
            (fixture / "src/import-smoke.ts").write_text(
                'import "grain-sdk-ts";\nimport "grain-sdk-ts/errors";\nimport "grain-sdk-ai-ts";\n',
                encoding="utf-8",
            )
            (fixture / "src/runtime-smoke.mjs").write_text(
                'await import("grain-sdk-ts");\nawait import("grain-sdk-ts/errors");\nawait import("grain-sdk-ai-ts");\n',
                encoding="utf-8",
            )

            packages = module.package_paths(vendor_root)
            module.validate_fixture(fixture, packages)
            for name, path in packages.items():
                module.validate_package_exports(name, path, require_dist=False)

    def test_rejects_internal_fixture_import(self) -> None:
        module = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            fixture = Path(tmp) / "fixture"
            (fixture / "src").mkdir(parents=True)
            (fixture / "package.json").write_text(
                json.dumps(
                    {
                        "private": True,
                        "dependencies": {
                            "grain-ts-core": "file:../../../core/ts/grain-ts-core",
                            "grain-sdk-ts": "file:../../../core/ts/grain-sdk",
                            "grain-sdk-ai-ts": "file:../../../core/ts/grain-sdk-ai",
                        },
                    }
                )
                + "\n",
                encoding="utf-8",
            )
            (fixture / "tsconfig.json").write_text("{}\n", encoding="utf-8")
            (fixture / "src/import-smoke.ts").write_text(
                'import "../../core/ts/grain-sdk/src/index.ts";\n'
                'import "grain-sdk-ts";\n'
                'import "grain-sdk-ts/errors";\n'
                'import "grain-sdk-ai-ts";\n',
                encoding="utf-8",
            )
            (fixture / "src/runtime-smoke.mjs").write_text(
                'await import("grain-sdk-ts");\nawait import("grain-sdk-ts/errors");\nawait import("grain-sdk-ai-ts");\n',
                encoding="utf-8",
            )

            with self.assertRaisesRegex(SystemExit, "NPM_RELEASE_DRY_RUN_ERR_FIXTURE_INTERNAL_IMPORT"):
                module.validate_fixture(fixture)


if __name__ == "__main__":
    unittest.main()
