#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


PROJECT_ROOT = Path(__file__).resolve().parents[1]

PLATFORMS = {
    "windows": {
        "build_dir": PROJECT_ROOT / "builds" / "windows",
        "zip_name": "game-{version}-windows.zip",
        "manifest_name": "manifest-windows.json",
        "executable": "Pokemon Aether Online.exe",
        "launcher_build_dir": PROJECT_ROOT / "builds" / "launcher-app" / "windows",
        "launcher_zip_name": "PokemonAetherLauncher-windows.zip",
        "launcher_executable": "Pokemon Aether Launcher.exe",
        "launcher_required_files": [
            "Pokemon Aether Launcher.exe",
            "Pokemon Aether Launcher.pck",
        ],
        "required_files": [
            "Pokemon Aether Online.exe",
            "Pokemon Aether Online.pck",
        ],
    },
    "linux": {
        "build_dir": PROJECT_ROOT / "builds" / "linux",
        "zip_name": "game-{version}-linux.zip",
        "manifest_name": "manifest-linux.json",
        "executable": "Pokemon Aether Online.x86_64",
        "launcher_build_dir": PROJECT_ROOT / "builds" / "launcher-app" / "linux",
        "launcher_zip_name": "PokemonAetherLauncher-linux.zip",
        "launcher_executable": "Pokemon Aether Launcher.x86_64",
        "launcher_required_files": [
            "Pokemon Aether Launcher.x86_64",
            "Pokemon Aether Launcher.pck",
        ],
        "required_files": [
            "Pokemon Aether Online.x86_64",
            "Pokemon Aether Online.pck",
        ],
    },
}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Package exported Godot builds for the Pokemon Aether launcher."
    )
    parser.add_argument("--version", required=True, help="Release version, for example 0.1.0.")
    parser.add_argument(
        "--base-url",
        required=True,
        help="Public URL folder where the generated zip files will be hosted.",
    )
    parser.add_argument(
        "--game-prefix",
        default="",
        help="Optional public URL path prefix for game zips, for example game.",
    )
    parser.add_argument(
        "--asset-prefix",
        default="",
        help="Optional public URL path prefix for asset pack zips, for example assets.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(PROJECT_ROOT / "builds" / "launcher"),
        help="Folder where release zips and manifests are written.",
    )
    parser.add_argument(
        "--platform",
        choices=["windows", "linux", "all"],
        default="all",
        help="Which platform build to package.",
    )
    parser.add_argument(
        "--default-platform",
        choices=["windows", "linux"],
        default="windows",
        help="Which platform manifest is also copied to manifest.json.",
    )
    parser.add_argument(
        "--asset-pack",
        action="append",
        default=[],
        metavar="ID:VERSION:PATH",
        help="Optional asset pack to include in each manifest.",
    )
    parser.add_argument(
        "--external-asset-pack",
        action="append",
        default=[],
        metavar="ID:VERSION:FILE_NAME[:SIZE_BYTES[:OPTIONAL]]",
        help="Existing hosted asset pack to include in each manifest without copying or hashing it.",
    )
    parser.add_argument(
        "--include-launcher",
        action="store_true",
        help="Include launcher self-update metadata in each platform manifest.",
    )
    parser.add_argument(
        "--launcher-prefix",
        default="launcher/latest",
        help="Public URL path prefix for launcher zip URLs.",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    base_url = args.base_url.rstrip("/")
    platform_names = ["windows", "linux"] if args.platform == "all" else [args.platform]
    game_prefix = args.game_prefix.strip("/")
    asset_prefix = args.asset_prefix.strip("/")
    asset_packs = [_build_asset_pack(entry, base_url, asset_prefix, output_dir) for entry in args.asset_pack]
    asset_packs += [_build_external_asset_pack(entry, base_url, asset_prefix) for entry in args.external_asset_pack]

    manifests: dict[str, dict] = {}
    for platform_name in platform_names:
        platform_config = PLATFORMS[platform_name]
        build_dir = platform_config["build_dir"]
        _assert_required_files(build_dir, platform_config["required_files"])

        zip_name = platform_config["zip_name"].format(version=args.version)
        zip_path = output_dir / zip_name
        _zip_directory(build_dir, zip_path)

        launcher_data: dict[str, object] = {}
        if args.include_launcher:
            launcher_build_dir = platform_config["launcher_build_dir"]
            _assert_required_files(launcher_build_dir, platform_config["launcher_required_files"])
            launcher_zip_name = platform_config["launcher_zip_name"]
            launcher_zip_path = output_dir / launcher_zip_name
            _zip_directory(launcher_build_dir, launcher_zip_path)

            launcher_data = {
                "version": args.version,
                "url": _build_url(base_url, args.launcher_prefix, launcher_zip_name),
                "sha256": _sha256(launcher_zip_path),
                "sizeBytes": launcher_zip_path.stat().st_size,
                "binary": platform_config["launcher_executable"],
            }

        manifest = {
            "gameVersion": args.version,
            "game": {
                "version": args.version,
                "url": _build_url(base_url, game_prefix, zip_name),
                "sha256": _sha256(zip_path),
                "sizeBytes": zip_path.stat().st_size,
                "executable": platform_config["executable"],
            },
            "assetPacks": asset_packs,
        }
        if launcher_data:
            manifest["launcher"] = launcher_data
        manifests[platform_name] = manifest

        manifest_path = output_dir / platform_config["manifest_name"]
        _write_json(manifest_path, manifest)
        if args.include_launcher:
            print(f"Wrote {_display_path(launcher_zip_path)}")
        print(f"Wrote {_display_path(zip_path)}")
        print(f"Wrote {_display_path(manifest_path)}")

    if args.default_platform in manifests:
        default_manifest_path = output_dir / "manifest.json"
        _write_json(default_manifest_path, manifests[args.default_platform])
        print(f"Wrote {_display_path(default_manifest_path)}")


def _assert_required_files(build_dir: Path, required_files: list[str]) -> None:
    if not build_dir.is_dir():
        raise SystemExit(f"Missing build directory: {build_dir}")

    missing_files = [file_name for file_name in required_files if not (build_dir / file_name).is_file()]
    if missing_files:
        missing_list = ", ".join(missing_files)
        raise SystemExit(f"Missing required build files in {build_dir}: {missing_list}")


def _build_asset_pack(entry: str, base_url: str, asset_prefix: str, output_dir: Path) -> dict:
    parts = entry.split(":", 2)
    if len(parts) != 3:
        raise SystemExit("--asset-pack must use ID:VERSION:PATH")

    pack_id, version, source_path_text = parts
    source_path = Path(source_path_text)
    if not source_path.is_absolute():
        source_path = PROJECT_ROOT / source_path
    if not source_path.is_file():
        raise SystemExit(f"Missing asset pack zip: {source_path}")

    target_path = output_dir / source_path.name
    if source_path.resolve() != target_path.resolve():
        target_path.write_bytes(source_path.read_bytes())

    return {
        "id": pack_id,
        "version": version,
        "url": _build_url(base_url, asset_prefix, target_path.name),
        "sha256": _sha256(target_path),
        "sizeBytes": target_path.stat().st_size,
    }


def _build_external_asset_pack(entry: str, base_url: str, asset_prefix: str) -> dict:
    parts = entry.split(":", 4)
    if len(parts) not in (3, 4, 5):
        raise SystemExit("--external-asset-pack must use ID:VERSION:FILE_NAME[:SIZE_BYTES[:OPTIONAL]]")

    pack_id, version, file_name = parts[:3]
    if not pack_id or not version or not file_name:
        raise SystemExit("--external-asset-pack must use ID:VERSION:FILE_NAME[:SIZE_BYTES[:OPTIONAL]]")

    if "/" in file_name or "\\" in file_name:
        raise SystemExit("--external-asset-pack FILE_NAME must be a file name, not a path")

    size_bytes = 0
    if len(parts) >= 4 and parts[3]:
        try:
            size_bytes = int(parts[3])
        except ValueError:
            raise SystemExit("--external-asset-pack SIZE_BYTES must be an integer") from None

        if size_bytes < 0:
            raise SystemExit("--external-asset-pack SIZE_BYTES cannot be negative")

    optional = len(parts) == 5 and parts[4].strip().lower() in {"1", "true", "yes", "optional"}
    asset_pack = {
        "id": pack_id,
        "version": version,
        "url": _build_url(base_url, asset_prefix, file_name),
        "sha256": "",
        "sizeBytes": size_bytes,
    }
    if optional:
        asset_pack["optional"] = True

    return asset_pack


def _build_url(base_url: str, prefix: str, file_name: str) -> str:
    parts = [base_url.rstrip("/")]
    if prefix:
        parts.append(prefix.strip("/"))
    parts.append(file_name)
    return "/".join(parts)


def _zip_directory(source_dir: Path, zip_path: Path) -> None:
    if zip_path.exists():
        zip_path.unlink()

    with ZipFile(zip_path, "w", ZIP_DEFLATED) as archive:
        for file_path in sorted(source_dir.rglob("*")):
            if file_path.is_dir():
                continue

            relative_path = file_path.relative_to(source_dir).as_posix()
            info = ZipInfo.from_file(file_path, relative_path)
            info.compress_type = ZIP_DEFLATED
            info.external_attr = (file_path.stat().st_mode & 0xFFFF) << 16
            with file_path.open("rb") as file:
                archive.writestr(info, file.read())


def _sha256(file_path: Path) -> str:
    digest = hashlib.sha256()
    with file_path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _write_json(file_path: Path, data: dict) -> None:
    file_path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def _display_path(file_path: Path) -> str:
    try:
        return str(file_path.relative_to(PROJECT_ROOT))
    except ValueError:
        return str(file_path)


if __name__ == "__main__":
    main()
