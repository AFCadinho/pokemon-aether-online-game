# Pokémon sprite asset provenance

Large Pokémon sprite packs are distributed through the PokeAether launcher and
are intentionally excluded from Git. Tracked import manifests and tools must
still make targeted additions reproducible and auditable.

## Mega Champions source

The Phase 3 Mega Champions additions use `Generation 9 Pack` version `3.3.6`,
published by Caruban at <https://www.eeveeexpo.com/threads/5817/>. The reviewed
local bundle pins these source metadata hashes:

- `Credits.txt`: `d9d782f9f01fbc4f33352619ad48dcd3c83eb72591b436e5a551e6bcaebd6b21`;
- `Changelog.txt`: `2e31d1b30906ba0e907d558def8c48a5eb3a260638217fd5cfbfea731de61f50`.

Its PLZA sprite credits name Caruban, ace_stryfe, KingOfThe-X-Roads,
camiloveso, and Mak. The bundle does not contain an explicit license
declaration, so repository metadata records that fact instead of assigning an
unverified license. The user approved this source for the targeted PokeAether
import and R2 publication on 2026-08-21.

`tools/import_mega_champions_sprite_assets.py` maps the reviewed PBS form
indexes to 15 canonical PokeAether species keys: the twelve previously missing
mappings plus corrections for Floette, regular Magearna, and Zygarde. It
imports front, back, shiny-front, shiny-back, normal icon, and shiny icon data.
The exact source paths and hashes are recorded in
`data/mega_champions_sprite_imports.generated.json`.

Use the importer with the reviewed unpacked source, then verify it before
packaging:

```bash
python3 tools/import_mega_champions_sprite_assets.py \
  --source-root /path/to/gen9_asset_pack
python3 tools/import_mega_champions_sprite_assets.py \
  --source-root /path/to/gen9_asset_pack --check
```

Publish only through `tools/upload_sprite_asset_packs.py`; do not manually
edit launcher manifest versions or upload individual unpacked sprite files.
