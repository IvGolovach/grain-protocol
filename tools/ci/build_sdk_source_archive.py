#!/usr/bin/env python3
"""Write reproducible SDK source tar.gz archives without host filesystem metadata."""

from __future__ import annotations

import argparse
import fnmatch
import gzip
import stat
import tarfile
from pathlib import Path, PurePosixPath


def build_archive(
    output: Path, root: Path, paths: list[str], excludes: list[str], source_epoch: int
) -> None:
    if not 0 <= source_epoch <= 0xFFFFFFFF:
        raise ValueError("SDK_ARCHIVE_ERR_SOURCE_EPOCH")
    entries: dict[str, Path] = {}

    def visit(name: str) -> None:
        relative = PurePosixPath(name)
        if relative.is_absolute() or ".." in relative.parts or str(relative) == ".":
            raise ValueError("SDK_ARCHIVE_ERR_PATH")
        if any(fnmatch.fnmatchcase(name if "/" in pattern else relative.name, pattern) for pattern in excludes):
            return
        if any(root.joinpath(*relative.parts[:index]).is_symlink() for index in range(1, len(relative.parts) + 1)):
            raise ValueError(f"SDK_ARCHIVE_ERR_FILE_TYPE: {name}")
        path = root / relative
        mode = path.lstat().st_mode
        if not (stat.S_ISDIR(mode) or stat.S_ISREG(mode)):
            raise ValueError(f"SDK_ARCHIVE_ERR_FILE_TYPE: {name}")
        if name in entries:
            return
        entries[name] = path
        if stat.S_ISDIR(mode):
            for child in path.iterdir():
                visit(f"{name}/{child.name}")

    for name in paths:
        visit(str(PurePosixPath(name)))

    with output.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=source_epoch, compresslevel=9) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                for name, path in sorted(entries.items()):
                    metadata = path.lstat()
                    entry = tarfile.TarInfo(name)
                    entry.mtime = source_epoch
                    entry.uid = entry.gid = 0
                    entry.uname = entry.gname = ""
                    if stat.S_ISDIR(metadata.st_mode):
                        entry.type = tarfile.DIRTYPE
                        entry.mode = 0o755
                        archive.addfile(entry)
                    elif stat.S_ISREG(metadata.st_mode):
                        entry.mode = 0o755 if metadata.st_mode & 0o111 else 0o644
                        entry.size = metadata.st_size
                        with path.open("rb") as source:
                            archive.addfile(entry, source)
                    else:
                        raise ValueError(f"SDK_ARCHIVE_ERR_FILE_TYPE: {name}")


def main() -> int:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-epoch", type=int, required=True)
    parser.add_argument("-C", dest="root", type=Path, required=True)
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()
    build_archive(args.output, args.root, args.paths, args.exclude, args.source_epoch)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
