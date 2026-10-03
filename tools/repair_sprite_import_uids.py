#!/usr/bin/env python3
"""Give copied Pokemon sprite imports distinct UIDs without touching image data.

Run with --apply while Godot is closed, then reopen the editor to reimport.
Only duplicate UID lines in generated sprite .import metadata are removed.
Godot assigns new UIDs on the next import; existing unique UIDs are preserved.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import re

UID_LINE = re.compile(r'^uid="(uid://[^"\n]+)"\r?\n', re.MULTILINE)


def repair(project: Path, apply: bool = False) -> int:
    root = project / "assets/sprites/pokemon"
    if not root.is_dir():
        raise ValueError(f"Missing sprite directory: {root}")
    imports: dict[str, list[Path]] = defaultdict(list)
    for path in sorted(root.rglob("*.import")):
        if path.is_symlink():
            continue
        match = UID_LINE.search(path.read_text())
        if match:
            imports[match[1]].append(path)
    count = 0
    for paths in imports.values():
        # Preserve the regular sprite UID before aliases in optional Gen5 packs.
        paths.sort(key=lambda path: ("gen5" in path.relative_to(root).parts, str(path)))
        for path in paths[1:]:
            print(f"{'Repair' if apply else 'Would repair'} {path.relative_to(project)}")
            if apply:
                path.write_text(UID_LINE.sub("", path.read_text(), count=1))
            count += 1
    print(f"{'Repaired' if apply else 'Found'} {count} duplicate sprite import UIDs")
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    repair(args.project.resolve(), args.apply)


if __name__ == "__main__":
    main()
