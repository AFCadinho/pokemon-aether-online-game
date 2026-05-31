# Pokemon Data

This folder contains local game data generated from external sources such as PokeAPI.

- `species/`: one JSON file per Pokemon species.
- `moves/`: one JSON file per move.
- `abilities/`: one JSON file per ability.
- `types/`: one JSON file per type.

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
