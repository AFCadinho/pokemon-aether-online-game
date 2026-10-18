# Celadon Game Corner and Gym battle arenas

`celadon_game_corner` is an enclosed casino lounge with a wine-coloured carpet,
plum walls, gold trim, fourteen slot cabinets with stools, a token counter and
seating. Screen and marquee emission is restrained; the floor stays matte.

`celadon_gym` is Erika's conservatory: a green garden court, timber-framed
windows, planted beds, flowers, potted trees, a wooden dais and an eight-petal
Rainbow Badge. Both interiors use subdued material colours under the shared
neutral Pokémon lights. They require no external art pack or new textures.

## Selection

- `kanto_celadon_game_corner` selects `celadon_game_corner` for the Rocket guard
  and other trainer encounters.
- `kanto_celadon_gym` selects `celadon_gym`. Erika and the four Gym trainers
  explicitly select this profile, replacing their old `grass` override in the
  map and Erika's trainer resource. This
  also prevents the Gym leader's generic stadium default from taking over.
- Both definitions retain their interior for developer-triggered wild battles.
- Explicit environment overrides, PvP and manual review selection retain the
  existing precedence. The 2D profiles reuse the existing grass assets.

Each display/material-response pass owns its arena independently. All raised
scenery sits beyond the tested free-camera orbit. Both combatant spawns contact
the y=0 floor; the lower foundation avoids overlapping floor surfaces.

## Focused review

Run Godot through `ops/worktrees/slot-env SLOT --`:

- `tests/celadon_interior_arenas_check.gd`: real map/NPC metadata after profile
  application, routing priorities, floor support, mesh budget, 648 camera
  samples per arena and independent response-pass lifetime.
- `tests/celadon_gym_trainers_check.gd`: all five trainers keep their existing
  placement, identity, portraits and progression while using the new profile.
- `tests/battle_arena_contract_check.gd` and
  `tests/battle_arena_kind_integration_check.gd`: catalog and battle-host routing.
- `tests/dungeon_arenas_preview.gd`: set
  `POKEAETHER_TEST_ARENAS=celadon_game_corner,celadon_gym` and
  `POKEAETHER_STAGE_OUTPUT` to capture the four orbit angles and a fixed close
  geometry view. Review both Forward+ and Compatibility.

Geometry previews are not certification of every species, move camera or device.
