# Content packs v1

## Available in this foundation

The desktop launcher has a **Mods** button. **Installed** imports local zip
packs. **Customize** selects one installed pack per supported category, so each category uses either its selected pack or the game default. Changes apply at the next game start.
**Discover** loads the configured HTTPS catalog and installs official packs with
the launcher's resumable downloader, verified size and SHA-256 checksum.

Supported overrides are Pokémon battle sprites (front/back, normal/shiny),
followers and Ogg Vorbis cries. Packs are cosmetic data, not scripts. Party icons,
trainer sprites, world tiles and additional battle action animations are outside
v1. Missing or undecodable overrides fall through to the next pack and then to
the game's existing assets. Forms and shiny variants require explicit entries.

The existing Anime Cries setting still works as the cry fallback. Converting it
into an official downloadable pack and removing that setting is a later migration.
Game volume controls continue to apply to modded cries.

## Make a pack

Create a folder with `mod.json` at its root and your PNG/Ogg files alongside it.
Use [the example manifest](examples/content-pack/mod.json) as a template. Remove
categories or entries you do not provide. The example references artwork and
audio you must supply; it is a template, not a complete installable pack.

```text
my-pikachu-pack/
  mod.json
  sprites/pikachu-front.png
  followers/pikachu.png
  cries/pikachu.ogg
```

Select the **contents** of this folder and create a zip, so `mod.json` is at the
archive root. Import it in the launcher and enable it. Alternatively open the
mods folder and place the folder there; its name must equal the manifest `id`.
Press Refresh after manual changes. Godot and the game source are not needed.

Required manifest fields: `format_version: 1`, `id`, `name`, `version`, `author`,
and `assets`. IDs contain lowercase ASCII letters, numbers, hyphens or underscores
and are at most 80 characters. Optional `description` appears as a tooltip.

Asset keys use the game's species ID, in lowercase with hyphens, for example
`pikachu`, `mr-mime`, `nidoran-f`, `charizard-mega-x`. Runtime input normalizes spaces
and underscores to hyphens and removes apostrophes, periods and colons.

| Category | Entry key | File and metadata |
| --- | --- | --- |
| `cries` | `pikachu` | `file`: Ogg **Vorbis**, not Opus |
| `battle_sprites` | `pikachu:front:normal` | `file`: PNG, optionally `columns`, `rows`, `frames`, `fps`, `scale`, `anchor`, `offset` |
| `battle_sprites` | `pikachu:back:shiny` | Explicit shiny back sprite |
| `followers` | `pikachu:normal` | `file`: PNG with the game's existing 4×4 follower grid |
| `sprite_collections` | `gen5` | `directory`: a pack directory; `style`: `gen5`; contains the Gen 5 sheet and animation files |

Battle sheets contain equal-sized cells read left to right, then top to bottom.
Defaults are one column, one row, one frame, 10 fps and scale 1. Grid dimensions
must divide the image exactly. `frames` may be smaller than the cell count. V1
plays the sheet as a looping idle animation; existing battle effects still apply.
`scale` multiplies the game's base battle-sprite display size (0 < scale <= 10).
`anchor` is an optional `[x, y]` in cell pixels; default is the cell center.
`offset` is an optional `[x, y]` battle position adjustment; default is `[0, 0]`.

Followers use four columns and four direction rows: down, left, right, up.
Existing species-specific direction conventions still apply (Dreepy differs).
Use separate `:shiny` entries for shiny followers.

## Storage and priority

Packs live in the launcher's `user://mods`, outside the game installation/update
folder. **Open mods folder** opens the correct location. The launcher passes its
absolute path to the child game through `POKEAETHER_MODS_DIR`, then restores its
own previous environment value. The game and launcher share the same pack parser.

`enabled.json` contains the selected pack ID for each category. The launcher
writes it via a temporary file. Newly imported packs are disabled. Manual imports
reject an existing ID. Official catalog updates stage the new pack first, replace
the old folder only after a valid import, and restore the old folder if replacement
fails.

The desktop game snapshots the selection at startup, and caches up to 96
decoded results. Restart after changing packs or assets. Direct editor launches
use the game's `user://mods` unless `POKEAETHER_MODS_DIR` is explicitly provided.
Browser builds ignore local packs.

The loader accepts relative paths inside a pack, skips linked pack paths and
extracts only declared PNG/Ogg assets, declared Gen 5 sprite collection PNG/JSON
files, and the manifest. Zip import stages files before making a pack visible.
Unsupported schemas, traversal, duplicate zip names, encrypted/multipart/ZIP64
archives, and oversized archives are rejected. Limits: 2 MiB manifest, 64 MiB per
file, 2 GiB total, 20,000 zip entries, 8192 pixels per image dimension and
16,777,216 pixels per image. Image/audio decoding failures still fall back at
runtime; import is not a full artistic/audio quality review.

## Official catalog and R2 publication

The catalog URL is `https://updates.pokeaether.com/data/content-packs.json`.
Keep it separate from required game-update assets. Entries have this shape:

```json
{
  "id": "anime-cries",
  "name": "Anime Cries",
  "version": "1.0.0",
  "author": "PokeAether",
  "description": "Anime cries for available Pokémon from generations 1–7.",
  "categories": ["cries"],
  "download": {
    "url": "https://updates.pokeaether.com/mods/anime-cries-1.0.0.zip",
    "sha256": "<actual SHA-256 of the zip>",
    "size_bytes": 123456
  }
}
```

Build both official packs and a real catalog with:

```sh
python3 tools/package_official_content_packs.py --output-dir builds/content-packs
```

This produces `anime-cries-*.zip`, `gen5-animated-sprites-*.zip` and
`content-packs.json`. It uses content hashes as immutable versions and does not
publish anything. With configured R2 credentials, the explicit command below
uploads immutable zips under `mods/` and the catalog as `data/content-packs.json`:

```sh
python3 tools/package_official_content_packs.py --output-dir builds/content-packs --upload
```

Catalog presence is curated; imported player packs do not appear online
automatically. The Gen 5 archive is roughly 1.2 GiB uncompressed and is a single
optional download to preserve every existing sheet and animation definition.

## Implementation and checks

- `launcher/scripts/content_pack_store.gd`: shared format, selection, import.
- `launcher/scripts/content_packs_panel.gd`: launcher management panel.
- `scripts/services/content_pack_runtime.gd`: desktop asset decoding and caches.
- Hooks: `sprite_box.gd`, `follower_sprite_service.gd`, `sfx_manager.gd`.
- `tests/content_packs_check.gd`: real zip, PNG and Ogg fixtures, priority,
  fallback, form/shiny identity, selection persistence and invalid imports.
- `launcher/tests/content_packs_panel_check.gd`: translated panel and enable flow;
  graphical runs save a review image under the slot's test logs.
- `tools/package_official_content_packs.py`: builds the Anime Cries and complete
  Gen 5 animation archives, catalog and optional R2 upload.
