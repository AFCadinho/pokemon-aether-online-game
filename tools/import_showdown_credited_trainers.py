#!/usr/bin/env python3
"""Import every credited Pokémon Showdown trainer sprite without modifying it."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import time
from pathlib import Path
from urllib.parse import quote, urljoin
from urllib.request import Request, urlopen


PAGE_URL = "https://play.pokemonshowdown.com/sprites/trainers/?view=sprites&filter=credited"
ALL_SPRITES_PAGE_URL = "https://play.pokemonshowdown.com/sprites/trainers/?view=sprites"
IMAGE_ROOT = "https://play.pokemonshowdown.com/sprites/trainers/"
ASSET_ROOT = Path("assets/sprites/trainer_cards/showdown")
CATALOG_PATH = Path("data/npc_portraits/showdown_trainer_catalog.json")
CREDITS_PATH = ASSET_ROOT / "CREDITS.md"
FIGURE_RE = re.compile(r'<figure id="([^"]+\.png)">')
ARTIST_RE = re.compile(r'<h3[^>]*>By\s+([^<]+)</h3>')
SUPPLEMENTAL_ENTRIES = [
    {
        "filename": "alder.png",
        "artist": "Pokémon Showdown",
        "catalog_source": ALL_SPRITES_PAGE_URL,
    },
    {
        "filename": "ltsurge.png",
        "artist": "Pokémon Showdown",
        "catalog_source": ALL_SPRITES_PAGE_URL,
    },
    {
        "filename": "pokemonbreeder-gen4.png",
        "artist": "Pokémon Showdown",
        "catalog_source": ALL_SPRITES_PAGE_URL,
    },
]


def fetch_text(url: str) -> str:
    request = Request(url, headers={"User-Agent": "PokeAether Showdown trainer importer"})
    with urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def parse_entries(page: str) -> list[dict[str, str]]:
    current_artist = ""
    entries: list[dict[str, str]] = []
    for line in page.splitlines():
        artist_match = ARTIST_RE.search(line)
        if artist_match:
            current_artist = html.unescape(artist_match.group(1).strip())

        figure_match = FIGURE_RE.search(line)
        if figure_match:
            filename = html.unescape(figure_match.group(1))
            if not current_artist:
                raise RuntimeError(f"Missing artist attribution for {filename}")
            entries.append({"filename": filename, "artist": current_artist})

    if not entries:
        raise RuntimeError("No credited trainer sprites found")
    if len({entry["filename"] for entry in entries}) != len(entries):
        raise RuntimeError("Duplicate trainer sprite filename found")
    return sorted(entries, key=lambda entry: entry["filename"].lower())


def portrait_id(filename: str) -> str:
    stem = Path(filename).stem.lower()
    normalized = re.sub(r"[^a-z0-9]+", "_", stem).strip("_")
    return f"showdown_{normalized}"


def download_asset(filename: str, destination: Path) -> str:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file():
        content = destination.read_bytes()
        if content.startswith(b"\x89PNG\r\n\x1a\n"):
            return hashlib.sha256(content).hexdigest()
    request = Request(urljoin(IMAGE_ROOT, quote(filename)), headers={"User-Agent": "PokeAether Showdown trainer importer"})
    with urlopen(request, timeout=30) as response:
        content = response.read()
    if not content.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"Downloaded file is not a PNG: {filename}")
    destination.write_bytes(content)
    return hashlib.sha256(content).hexdigest()


def build_catalog(entries: list[dict[str, str]], page_url: str) -> list[dict[str, str]]:
    catalog: list[dict[str, str]] = []
    seen_ids: set[str] = set()
    for entry in entries:
        filename = entry["filename"]
        identifier = portrait_id(filename)
        if identifier in seen_ids:
            raise RuntimeError(f"Portrait ID collision for {filename}: {identifier}")
        seen_ids.add(identifier)

        destination = ASSET_ROOT / filename
        sha256 = download_asset(filename, destination)
        catalog.append(
            {
                "id": identifier,
                "filename": filename,
                "texture": f"res://{destination.as_posix()}",
                "artist": entry["artist"],
                "source": urljoin(IMAGE_ROOT, quote(filename)),
                "catalog_source": entry.get("catalog_source", page_url),
                "sha256": sha256,
            }
        )
        print(f"Imported {filename} ({entry['artist']})")
        time.sleep(0.02)
    return catalog


def write_outputs(catalog: list[dict[str, str]], page_url: str) -> None:
    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CATALOG_PATH.write_text(
        json.dumps(
            {
                "source": page_url,
                "filter": "credited",
                "generated_by": "tools/import_showdown_credited_trainers.py",
                "entries": catalog,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )

    by_artist: dict[str, list[dict[str, str]]] = {}
    for entry in catalog:
        by_artist.setdefault(entry["artist"], []).append(entry)
    lines = [
        "# Pokémon Showdown trainer sprites",
        "",
        "These PNGs are the original files imported without edits. Entries without a listed artist are credited to Pokémon Showdown.",
        "Source index: " + page_url,
        "",
    ]
    for artist in sorted(by_artist, key=str.casefold):
        lines.append(f"## {artist}")
        lines.append("")
        for entry in by_artist[artist]:
            lines.append(f"- `{entry['filename']}` — [source]({entry['source']})")
        lines.append("")
    CREDITS_PATH.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--page-url", default=PAGE_URL)
    args = parser.parse_args()
    entries = parse_entries(fetch_text(args.page_url))
    existing_filenames = {entry["filename"] for entry in entries}
    entries.extend(
        entry for entry in SUPPLEMENTAL_ENTRIES
        if entry["filename"] not in existing_filenames
    )
    entries.sort(key=lambda entry: entry["filename"].lower())
    print(f"Found {len(entries)} credited and supplemental trainer sprites")
    catalog = build_catalog(entries, args.page_url)
    write_outputs(catalog, args.page_url)
    print(f"Wrote {CATALOG_PATH} and {CREDITS_PATH}")


if __name__ == "__main__":
    main()
