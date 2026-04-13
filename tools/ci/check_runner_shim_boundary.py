#!/usr/bin/env python3
"""Keep the TypeScript runner as a thin shell over grain-ts-core."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNNER_SRC = ROOT / "runner" / "typescript" / "src"
LOCAL_IMPLEMENTATIONS = {
    Path("cli.ts"),
}


def expected_export(rel_path: Path) -> str:
    module_path = rel_path.with_suffix("").as_posix()
    return f'export * from "grain-ts-core/{module_path}";\n'


def main() -> int:
    bad_files: list[str] = []

    for path in sorted(RUNNER_SRC.rglob("*.ts")):
        rel_path = path.relative_to(RUNNER_SRC)
        if rel_path in LOCAL_IMPLEMENTATIONS:
            continue

        expected = expected_export(rel_path)
        actual = path.read_text(encoding="utf-8")
        if actual != expected:
            bad_files.append(
                f"{rel_path.as_posix()}: expected exact shim `{expected.strip()}`"
            )

    if bad_files:
        details = "\n".join(bad_files)
        raise SystemExit(
            "Runner shim boundary check failed.\n"
            "Shared protocol logic belongs in core/ts/grain-ts-core.\n"
            "Update the allowlist in tools/ci/check_runner_shim_boundary.py only when a runner-local file is intentional.\n"
            f"{details}"
        )

    print("runner shim boundary: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
