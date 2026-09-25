#!/usr/bin/env python3
"""Stage batch-01 normal/shiny scenes for explicit local in-game review."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile


ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
LAUNCHER_REGISTRY = ROOT / "launcher/data/screened_model_catalog.json"
QUALIFICATION = ROOT / "tools/sprite_factory/catalog_production_batch_01_shiny_qualification.json"
MOTION = ROOT / ".tmp/catalog-production-01-battle-input-2026-09-25/motion-candidates.json"
NORMAL = ROOT / ".tmp/catalog-production-01-runtime/report.json"
SHINY = ROOT / ".tmp/catalog-production-01-shiny-runtime-2026-09-25/report.json"


def digest(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def encode(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def prepare(catalog: Path, output: Path) -> dict:
    catalog, output = catalog.resolve(), output.absolute()
    if output.exists() or output.is_symlink():
        raise ValueError("review output already exists")
    qualification = json.loads(QUALIFICATION.read_text())
    qualified = {item["species"]: item for item in qualification["entries"]}
    if (qualification.get("release_approved") is not False or len(qualified) != 14
            or len(qualification.get("material_holds", [])) != 4):
        raise ValueError("batch-01 candidate qualification is incomplete")
    for name, expected in qualification["evidence_sha256"].items():
        if digest(ROOT / name) != expected:
            raise ValueError(f"candidate evidence changed: {name}")
    motions = json.loads(MOTION.read_text())["motion"]
    normals = {item["species"]: item for item in json.loads(NORMAL.read_text())}
    shinies = {item["species"].removesuffix("@shiny"): item for item in json.loads(SHINY.read_text())}
    entries = json.loads(catalog.read_text())
    expected_keys = set(qualified) | {species + "@shiny" for species in qualified}
    keys = {item["species"] + ("@shiny" if item["variant"] == "shiny" else "") for item in entries}
    if len(entries) != 28 or keys != expected_keys or set(shinies) != set(qualified):
        raise ValueError("paired review catalog is incomplete")
    original = REGISTRY.read_bytes()
    if LAUNCHER_REGISTRY.read_bytes() != original:
        raise ValueError("game and launcher screened registries differ")
    registry = json.loads(original)
    already_staged = registry.get("catalog_batch_01_pairs") is not None
    if already_staged:
        if (set(registry["catalog_batch_01_pairs"]) != set(qualified)
                or len(registry["models"]) != 103 or registry.get("normal_only") is not False):
            raise ValueError("existing batch-01 screened registry differs")
    elif (registry.get("normal_only") is not True or len(registry["models"]) != 75
          or set(registry["models"]) & expected_keys):
        raise ValueError("expected the original 75-model screened registry")
    staged = Path(tempfile.mkdtemp(prefix=".catalog-batch-01-review-", dir=output.parent))
    review_entries = []
    try:
        for entry in sorted(entries, key=lambda item: (item["species"], item["variant"])):
            species, variant = entry["species"], entry["variant"]
            identity = species + ("@shiny" if variant == "shiny" else "")
            expected = qualified[species][variant + "_scn_sha256"]
            source = Path(entry["runtime_path"])
            if (entry["runtime_sha256"] != expected or source.is_symlink()
                    or not source.is_file() or digest(source) != expected):
                raise ValueError(f"candidate scene changed: {identity}")
            row = normals[species] if variant == "normal" else shinies[species]
            if row["runtime_sha256"] != expected:
                raise ValueError(f"source report changed: {identity}")
            motion = dict(motions[species])
            if motion["sha256"] != normals[species]["glb_sha256"]:
                raise ValueError(f"motion profile changed: {identity}")
            motion["sha256"] = expected
            placement = {"scale": motion["scale"], "yaw_degrees": motion["yaw_degrees"]}
            grounding = {**placement, "lift": motion["lift"], "sha256": expected}
            registry["models"][identity] = {"sha256": expected, "glb_sha256": row["glb_sha256"], "profile": species}
            profile = {"action_timing": row["action_timing"], "placement": placement,
                "grounding": grounding, "motion": motion}
            if species in registry["profiles"]:
                # Parity-qualified variants share one motion profile. resolve()
                # binds the profile's scene hash to the selected appearance.
                previous = registry["profiles"][species]
                profile["grounding"]["sha256"] = previous["grounding"]["sha256"]
                profile["motion"]["sha256"] = previous["motion"]["sha256"]
                if profile != previous:
                    raise ValueError(f"normal/shiny profile differs: {species}")
            else:
                registry["profiles"][species] = profile
            destination = staged / "models" / (expected + ".scn")
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            if digest(destination) != expected:
                raise ValueError(f"copied scene changed: {identity}")
            review_entries.append({"species": species, "variant": variant, "runtime_schema": 1,
                "runtime_path": str(output / "models" / destination.name), "runtime_sha256": expected})
        registry["normal_only"] = False
        registry["catalog_batch_01_pairs"] = sorted(qualified)
        registry["catalog_batch_01_qualification_sha256"] = digest(QUALIFICATION)
        registry["limitations"] = ["original 75 models have only visual screening and normal forms",
            "batch-01 pairs are local battle-review candidates, not release-approved",
            "not an approved or portable launcher pack"]
        (staged / "catalog.json").write_bytes(encode(review_entries))
        (staged / "review-manifest.json").write_bytes(encode({
            "schema": 1, "kind": "pokeaether-local-3d-review", "release_approved": False,
            "qualification_sha256": digest(QUALIFICATION),
            "catalog_sha256": digest(staged / "catalog.json"),
            "identities": sorted(expected_keys),
        }))
        os.rename(staged, output)
        updated = encode(registry)
        if already_staged and updated != original:
            raise ValueError("existing batch-01 screened registry changed")
        REGISTRY.write_bytes(updated)
        LAUNCHER_REGISTRY.write_bytes(updated)
        return {"catalog": str(output / "catalog.json"), "species": sorted(qualified),
                "catalog_sha256": digest(output / "catalog.json")}
    except BaseException:
        if staged.exists():
            shutil.rmtree(staged)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare(args.catalog, args.output), indent=2))


if __name__ == "__main__":
    main()
