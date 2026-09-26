#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

if __package__:
    from .upload_launcher_release import _load_config, _signed_request
else:
    from upload_launcher_release import _load_config, _signed_request


def _version_code(manifest: Any, label: str) -> int:
    if not isinstance(manifest, dict):
        raise SystemExit(f"{label} manifest must be a JSON object")
    game = manifest.get("game")
    if not isinstance(game, dict):
        raise SystemExit(f"{label} manifest is missing game metadata")
    version_code = game.get("versionCode")
    if type(version_code) is not int or version_code < 1:
        raise SystemExit(f"{label} manifest has an invalid Android version code")
    return version_code


def require_newer_android_version(candidate_manifest: dict[str, Any], config: Any) -> int | None:
    candidate_code = _version_code(candidate_manifest, "Candidate")
    status, reason, body = _signed_request(config, "GET", "manifest-android.json")
    if status == 404:
        return None
    if status != 200:
        raise SystemExit(f"Could not read current Android manifest from R2: {status} {reason}")

    try:
        current_manifest = json.loads(body)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SystemExit(f"Current Android R2 manifest is invalid JSON: {error}") from error
    current_code = _version_code(current_manifest, "Current")
    if candidate_code <= current_code:
        raise SystemExit(
            "Candidate Android version code must exceed the currently published version "
            f"({candidate_code} <= {current_code})"
        )
    return current_code


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ensure an Android release candidate is newer than the manifest in R2."
    )
    parser.add_argument("manifest", type=Path, help="Path to the candidate manifest-android.json")
    args = parser.parse_args()
    try:
        candidate_manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SystemExit(f"Could not read candidate Android manifest: {error}") from error

    previous_code = require_newer_android_version(candidate_manifest, _load_config())
    candidate_code = _version_code(candidate_manifest, "Candidate")
    if previous_code is None:
        print(f"Android version code {candidate_code} is the first published version")
    else:
        print(f"Android version code {candidate_code} is newer than published code {previous_code}")


if __name__ == "__main__":
    main()
