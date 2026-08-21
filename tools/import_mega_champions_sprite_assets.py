#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import io
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ASSET_PACK_NAME = "Generation 9 Pack"
ASSET_PACK_VERSION = "3.3.6"
ASSET_PACK_WEBSITE = "https://www.eeveeexpo.com/threads/5817/"
EXPECTED_CREDITS_SHA256 = "d9d782f9f01fbc4f33352619ad48dcd3c83eb72591b436e5a551e6bcaebd6b21"
EXPECTED_CHANGELOG_SHA256 = "2e31d1b30906ba0e907d558def8c48a5eb3a260638217fd5cfbfea731de61f50"
IMPORT_MANIFEST_PATH = PROJECT_ROOT / "data" / "mega_champions_sprite_imports.generated.json"


@dataclass(frozen=True)
class FormAssetMapping:
    catalog_entry_id: str
    showdown_species_name: str
    source_pokemon_id: str
    source_form_index: int

    @property
    def source_stem(self) -> str:
        return f"{self.source_pokemon_id}_{self.source_form_index}"


FORM_ASSET_MAPPINGS: tuple[FormAssetMapping, ...] = (
    FormAssetMapping("absol-mega-z", "Absol-Mega-Z", "ABSOL", 2),
    FormAssetMapping("floette-mega", "Floette-Mega", "FLOETTE", 6),
    FormAssetMapping("garchomp-mega-z", "Garchomp-Mega-Z", "GARCHOMP", 2),
    FormAssetMapping("greninja-mega", "Greninja-Mega", "GRENINJA", 3),
    FormAssetMapping("lucario-mega-z", "Lucario-Mega-Z", "LUCARIO", 2),
    FormAssetMapping("magearna-mega", "Magearna-Mega", "MAGEARNA", 2),
    FormAssetMapping(
        "magearna-original-mega",
        "Magearna-Original-Mega",
        "MAGEARNA",
        3,
    ),
    FormAssetMapping("meowstic-f-mega", "Meowstic-F-Mega", "MEOWSTIC", 3),
    FormAssetMapping("meowstic-m-mega", "Meowstic-M-Mega", "MEOWSTIC", 2),
    FormAssetMapping("raichu-mega-x", "Raichu-Mega-X", "RAICHU", 2),
    FormAssetMapping("raichu-mega-y", "Raichu-Mega-Y", "RAICHU", 3),
    FormAssetMapping("tatsugiri-curly-mega", "Tatsugiri-Curly-Mega", "TATSUGIRI", 3),
    FormAssetMapping("tatsugiri-droopy-mega", "Tatsugiri-Droopy-Mega", "TATSUGIRI", 4),
    FormAssetMapping(
        "tatsugiri-stretchy-mega",
        "Tatsugiri-Stretchy-Mega",
        "TATSUGIRI",
        5,
    ),
    FormAssetMapping("zygarde-mega", "Zygarde-Mega", "ZYGARDE", 4),
)

BATTLE_ASSETS: tuple[tuple[str, str], ...] = (
    ("Front", "front"),
    ("Back", "back"),
    ("Front shiny", "shiny_front"),
    ("Back shiny", "shiny_back"),
)
ICON_ASSETS: tuple[tuple[str, str], ...] = (
    ("Icons", "pokemon_home"),
    ("Icons shiny", "pokemon_home_shiny"),
)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def png_bytes(image: Image.Image) -> bytes:
    output = io.BytesIO()
    image.save(output, format="PNG", optimize=False)
    return output.getvalue()


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as source:
        image = source.convert("RGBA")
    if image.width <= 0 or image.height <= 0 or image.getbbox() is None:
        raise ValueError(f"Sprite is empty: {path}")
    return image


def icon_frame(image: Image.Image, path: Path) -> Image.Image:
    if image.width < image.height or image.width % image.height != 0:
        raise ValueError(f"Expected horizontal square icon frames: {path}")
    return image.crop((0, 0, image.height, image.height))


def animation_metadata(
    logical_source_path: str,
    width: int,
    height: int,
) -> dict[str, Any]:
    return {
        "source": logical_source_path,
        "source_pack": f"{ASSET_PACK_NAME} {ASSET_PACK_VERSION}",
        "image": "sheet.png",
        "speed": 1.0,
        "frame_width": width,
        "frame_height": height,
        "source_frame_count": 1,
        "frames": [
            {
                "x": 0,
                "y": 0,
                "w": width,
                "h": height,
                "duration": 1.0,
            }
        ],
    }


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def canonical_revision(value: dict[str, Any]) -> str:
    canonical = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return f"sha256:{sha256_bytes(canonical)}"


def validate_source_pack(source_root: Path) -> None:
    credits_path = source_root / "Credits.txt"
    changelog_path = source_root / "Changelog.txt"
    graphics_root = source_root / "Graphics" / "Pokemon"
    if not graphics_root.is_dir():
        raise ValueError(f"Missing Graphics/Pokemon source directory: {graphics_root}")
    if sha256_file(credits_path) != EXPECTED_CREDITS_SHA256:
        raise ValueError("Credits.txt does not match the reviewed Generation 9 Pack 3.3.6")
    if sha256_file(changelog_path) != EXPECTED_CHANGELOG_SHA256:
        raise ValueError("Changelog.txt does not match the reviewed Generation 9 Pack 3.3.6")


def expected_outputs(
    source_root: Path,
    project_root: Path,
) -> tuple[dict[Path, bytes], dict[str, Any]]:
    graphics_root = source_root / "Graphics" / "Pokemon"
    pokemon_root = project_root / "assets" / "sprites" / "pokemon"
    outputs: dict[Path, bytes] = {}
    manifest_forms: list[dict[str, Any]] = []

    for mapping in FORM_ASSET_MAPPINGS:
        source_assets: dict[str, Any] = {}
        output_paths: list[str] = []
        for source_folder, output_folder in BATTLE_ASSETS:
            source_path = graphics_root / source_folder / f"{mapping.source_stem}.png"
            image = load_rgba(source_path)
            logical_source = (
                f"gen9_asset_pack/Graphics/Pokemon/{source_folder}/"
                f"{mapping.source_stem}.png"
            )
            output_dir = pokemon_root / output_folder / mapping.catalog_entry_id
            sheet_path = output_dir / "sheet.png"
            metadata_path = output_dir / "animation.json"
            outputs[sheet_path] = png_bytes(image)
            outputs[metadata_path] = json_bytes(
                animation_metadata(logical_source, image.width, image.height)
            )
            source_assets[output_folder] = {
                "path": logical_source,
                "sha256": sha256_file(source_path),
                "width": image.width,
                "height": image.height,
            }
            output_paths.extend(
                [
                    sheet_path.relative_to(project_root).as_posix(),
                    metadata_path.relative_to(project_root).as_posix(),
                ]
            )

        for source_folder, output_folder in ICON_ASSETS:
            source_path = graphics_root / source_folder / f"{mapping.source_stem}.png"
            source_image = load_rgba(source_path)
            image = icon_frame(source_image, source_path)
            logical_source = (
                f"gen9_asset_pack/Graphics/Pokemon/{source_folder}/"
                f"{mapping.source_stem}.png"
            )
            output_path = pokemon_root / output_folder / f"{mapping.showdown_species_name}.png"
            outputs[output_path] = png_bytes(image)
            source_assets[output_folder] = {
                "path": logical_source,
                "sha256": sha256_file(source_path),
                "sourceWidth": source_image.width,
                "sourceHeight": source_image.height,
                "frameWidth": image.width,
                "frameHeight": image.height,
                "selectedFrame": 0,
            }
            output_paths.append(output_path.relative_to(project_root).as_posix())

        manifest_forms.append(
            {
                "catalogEntryId": mapping.catalog_entry_id,
                "showdownSpeciesName": mapping.showdown_species_name,
                "sourcePokemonId": mapping.source_pokemon_id,
                "sourceFormIndex": mapping.source_form_index,
                "sourceStem": mapping.source_stem,
                "sourceAssets": source_assets,
                "outputs": output_paths,
            }
        )

    without_revision = {
        "schemaVersion": 1,
        "source": {
            "name": ASSET_PACK_NAME,
            "version": ASSET_PACK_VERSION,
            "website": ASSET_PACK_WEBSITE,
            "creditsFileSha256": EXPECTED_CREDITS_SHA256,
            "changelogFileSha256": EXPECTED_CHANGELOG_SHA256,
            "plzaSpriteCredits": [
                "Caruban",
                "ace_stryfe",
                "KingOfThe-X-Roads",
                "camiloveso",
                "Mak",
            ],
            "licenseStatus": "not_declared_in_source_bundle",
            "approval": "User-approved for PokeAether import and R2 publication on 2026-08-21",
        },
        "mappingCount": len(FORM_ASSET_MAPPINGS),
        "forms": manifest_forms,
    }
    manifest = {
        **without_revision,
        "importManifestRevision": canonical_revision(without_revision),
    }
    outputs[project_root / "data" / IMPORT_MANIFEST_PATH.name] = json_bytes(manifest)
    return outputs, manifest


def write_outputs(outputs: dict[Path, bytes]) -> None:
    for path, content in sorted(outputs.items(), key=lambda value: str(value[0])):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        print(f"WROTE {path.relative_to(PROJECT_ROOT)}")


def check_outputs(outputs: dict[Path, bytes]) -> None:
    differences: list[str] = []
    for path, expected in sorted(outputs.items(), key=lambda value: str(value[0])):
        if not path.is_file():
            differences.append(f"missing {path.relative_to(PROJECT_ROOT)}")
        elif path.read_bytes() != expected:
            differences.append(f"different {path.relative_to(PROJECT_ROOT)}")
    if differences:
        raise ValueError("Import outputs are stale:\n" + "\n".join(differences))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Import reviewed Mega Champions sprites from Generation 9 Pack 3.3.6."
    )
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    source_root = args.source_root.expanduser().resolve()
    validate_source_pack(source_root)
    outputs, manifest = expected_outputs(source_root, PROJECT_ROOT)
    if args.check:
        check_outputs(outputs)
        print(
            f"VERIFIED {manifest['mappingCount']} Mega Champions sprite mappings, "
            f"revision={manifest['importManifestRevision']}"
        )
        return

    write_outputs(outputs)
    print(
        f"IMPORTED {manifest['mappingCount']} Mega Champions sprite mappings, "
        f"revision={manifest['importManifestRevision']}"
    )


if __name__ == "__main__":
    main()
