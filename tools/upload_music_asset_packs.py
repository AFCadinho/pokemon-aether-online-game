#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
from dataclasses import dataclass
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from upload_launcher_release import _load_config, _upload_file


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "builds" / "asset-packs"
WORKFLOW_PATH = PROJECT_ROOT / ".github" / "workflows" / "deploy-desktop-r2.yml"


@dataclass(frozen=True)
class MusicPack:
    pack_id: str
    version_prefix: str
    source_path: Path
    version_env: str
    size_env: str


MUSIC_PACKS: tuple[MusicPack, ...] = (
    MusicPack(
        "music",
        "music",
        PROJECT_ROOT / "assets" / "music",
        "MUSIC_ASSET_VERSION",
        "MUSIC_ASSET_SIZE",
    ),
)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Package local music folders, upload them to R2 under assets/, "
            "and update the launcher deploy workflow manifest versions."
        )
    )
    parser.add_argument(
        "--pack",
        action="append",
        choices=[pack.pack_id for pack in MUSIC_PACKS],
        help="Upload only this pack. Defaults to all packs.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory for generated zip files.",
    )
    parser.add_argument(
        "--version-label",
        default="",
        help=(
            "Use this label instead of the content hash, for example v3. "
            "The final version is <pack-prefix>-<label>."
        ),
    )
    parser.add_argument(
        "--no-upload",
        action="store_true",
        help="Package and update the workflow without uploading to R2.",
    )
    parser.add_argument(
        "--no-workflow-update",
        action="store_true",
        help="Do not update .github/workflows/deploy-desktop-r2.yml.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Recreate and upload packs even when their computed version is already in the workflow.",
    )
    args = parser.parse_args()

    selected_ids = set(args.pack or [pack.pack_id for pack in MUSIC_PACKS])
    selected_packs = [pack for pack in MUSIC_PACKS if pack.pack_id in selected_ids]
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    workflow_versions = _read_workflow_versions()

    uploaded_versions: dict[str, tuple[str, int]] = {}
    r2_config = None if args.no_upload else _load_config()

    for pack in selected_packs:
        files = _collect_pack_files(pack.source_path)
        digest = _content_hash(pack.source_path, files)
        version_suffix = args.version_label.strip() or digest[:12]
        version = f"{pack.version_prefix}-{version_suffix}"
        zip_path = output_dir / f"{version}.zip"
        current_version = workflow_versions.get(pack.version_env, "")

        if not args.force and current_version == version:
            print(f"Skipping unchanged {pack.pack_id}: {version}")
            continue

        if args.force or not zip_path.exists():
            _write_pack_zip(files, zip_path)
        else:
            print(f"Reusing existing {zip_path.relative_to(PROJECT_ROOT)}")

        size_bytes = zip_path.stat().st_size
        uploaded_versions[pack.pack_id] = (version, size_bytes)
        print(f"{pack.pack_id}: {version}.zip ({size_bytes} bytes)")

        if r2_config is not None:
            key = f"assets/{zip_path.name}"
            print(f"Uploading {zip_path.name} -> s3://{r2_config.bucket}/{key}")
            _upload_file(r2_config, zip_path, key)
            print(f"Uploaded {zip_path.name}")

    if not uploaded_versions:
        print("No music asset pack changes detected.")
        return

    if not args.no_workflow_update:
        _update_workflow(selected_packs, uploaded_versions)
        print(f"Updated {WORKFLOW_PATH.relative_to(PROJECT_ROOT)}")

    print("Done.")


def _collect_pack_files(source_dir: Path) -> list[Path]:
    if not source_dir.is_dir():
        raise SystemExit(f"Missing music asset folder: {source_dir}")

    files = sorted(
        path
        for path in source_dir.rglob("*")
        if path.is_file() and path.suffix != ".import" and not path.name.startswith(".")
    )
    if not files:
        raise SystemExit(f"Music asset folder has no packageable files: {source_dir}")

    unsupported_files = [path for path in files if path.suffix.lower() not in {".ogg"}]
    if unsupported_files:
        unsupported_list = "\n".join(
            f"- {path.relative_to(PROJECT_ROOT)}" for path in unsupported_files
        )
        raise SystemExit(
            "Music asset packs only accept .ogg files. Convert or remove:\n"
            f"{unsupported_list}"
        )

    return files


def _content_hash(source_dir: Path, files: list[Path]) -> str:
    digest = hashlib.sha256()
    for file_path in files:
        relative_path = file_path.relative_to(source_dir).as_posix()
        digest.update(relative_path.encode("utf-8"))
        digest.update(b"\0")
        with file_path.open("rb") as file:
            for chunk in iter(lambda: file.read(1024 * 1024), b""):
                digest.update(chunk)
        digest.update(b"\0")

    return digest.hexdigest()


def _write_pack_zip(files: list[Path], zip_path: Path) -> None:
    if zip_path.exists():
        zip_path.unlink()

    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(zip_path, "w", ZIP_DEFLATED) as archive:
        for file_path in files:
            archive_path = file_path.relative_to(PROJECT_ROOT).as_posix()
            info = ZipInfo.from_file(file_path, archive_path)
            info.compress_type = ZIP_DEFLATED
            info.external_attr = (file_path.stat().st_mode & 0xFFFF) << 16
            with file_path.open("rb") as file:
                archive.writestr(info, file.read())

    print(f"Wrote {zip_path.relative_to(PROJECT_ROOT)}")


def _update_workflow(
    packs: list[MusicPack],
    uploaded_versions: dict[str, tuple[str, int]],
) -> None:
    workflow_text = WORKFLOW_PATH.read_text(encoding="utf-8")

    for pack in packs:
        if pack.pack_id not in uploaded_versions:
            continue

        version, size_bytes = uploaded_versions[pack.pack_id]
        workflow_text = _replace_env_value(workflow_text, pack.version_env, version)
        workflow_text = _replace_env_value(workflow_text, pack.size_env, str(size_bytes))

    WORKFLOW_PATH.write_text(workflow_text, encoding="utf-8")


def _read_workflow_versions() -> dict[str, str]:
    workflow_text = WORKFLOW_PATH.read_text(encoding="utf-8")
    versions: dict[str, str] = {}
    for pack in MUSIC_PACKS:
        versions[pack.version_env] = _read_env_value(workflow_text, pack.version_env)

    return versions


def _read_env_value(workflow_text: str, env_name: str) -> str:
    pattern = re.compile(rf"^  {re.escape(env_name)}: (.*)$", re.MULTILINE)
    match = pattern.search(workflow_text)
    if not match:
        raise SystemExit(f"Missing workflow env entry for {env_name}")

    return match.group(1).strip()


def _replace_env_value(workflow_text: str, env_name: str, value: str) -> str:
    pattern = re.compile(rf"^(  {re.escape(env_name)}: ).*$", re.MULTILINE)
    updated, count = pattern.subn(rf"\g<1>{value}", workflow_text)
    if count != 1:
        raise SystemExit(f"Expected exactly one workflow env entry for {env_name}, found {count}")

    return updated


if __name__ == "__main__":
    main()
