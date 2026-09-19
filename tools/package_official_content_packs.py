#!/usr/bin/env python3
"""Build and optionally publish the official cosmetic content packs.

The generated catalog is consumed by the desktop launcher's Mods > Discover tab.
R2 publication is opt-in: this script never uploads unless --upload is supplied.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "builds" / "content-packs"
DEFAULT_BASE_URL = "https://updates.pokeaether.com"


@dataclass(frozen=True)
class ContentPack:
    pack_id: str
    name: str
    description: str
    source_dir: Path
    archive_root: str


PACKS: tuple[ContentPack, ...] = (
    ContentPack(
        "anime-cries",
        "Anime Cries",
        "Anime cries for available Pokémon from Generations 1–7.",
        PROJECT_ROOT / "assets" / "audio" / "sfx" / "pokemon_anime_cries",
        "cries",
    ),
    ContentPack(
        "gen5-animated-sprites",
        "Gen 5 Animated Sprites",
        "The complete animated Generation 5 battle-sprite collection, including shiny variants.",
        PROJECT_ROOT / "assets" / "sprites" / "pokemon" / "gen5",
        "sprites/gen5",
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack", action="append", choices=[pack.pack_id for pack in PACKS])
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--catalog-output", type=Path)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--version-label", default="", help="Optional shared version suffix, e.g. v1.")
    parser.add_argument("--updated-at", default=date.today().isoformat(), help="Catalog update date in YYYY-MM-DD format.")
    parser.add_argument("--upload", action="store_true", help="Upload immutable zips and catalog to configured R2.")
    return parser.parse_args()


def source_files(pack: ContentPack) -> list[Path]:
    if not pack.source_dir.is_dir():
        raise SystemExit(f"Missing source folder for {pack.pack_id}: {pack.source_dir}")
    allowed = {".ogg"} if pack.pack_id == "anime-cries" else {".png", ".json"}
    files = sorted(path for path in pack.source_dir.rglob("*") if path.is_file() and path.suffix in allowed)
    if not files:
        raise SystemExit(f"No packageable source files for {pack.pack_id}")
    return files


def content_hash(pack: ContentPack, files: list[Path]) -> str:
    digest = hashlib.sha256()
    digest.update(pack.pack_id.encode())
    for path in files:
        digest.update(path.relative_to(pack.source_dir).as_posix().encode())
        digest.update(b"\0")
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        digest.update(b"\0")
    return digest.hexdigest()


def pack_manifest(pack: ContentPack, version: str, files: list[Path]) -> dict[str, object]:
    assets: dict[str, object]
    if pack.pack_id == "anime-cries":
        assets = {
            "cries": {
                path.stem: {"file": f"cries/{path.name}"}
                for path in files
            }
        }
    else:
        assets = {"sprite_collections": {"gen5": {"directory": "sprites", "style": "gen5"}}}
    return {
        "format_version": 1,
        "id": pack.pack_id,
        "name": pack.name,
        "version": version,
        "author": "PokeAether",
        "description": pack.description,
        "assets": assets,
    }


def write_zip(output: Path, pack: ContentPack, files: list[Path], manifest: dict[str, object]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(output, "w", ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr("mod.json", json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
        for path in files:
            archive_path = f"{pack.archive_root}/{path.relative_to(pack.source_dir).as_posix()}"
            info = ZipInfo.from_file(path, archive_path)
            info.compress_type = ZIP_DEFLATED
            info.external_attr = (path.stat().st_mode & 0xFFFF) << 16
            with path.open("rb") as handle:
                archive.writestr(info, handle.read())


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_pack(pack: ContentPack, output_dir: Path, base_url: str, version_label: str, updated_at: str) -> dict[str, object]:
    files = source_files(pack)
    suffix = version_label.strip() or content_hash(pack, files)[:12]
    version = f"{pack.pack_id}-{suffix}"
    output = output_dir / f"{version}.zip"
    manifest = pack_manifest(pack, version, files)
    if output.is_file():
        with ZipFile(output) as archive:
            existing_manifest = json.loads(archive.read("mod.json"))
        if existing_manifest != manifest:
            raise SystemExit(f"Refusing to reuse incompatible immutable archive: {output}")
    else:
        write_zip(output, pack, files, manifest)
    return {
        "id": pack.pack_id,
        "name": pack.name,
        "version": version,
        "author": "PokeAether",
        "description": pack.description,
        "updated_at": updated_at,
        "categories": list(manifest["assets"].keys()),
        "download": {
            "url": f"{base_url.rstrip('/')}/mods/{output.name}",
            "sha256": sha256(output),
            "size_bytes": output.stat().st_size,
        },
    }


def upload(output_dir: Path, catalog_path: Path, catalog: dict[str, object]) -> None:
    sys.path.insert(0, str(PROJECT_ROOT / "tools"))
    from upload_launcher_release import _load_config, _upload_file

    config = _load_config()
    for pack in catalog["packs"]:
        filename = Path(str(pack["download"]["url"])).name
        _upload_file(config, output_dir / filename, f"mods/{filename}")
    _upload_file(config, catalog_path, "data/content-packs.json")


def main() -> None:
    args = parse_args()
    try:
        updated_at = date.fromisoformat(args.updated_at).isoformat()
    except ValueError as error:
        raise SystemExit("--updated-at must be a valid YYYY-MM-DD date.") from error
    selected = [pack for pack in PACKS if pack.pack_id in set(args.pack or [item.pack_id for item in PACKS])]
    if args.upload and len(selected) != len(PACKS):
        raise SystemExit("R2 catalog publication requires building every official pack.")
    output_dir = args.output_dir.resolve()
    catalog_path = (args.catalog_output or output_dir / "content-packs.json").resolve()
    catalog = {
        "format_version": 1,
        "packs": [build_pack(pack, output_dir, args.base_url, args.version_label, updated_at) for pack in selected],
    }
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for pack in catalog["packs"]:
        download = pack["download"]
        print(f"{pack['id']}: {pack['version']} ({download['size_bytes']} bytes, {download['sha256']})")
    print(f"Catalog: {catalog_path}")
    if args.upload:
        upload(output_dir, catalog_path, catalog)
        print("Published official content packs and catalog to R2.")


if __name__ == "__main__":
    main()
