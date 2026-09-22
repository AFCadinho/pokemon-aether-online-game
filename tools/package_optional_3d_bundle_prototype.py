#!/usr/bin/env python3
"""Package the three approved local 3D delivery-prototype bundles.

This is intentionally a local-only delivery tool. It does not upload, select,
install, convert or modify model sources.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
SPECIES = ("arcanine", "dragonite", "roaring-moon")
DEX = {"arcanine": 59, "dragonite": 149, "roaring-moon": 1005}
MAX_SCENE = 128 * 1024 * 1024


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def digest(path: Path) -> tuple[str, int]:
    hashing, size = hashlib.sha256(), 0
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            size += len(chunk)
            if size > MAX_SCENE:
                raise ValueError(f"scene exceeds {MAX_SCENE} bytes: {path}")
            hashing.update(chunk)
    return hashing.hexdigest(), size


def zip_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o644) << 16
    info.compress_type = zipfile.ZIP_STORED
    return info


def identity(entry: dict) -> str:
    species = entry.get("species")
    variant = entry.get("variant", "normal")
    if not isinstance(species, str) or variant not in {"normal", "shiny"}:
        raise ValueError("invalid model identity")
    return species + ("@shiny" if variant == "shiny" else "")


def source_entries(catalog_path: Path) -> dict[str, tuple[dict, Path]]:
    value = json.loads(catalog_path.read_text())
    entries = value if isinstance(value, list) else value.get("entries")
    if not isinstance(entries, list):
        raise ValueError("expected a local or portable model catalog")
    result = {}
    for entry in entries:
        key = identity(entry)
        if key in result:
            raise ValueError(f"duplicate model identity: {key}")
        path = Path(entry.get("runtime_path", ""))
        if not path.is_absolute():
            path = catalog_path.parent / path
        result[key] = (entry, path)
    return result


def approved(registry: dict, key: str, model_hash: str) -> bool:
    model = registry.get("models", {}).get(key, {})
    return model_hash == model.get("sha256") or model_hash in model.get("previous_sha256", [])


def build(catalog_path: Path, output: Path, version: int = 1, revision: str = "prototype-1",
          registry_path: Path = REGISTRY, species_set: tuple[str, ...] = SPECIES,
          dex: dict[str, int] = DEX) -> dict:
    if version < 1:
        raise ValueError("version must be positive")
    if output.exists() or output.is_symlink():
        raise ValueError("output directory already exists")
    source = source_entries(catalog_path)
    registry = json.loads(registry_path.read_text())
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".asset-bundle-prototype-", dir=output.parent))
    assets = []
    try:
        for species in species_set:
            appearances, paths = [], {}
            for variant in ("normal", "shiny"):
                key = species + ("@shiny" if variant == "shiny" else "")
                if key not in source:
                    raise ValueError(f"missing approved prototype appearance: {key}")
                entry, path = source[key]
                if path.is_symlink() or not path.is_file():
                    raise ValueError(f"missing regular scene: {path}")
                scene_hash, size = digest(path)
                if scene_hash != entry.get("runtime_sha256") or not approved(registry, key, scene_hash):
                    raise ValueError(f"unapproved or changed model: {key}")
                runtime_path = f"models/{variant}.scn"
                appearances.append({
                    "variant": variant,
                    "runtime_identity": key,
                    "runtime_path": runtime_path,
                    "runtime_sha256": scene_hash,
                    "bytes": size,
                })
                paths[runtime_path] = path
            asset_id = f"pokemon_3d:{species}:base"
            manifest = {
                "schema": 1,
                "kind": "pokeaether-asset-bundle",
                "asset_id": asset_id,
                "asset_type": "pokemon_3d",
                "species_id": species,
                "form_id": "base",
                "version": version,
                "dependencies": [],
                "appearances": appearances,
            }
            archive = staging / f"{species}-base-v{version}.zip"
            with zipfile.ZipFile(archive, "w", allowZip64=False) as target:
                target.writestr(zip_info("bundle.json"), encoded(manifest))
                for name, path in paths.items():
                    with path.open("rb") as model:
                        target.writestr(zip_info(name), model.read())
            archive_hash, archive_size = digest(archive)
            object_key = f"optional-assets/pokemon_3d/{species}/base/v{version}-{archive_hash}.zip"
            published_archive = archive.with_name(Path(object_key).name)
            archive.rename(published_archive)
            assets.append({
                "asset_id": asset_id,
                "asset_type": "pokemon_3d",
                "species_id": species,
                "national_dex": dex[species],
                "form_id": "base",
                "version": version,
                "size_bytes": archive_size,
                "sha256": archive_hash,
                "object_key": object_key,
                "dependencies": [],
                "appearances": [
                    {key: item[key] for key in ("variant", "runtime_identity", "runtime_sha256")}
                    for item in appearances
                ],
            })
        index = {
            "schema": 1,
            "kind": "pokeaether-optional-asset-index",
            "catalog_revision": revision,
            "runtime_contract": {"pokemon_3d": 1, "godot": "4.6"},
            "assets": assets,
        }
        (staging / "asset-index.json").write_bytes(encoded(index))
        os.rename(staging, output)
        return index
    except BaseException:
        for path in sorted(staging.rglob("*"), reverse=True):
            path.unlink() if path.is_file() else path.rmdir()
        staging.rmdir()
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path, help="Approved portable/local model catalog containing all six appearances.")
    parser.add_argument("output", type=Path, help="New local output directory; never overwritten.")
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--revision", default="prototype-1")
    args = parser.parse_args()
    index = build(args.catalog.resolve(), args.output.absolute(), args.version, args.revision)
    for asset in index["assets"]:
        print(f"{asset['asset_id']}: {asset['size_bytes']} bytes {asset['sha256']}")
    print(f"Index: {args.output.absolute() / 'asset-index.json'}")


if __name__ == "__main__":
    main()
