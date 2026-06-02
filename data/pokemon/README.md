# Pokemon Data

This folder contains local game data generated from external sources such as PokeAPI.

- `species/`: one JSON file per Pokemon species.
- `moves/`: JSON files grouped by move type (e.g. `fire.json`, `water.json`).
- `abilities.json`: ability lookup table keyed by ability id.
- `items/`: JSON item lookup tables grouped by category (e.g. `balls`, `medicine`, `held-items`).
- `types/`: one JSON file per type.

Move entries inside type files follow:

- `id`: move id
- `name`: human-readable display name
- `type`: move type
- `category`: physical / special / status
- `base_power`: base power (or `null` for status/non-damaging moves)
- `accuracy`: accuracy value (`null` when not applicable)
- `pp`: power points
- `priority`: priority modifier

Item entries inside category files follow:

- `id`: item id
- `name`: human-readable display name
- `category`: item category matching the filename
- `short_desc`: compact UI description
- `desc`: full description for detail views
- `flavor_text`: optional Pokedex-style text
- `generation`: generation where the item was introduced
- `is_key_item`: whether the item is a key item
- `is_consumable`: whether use consumes the item
- `is_holdable`: whether a Pokemon can hold the item
- `battle_effect`: battle effect id or `null`
- `field_effect`: field effect id or `null`
- `data`: category/effect-specific structured values

File-IDs and payload IDs follow this convention:

- `id`: numeric Pokédex/form id from the source data.
- `species_id`: internal filename/identifier in lowercase kebab-case (this is what we use in-game), e.g. `mr-mime`.
- `showdown_id`: canonical Showdown identifier used for battle/API payloads, usually without punctuation or punctuation normalized.
- `name`: human-readable display name for UI only.

Forms and special cases are handled via `data/pokemon/showdown_id_overrides.json` when
we need a different `showdown_id` than the default `species_id`.
If a species is a form variant (bijv. Aegislash Shield, Mega- forms), set a mapping there so
API/battle payloads keep the canonical Showdown ID.

Gebruik `python tools/apply_showdown_id_overrides.py` om de overrides toe te passen op alle
species-bestanden.

Use lowercase kebab-case IDs for filenames and references, for example `solar-power` or `mr-mime`.
