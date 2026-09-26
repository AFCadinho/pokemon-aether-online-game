#!/usr/bin/env python3
"""Stamp and inspect an Android release without publishing it."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


PACKAGE = "com.pokeaether.game"
ORIGIN = "https://updates.pokeaether.com"
VERSION = re.compile(r"[0-9]+(?:\.[0-9]+){1,2}(?:-[A-Za-z0-9._-]+)?\Z")
BUILD_ID = re.compile(r"[A-Za-z0-9._-]{1,120}\Z")
CERT = re.compile(r"[0-9a-f]{64}\Z")


def setting(path: Path, section: str, key: str) -> str:
    current = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
        elif current == section and line.startswith(key + "="):
            return line.split("=", 1)[1].strip()
    raise ValueError(f"Missing [{section}] {key} in {path}")


def replace_setting(path: Path, section: str, key: str, value: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    current = ""
    for index, line in enumerate(lines):
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
        elif current == section and line.startswith(key + "="):
            lines[index] = f"{key}={value}"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            return
    raise ValueError(f"Missing [{section}] {key} in {path}")


def prepare(project: Path, presets: Path, version: str, code: int, build_id: str) -> None:
    if not VERSION.fullmatch(version) or not BUILD_ID.fullmatch(build_id):
        raise ValueError("Invalid Android version or build ID")
    previous = int(setting(presets, "preset.7.options", "version/code"))
    if code <= previous or code > 2147483647:
        raise ValueError(f"Android version code must be greater than {previous}")
    if setting(presets, "preset.7.options", "package/unique_name") != f'"{PACKAGE}"':
        raise ValueError("Unexpected Android package ID")
    replace_setting(project, "application", "config/version", json.dumps(version))
    replace_setting(project, "application", "config/build_id", json.dumps(build_id))
    replace_setting(project, "application", "config/android_version_code", str(code))
    replace_setting(presets, "preset.7.options", "version/code", str(code))
    replace_setting(presets, "preset.7.options", "version/name", json.dumps(version))


def inspect(apk: Path, aapt: Path, apksigner: Path, version: str, code: int,
            build_id: str, certificate: str, output: Path) -> dict:
    if not VERSION.fullmatch(version) or not BUILD_ID.fullmatch(build_id):
        raise ValueError("Invalid Android version or build ID")
    certificate = certificate.lower().replace(":", "")
    if not CERT.fullmatch(certificate):
        raise ValueError("Expected signing certificate must be a SHA-256 fingerprint")
    if not apk.is_file() or not 0 < apk.stat().st_size <= 1024 * 1024 * 1024:
        raise ValueError("APK is missing, empty, or larger than the updater allows")
    badging = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True)
    match = re.search(r"^package: name='([^']+)' versionCode='([0-9]+)' versionName='([^']+)'", badging, re.MULTILINE)
    if not match or match.groups() != (PACKAGE, str(code), version):
        raise ValueError("Exported APK package or version differs from release record")
    signature = subprocess.check_output([str(apksigner), "verify", "--print-certs", str(apk)], text=True)
    match = re.search(r"^Signer #1 certificate SHA-256 digest: ([0-9a-fA-F]+)$", signature, re.MULTILINE)
    if not match or match.group(1).lower() != certificate:
        raise ValueError("APK signing certificate differs from the pinned release certificate")
    apk_name = f"game-{build_id}-android.apk"
    if apk.name != apk_name:
        raise ValueError(f"APK must have immutable name {apk_name}")
    digest = hashlib.sha256()
    with apk.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    manifest = {"game": {
        "buildId": build_id,
        "version": version,
        "versionCode": code,
        "url": f"{ORIGIN}/game/{apk_name}",
        "sizeBytes": apk.stat().st_size,
        "sha256": digest.hexdigest(),
    }}
    output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    stamp = commands.add_parser("prepare")
    stamp.add_argument("--project", type=Path, default=Path("project.godot"))
    stamp.add_argument("--presets", type=Path, default=Path("export_presets.cfg"))
    review = commands.add_parser("inspect")
    review.add_argument("--apk", type=Path, required=True)
    review.add_argument("--aapt", type=Path, required=True)
    review.add_argument("--apksigner", type=Path, required=True)
    review.add_argument("--certificate", required=True)
    review.add_argument("--output", type=Path, required=True)
    for command in (stamp, review):
        command.add_argument("--version", required=True)
        command.add_argument("--code", type=int, required=True)
        command.add_argument("--build-id", required=True)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.project, args.presets, args.version, args.code, args.build_id)
    else:
        inspect(args.apk, args.aapt, args.apksigner, args.version, args.code,
                args.build_id, args.certificate, args.output)


if __name__ == "__main__":
    main()
