#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


PROJECT_ROOT = Path(__file__).resolve().parents[1]

PLATFORMS = {
    "windows": {
        "build_dir": PROJECT_ROOT / "builds" / "windows",
        "zip_name": "game-{artifact_id}-windows.zip",
        "manifest_name": "manifest-windows.json",
        "executable": "PokeAether.exe",
        "launcher_build_dir": PROJECT_ROOT / "builds" / "launcher-app" / "windows",
        "launcher_zip_name": "PokeAetherLauncher-windows.zip",
        "launcher_executable": "PokeAether Launcher.exe",
        "launcher_required_files": [
            "PokeAether Launcher.exe",
            "PokeAether Launcher.pck",
        ],
        "required_files": [
            "PokeAether.exe",
            "PokeAether.pck",
        ],
    },
    "linux": {
        "build_dir": PROJECT_ROOT / "builds" / "linux",
        "zip_name": "game-{artifact_id}-linux.zip",
        "manifest_name": "manifest-linux.json",
        "executable": "PokeAether.x86_64",
        "launcher_build_dir": PROJECT_ROOT / "builds" / "launcher-app" / "linux",
        "launcher_zip_name": "PokeAetherLauncher-linux.zip",
        "launcher_executable": "PokeAether Launcher.x86_64",
        "launcher_required_files": [
            "PokeAether Launcher.x86_64",
            "PokeAether Launcher.pck",
        ],
        "required_files": [
            "PokeAether.x86_64",
            "PokeAether.pck",
        ],
    },
    "macos": {
        "build_dir": PROJECT_ROOT / "builds" / "macos",
        "zip_name": "game-{artifact_id}-macos.zip",
        "manifest_name": "manifest-macos.json",
        "executable": "PokeAether.app/Contents/MacOS/PokeAether",
        "launcher_build_dir": PROJECT_ROOT / "builds" / "launcher-app" / "macos",
        "launcher_zip_name": "PokeAetherLauncher-macos.zip",
        "launcher_executable": "PokeAether Launcher.app/Contents/MacOS/PokeAether Launcher",
        "launcher_required_files": [
            "PokeAether Launcher.app",
        ],
        "required_files": [
            "PokeAether.app",
        ],
    },
}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Package exported Godot builds for the PokeAether launcher."
    )
    parser.add_argument("--version", required=True, help="Release version, for example 0.1.0.")
    parser.add_argument(
        "--build-id",
        help="Immutable game build identifier. Defaults to --version for local packages.",
    )
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
        default="all",
        help="Comma-separated platforms to package (windows,linux,macos), or all.",
    )
    parser.add_argument(
        "--default-platform",
        choices=["windows", "linux", "macos"],
        default="windows",
        help="Which platform manifest is also copied to manifest.json.",
    )
    parser.add_argument(
        "--asset-pack",
        action="append",
        default=[],
        metavar="ID:VERSION:PATH[:OPTIONAL]",
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
    if re.fullmatch(r"[A-Za-z0-9._+-]+", args.version) is None:
        raise SystemExit("--version may only contain letters, digits, dots, plus signs, underscores, and hyphens")
    build_id = (args.build_id or args.version).strip()
    if not build_id:
        raise SystemExit("--build-id cannot be empty")
    if re.fullmatch(r"[A-Za-z0-9._-]+", build_id) is None:
        raise SystemExit("--build-id may only contain letters, digits, dots, underscores, and hyphens")
    artifact_id = args.version if build_id == args.version else f"{args.version}-{build_id}"

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    base_url = args.base_url.rstrip("/")
    platform_names = _parse_platforms(args.platform)
    game_prefix = args.game_prefix.strip("/")
    asset_prefix = args.asset_prefix.strip("/")
    asset_packs = [_build_asset_pack(entry, base_url, asset_prefix, output_dir) for entry in args.asset_pack]
    asset_packs += [_build_external_asset_pack(entry, base_url, asset_prefix) for entry in args.external_asset_pack]

    manifests: dict[str, dict] = {}
    for platform_name in platform_names:
        platform_config = PLATFORMS[platform_name]
        build_dir = platform_config["build_dir"]
        _assert_required_paths(build_dir, platform_config["required_files"])

        zip_name = platform_config["zip_name"].format(artifact_id=artifact_id)
        zip_path = output_dir / zip_name
        _zip_directory(build_dir, zip_path)

        launcher_data: dict[str, object] = {}
        if args.include_launcher:
            launcher_build_dir = platform_config["launcher_build_dir"]
            _assert_required_paths(launcher_build_dir, platform_config["launcher_required_files"])
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
            "gameBuildId": build_id,
            "game": {
                "version": args.version,
                "buildId": build_id,
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


def _parse_platforms(platforms_arg: str) -> list[str]:
    if platforms_arg == "all":
        return ["windows", "linux", "macos"]

    requested_platforms: list[str] = []
    for platform_name in (item.strip().lower() for item in platforms_arg.split(",")):
        if not platform_name:
            continue
        if platform_name not in PLATFORMS:
            raise SystemExit(f"Unsupported platform for --platform: {platform_name}")
        if platform_name not in requested_platforms:
            requested_platforms.append(platform_name)

    if not requested_platforms:
        raise SystemExit("--platform must include at least one of windows, linux, macos, or all")

    return requested_platforms


def _assert_required_paths(build_dir: Path, required_paths: list[str]) -> None:
    if not build_dir.is_dir():
        raise SystemExit(f"Missing build directory: {build_dir}")

    missing_paths = [path_name for path_name in required_paths if not (build_dir / path_name).exists()]
    if missing_paths:
        missing_list = ", ".join(missing_paths)
        raise SystemExit(f"Missing required build files in {build_dir}: {missing_list}")


def _build_asset_pack(entry: str, base_url: str, asset_prefix: str, output_dir: Path) -> dict:
    parts = entry.split(":", 3)
    if len(parts) not in (3, 4):
        raise SystemExit("--asset-pack must use ID:VERSION:PATH[:OPTIONAL]")

    pack_id, version, source_path_text = parts[:3]
    source_path = Path(source_path_text)
    if not source_path.is_absolute():
        source_path = PROJECT_ROOT / source_path
    if not source_path.is_file():
        raise SystemExit(f"Missing asset pack zip: {source_path}")

    target_path = output_dir / source_path.name
    if source_path.resolve() != target_path.resolve():
        target_path.write_bytes(source_path.read_bytes())

    optional = len(parts) == 4 and parts[3].strip().lower() in {"1", "true", "yes", "optional"}
    asset_pack = {
        "id": pack_id,
        "version": version,
        "url": _build_url(base_url, asset_prefix, target_path.name),
        "sha256": _sha256(target_path),
        "sizeBytes": target_path.stat().st_size,
    }
    if optional:
        asset_pack["optional"] = True
        if pack_id.startswith("pokemon-gen5"):
            asset_pack["autoUpdateIfInstalled"] = True

    return asset_pack


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
        if pack_id.startswith("pokemon-gen5"):
            asset_pack["autoUpdateIfInstalled"] = True

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
