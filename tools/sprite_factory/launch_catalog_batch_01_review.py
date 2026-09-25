#!/usr/bin/env python3
"""Open the local 14-pair battle review in the development game."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]
CATALOG = Path("/home/adinho/Documents/3d_models/PokeAether/catalog-batch-01-paired-review-v1/catalog.json")
QUALIFICATION = ROOT / "tools/sprite_factory/catalog_production_batch_01_shiny_qualification.json"
REGISTRY = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
APPROVED = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
APPROVAL = ROOT / "tools/sprite_factory/catalog_production_batch_01_approval.json"


def main() -> None:
    if not CATALOG.is_file():
        raise SystemExit(f"Review catalog missing: {CATALOG}")
    manifest = json.loads((CATALOG.parent / "review-manifest.json").read_text())
    registry = json.loads(REGISTRY.read_text())
    approved = json.loads(APPROVED.read_text())
    approved_record = json.loads(APPROVAL.read_text())
    staged = registry.get("catalog_batch_01_qualification_sha256") == manifest["qualification_sha256"]
    promoted = (approved.get("catalog_batch_01_approval_sha256") == hashlib.sha256(APPROVAL.read_bytes()).hexdigest()
                and approved_record.get("qualification_sha256") == manifest["qualification_sha256"])
    if (hashlib.sha256(CATALOG.read_bytes()).hexdigest() != manifest["catalog_sha256"]
            or hashlib.sha256(QUALIFICATION.read_bytes()).hexdigest() != manifest["qualification_sha256"]
            or not (staged or promoted)):
        raise SystemExit("Review catalog does not match this development game")
    env = os.environ.copy()
    env["POKEAETHER_BATCH01_RUNTIME_CATALOG"] = str(CATALOG)
    raise SystemExit(subprocess.run(["godot", "--path", str(ROOT), "--script",
        "res://tools/sprite_factory/catalog_batch_01_live_review.gd"], env=env).returncode)


if __name__ == "__main__":
    main()
