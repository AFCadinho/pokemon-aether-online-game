#!/usr/bin/env python3
"""Split a Godot web export between Cloudflare Pages and immutable R2 objects."""
from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
from pathlib import Path
import re
import shutil
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
PAGES_FILE_LIMIT = 25 * 1024 * 1024
BUILD_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
RELEASE_VERSION = re.compile(r"^[0-9]+(?:\.[0-9]+){1,2}(?:[-+][A-Za-z0-9._-]+)?$")
RELEASE_MARKER = "<!-- POKEAETHER_RELEASE_CONFIG -->"
SPRITE_SIDES = ("front", "back", "shiny_front", "shiny_back")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--release-version", required=True)
    parser.add_argument("--asset-base-url", required=True)
    parser.add_argument("--web-url", required=True)
    for side in SPRITE_SIDES:
        parser.add_argument(f"--sprite-{side.replace('_', '-')}-version", required=True)
    parser.add_argument("--export-dir", type=Path, default=ROOT / "builds/web")
    parser.add_argument("--pages-dir", type=Path, default=ROOT / "builds/web-pages")
    parser.add_argument("--r2-dir", type=Path, default=ROOT / "builds/web-r2")
    args = parser.parse_args()

    if not BUILD_ID.fullmatch(args.build_id):
        parser.error("--build-id must contain only letters, digits, dots, underscores and hyphens")
    if not RELEASE_VERSION.fullmatch(args.release_version):
        parser.error("--release-version must look like 0.4.0 or 0.4.0-beta.1")
    asset_base_url = _https_origin(args.asset_base_url, "--asset-base-url")
    web_url = _https_origin(args.web_url, "--web-url")
    export_dir = args.export_dir.resolve()
    pages_dir = args.pages_dir.resolve()
    r2_dir = args.r2_dir.resolve()
    for required in ("index.html", "index.js", "index.wasm", "index.pck", "build-receipt.json"):
        if not (export_dir / required).is_file():
            parser.error(f"web export is incomplete: missing {required}")

    shutil.rmtree(pages_dir, ignore_errors=True)
    shutil.rmtree(r2_dir, ignore_errors=True)
    pages_dir.mkdir(parents=True)
    r2_dir.mkdir(parents=True)

    sprite_versions = {
        side: getattr(args, f"sprite_{side}_version")
        for side in SPRITE_SIDES
    }
    for value in sprite_versions.values():
        if not BUILD_ID.fullmatch(value):
            parser.error("sprite versions must be safe immutable path segments")
    release_config = {
        "buildId": args.build_id,
        "releaseVersion": args.release_version,
        "assetBaseUrl": asset_base_url,
        "spriteBases": {
            side: f"{asset_base_url}/web/assets/{version}"
            for side, version in sprite_versions.items()
        },
    }

    html = (export_dir / "index.html").read_text(encoding="utf-8")
    if html.count(RELEASE_MARKER) != 1:
        parser.error("exported index.html has no unique release configuration marker")
    release_json = json.dumps(
        release_config, separators=(",", ":"), ensure_ascii=True
    ).replace("<", "\\u003c")
    injection = "<script>window.POKEAETHER_WEB_RELEASE=Object.freeze(" + release_json + ");</script>"
    (pages_dir / "index.html").write_text(html.replace(RELEASE_MARKER, injection), encoding="utf-8")

    objects: list[dict[str, object]] = []
    for source in sorted(export_dir.rglob("*")):
        if not source.is_file():
            continue
        relative = source.relative_to(export_dir)
        relative_name = relative.as_posix()
        if relative_name in {"index.html", "build-receipt.json", "export.log", "export-console.log"}:
            continue
        on_r2 = relative_name.startswith("browser-audio/") or (
            source.name.startswith("index.") and source.name != "index.js"
        )
        if on_r2:
            destination = r2_dir / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            objects.append(_object_record(source, relative, args.build_id))
        else:
            if source.stat().st_size > PAGES_FILE_LIMIT:
                parser.error(f"Pages asset exceeds Cloudflare's 25 MiB limit: {relative_name}")
            destination = pages_dir / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

    asset_origin = urlsplit(asset_base_url)
    allowed_asset_origin = f"{asset_origin.scheme}://{asset_origin.netloc}"
    (pages_dir / "_headers").write_text(
        "/*\n"
        "  Cache-Control: no-cache, max-age=0\n"
        "  Cross-Origin-Opener-Policy: same-origin\n"
        "  Cross-Origin-Embedder-Policy: require-corp\n"
        "  X-Content-Type-Options: nosniff\n"
        "  Referrer-Policy: no-referrer\n"
        "  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()\n"
        "  X-Frame-Options: DENY\n"
        f"  Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' {allowed_asset_origin} data: blob:; media-src 'self' {allowed_asset_origin}; connect-src 'self' {allowed_asset_origin}; worker-src 'self' {allowed_asset_origin} blob:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'\n"
        "\n/index.js\n"
        "  Cache-Control: no-cache, max-age=0\n",
        encoding="utf-8",
    )
    (pages_dir / "404.html").write_text(
        "<!doctype html><meta charset=utf-8><title>Not found</title><h1>Page not found</h1>",
        encoding="utf-8",
    )

    release_manifest = {
        "schemaVersion": 1,
        "buildId": args.build_id,
        "releaseVersion": args.release_version,
        "assetBaseUrl": asset_base_url,
        "webUrl": web_url,
        "spriteVersions": sprite_versions,
        "objects": objects,
    }
    (r2_dir / "web-release.json").write_text(json.dumps(release_manifest, indent=2) + "\n", encoding="utf-8")
    gateway_manifest = {
        "gameVersion": args.release_version,
        "gameBuildId": args.build_id,
        "game": {
            "version": args.release_version,
            "buildId": args.build_id,
            "url": web_url,
        },
    }
    (r2_dir / "manifest-web.json").write_text(json.dumps(gateway_manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Cloudflare Pages bundle: {pages_dir}")
    print(f"Immutable R2 objects: {len(objects)} files, {sum(int(item['bytes']) for item in objects)} bytes")


def _https_origin(value: str, option: str) -> str:
    parsed = urlsplit(value.strip())
    if (parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password
            or parsed.path not in {"", "/"} or parsed.query or parsed.fragment):
        raise argparse.ArgumentTypeError(f"{option} must be an HTTPS URL without credentials, query or fragment")
    return f"{parsed.scheme}://{parsed.netloc}"


def _object_record(source: Path, relative: Path, build_id: str) -> dict[str, object]:
    with source.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {
        "source": relative.as_posix(),
        "key": f"web/releases/{build_id}/{relative.as_posix()}",
        "bytes": source.stat().st_size,
        "sha256": digest,
        "contentType": mimetypes.guess_type(source.name)[0] or "application/octet-stream",
        "cacheControl": "public, max-age=31536000, immutable",
    }


if __name__ == "__main__":
    main()
