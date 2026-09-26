#!/usr/bin/env python3
"""Open the 81 hash-pinned normal models for local Pokédex/summary review."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT.parents[2] if ROOT.parent.name == "slot-b" else ROOT.parent
CATALOG = Path.home() / "Documents/3d_models/PokeAether/catalog-production-02-review/catalog.json"
EVIDENCE = ROOT / "tools/sprite_factory/catalog_production_batch_02_results.json"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def validate(catalog: Path = CATALOG) -> list[dict]:
    evidence = json.loads(EVIDENCE.read_text())
    expected = {row["species"]: row for row in evidence["entries"] if row["visual_review"] == "pending"}
    if (len(expected) != 81 or evidence["runtime_approved"] is not False
            or evidence["standalone_models"] != 81):
        raise ValueError("batch-02 technical evidence is incomplete")
    entries = json.loads(catalog.read_text())
    if not isinstance(entries, list) or len(entries) != 81:
        raise ValueError("local review catalog needs exactly 81 entries")
    seen = set()
    for entry in entries:
        name = entry["species"]
        if (name in seen or name not in expected or entry["variant"] != "normal"
                or entry["runtime_schema"] != 1):
            raise ValueError("unexpected or duplicate review identity: " + name)
        seen.add(name)
        source = Path(entry["runtime_path"])
        if (not source.is_absolute() or source.is_symlink() or not source.is_file()
                or entry["runtime_sha256"] != expected[name]["runtime_sha256"]
                or digest(source) != expected[name]["runtime_sha256"]):
            raise ValueError("review scene differs from pinned evidence: " + name)
    if seen != set(expected):
        raise ValueError("local review catalog is incomplete")
    return entries


def main() -> None:
    validate()
    env = os.environ.copy()
    env["POKEAETHER_PREVIEW_REVIEW_CATALOG"] = str(CATALOG)
    raise SystemExit(subprocess.run([
        str(WORKSPACE / "ops/worktrees/slot-env"), "slot-b", "--",
        "godot", "--path", str(ROOT)
    ], env=env).returncode)


if __name__ == "__main__":
    main()
