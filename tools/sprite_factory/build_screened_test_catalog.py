"""Create a local, hash-bound catalog for the screened 3D test cohort.

This does not copy scenes, install a launcher pack, change Settings, or alter
the reviewed/portable model-pack boundary.  The resulting catalog points at the
retained local review scenes and is intentionally useful only on this machine.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).parents[2]
SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
REVIEW = ROOT / "tools/sprite_factory/cohort_runtime_visual_review_results.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_path(worktree: Path, raw: str) -> Path:
    # Historical cohort evidence was produced once from the paired-slot root
    # and once from frontend itself. Resolve both recorded forms explicitly.
    if raw.startswith("frontend/"):
        return (worktree / raw.removeprefix("frontend/")).resolve()
    return (worktree.parent / raw).resolve()


def build(output: Path, worktree: Path = ROOT) -> Path:
    output, worktree = output.resolve(), worktree.resolve()
    if output.exists() or output.is_symlink():
        raise ValueError("Output catalog already exists")
    screened = json.loads(SCREENED.read_text())
    review = json.loads(REVIEW.read_text())
    if (screened.get("schema") != 1
            or screened.get("source_visual_review_sha256") != digest(REVIEW)):
        raise ValueError("Screened registry is not bound to the visual review")
    entries = []
    seen = set()
    for row in review.get("entries", []):
        if row.get("classification") != "visual_pass":
            continue
        species = row.get("species")
        model = screened.get("models", {}).get(species, {})
        # Existing official models stay in their reviewed package; do not
        # substitute a screened scene for a known reviewed control.
        if not model:
            continue
        if species in seen or model.get("sha256") != row.get("runtime_sha256"):
            raise ValueError("Screened model identity/hash mismatch: " + str(species))
        source = source_path(worktree, str(row.get("runtime_path", "")))
        if not source.is_file() or source.is_symlink() or digest(source) != model["sha256"]:
            raise ValueError("Screened scene missing or changed: " + str(species))
        entries.append({"species": species, "variant": "normal", "runtime_schema": 1,
                        "runtime_path": str(source), "runtime_sha256": model["sha256"]})
        seen.add(species)
    if len(entries) != len(screened.get("models", {})) or not entries:
        raise ValueError("Incomplete screened cohort")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(sorted(entries, key=lambda row: row["species"]), indent=2) + "\n")
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="new local catalog JSON path")
    parser.add_argument("--worktree", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        print(build(args.output, args.worktree))
    except (OSError, TypeError, ValueError, KeyError) as error:
        parser.exit(1, "Screened catalog rejected: " + str(error) + "\n")


if __name__ == "__main__":
    main()
