#!/usr/bin/env python3
"""Require live latest download redirects before stopping duplicate uploads."""
import argparse
import json
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener
from prune_r2_release_objects import _load_remote_manifests


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def verify(manifest_dir, base_url, remote=False):
    opener = build_opener(NoRedirect)
    remote_manifests = _load_remote_manifests(base_url) if remote else []
    for platform in ("windows", "linux", "macos", "android"):
        if remote:
            manifest = next((value for value in remote_manifests
                             if urlparse(value.get('game', {}).get('url', '')).path.endswith(
                                 f'-{platform}.apk' if platform == "android" else f'-{platform}.zip'
                             )), None)
            if manifest is None:
                if platform not in {"macos", "android"}:
                    raise SystemExit(f"Missing remote platform manifest: {platform}")
                continue
        else:
            path = manifest_dir / f"manifest-{platform}.json"
            if not path.exists():
                if platform not in {"macos", "android"}:
                    raise SystemExit(f"Missing local platform manifest: {platform}")
                continue
            manifest = json.loads(path.read_text())
        release_kinds = (("game", "PokeAether"),) if platform == "android" else (
            ("game", "PokeAether"), ("launcher", "PokeAetherLauncher")
        )
        extension = "apk" if platform == "android" else "zip"
        for kind, name in release_kinds:
            expected = base_url.rstrip("/") + urlparse(manifest[kind]["url"]).path
            request = Request(f"{base_url.rstrip('/')}/{kind}/latest/{name}-{platform}.{extension}", method="HEAD",
                              headers={"Cache-Control": "no-cache", "User-Agent": "PokeAether-R2-Pruner/1"})
            try:
                response = opener.open(request, timeout=30)
            except HTTPError as error:
                response = error
            with response:
                if response.status != 302 or response.headers.get("Location") != expected:
                    raise SystemExit(f"Latest redirect does not match published manifest: {kind}/{platform}")
            print(f"Verified latest redirect: {kind}/{platform}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest_dir", type=Path, nargs="?", default=Path("builds/launcher"))
    parser.add_argument("--public-base-url", default="https://updates.pokeaether.com")
    parser.add_argument("--remote", action="store_true", help="Verify the currently published manifests before uploading a release.")
    args = parser.parse_args()
    verify(args.manifest_dir, args.public_base_url, args.remote)
