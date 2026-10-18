# Pokémon Tower and Rocket Hideout battle arenas

`pokemon_tower` is a lavender stone memorial chamber with graves, recessed
arches, candles and a remembrance altar. `rocket_hideout` is an underground
operations room with server racks, cargo crates, consoles, ventilation, a lift
door and a mesh-built Rocket insignia.

The Tower uses deep purple-grey stone; the Hideout uses dark blue-grey concrete
and steel. Floor, wall and trim albedos are deliberately subdued under the
shared neutral battle lights. Candle, screen and insignia emission is softened
so it remains an accent. This palette is checked in Forward+ and Compatibility;
Pokémon lighting and scene-wide exposure are unchanged.

The resolver selects these interiors for trainer and wild encounters on the
Tower map and Rocket Hideout B1F–B4F / elevator. All Tower floors share one map
and therefore the same arena. These dungeon definitions retain their authored
scene for wild encounters. Explicit environment overrides and PvP keep their
existing priority; the manual development arena override also still wins.
The existing cave/grass 2D backgrounds remain in the respective profiles.

Both builders reuse the indoor geometry and stone/panel shader. They need no
external pack, generated images or native extensions. They build independently
for the display and material-response viewports, retain the neutral Pokémon
lighting, and keep the combatant floor at y=0. Raised props stay outside the
tested camera orbit; the lower foundation avoids coplanar floor flicker.

Focused verification (run through `ops/worktrees/slot-env SLOT -- godot`):

- `tests/dungeon_arenas_check.gd`: real map IDs and NPC metadata, wild/trainer/
  override/PvP selection, floor contact, mesh budget, 648 camera samples per
  arena with sightlines to both combatants, independent response-pass ownership.
- `tests/battle_arena_contract_check.gd`: shared catalog contract.
- `tests/battle_arena_kind_integration_check.gd`: actual battle host/presenter
  selection, including both new interiors for trainers and wild encounters.
- `tests/battle_environment_resolver_check.gd`: existing selection priorities.
- `tests/dungeon_arenas_preview.gd`: four orbit views and a default-camera
  geometry review; set `POKEAETHER_STAGE_OUTPUT` to the output directory.

The geometry previews contain no combatants and do not certify every species,
move camera, device or production performance.

Local slot-b review also ran the existing arena lifecycle harness against both
interiors, using the prepared Charmeleon/Persian qualification catalog. Two
cycles per arena exercised recall, send-out, physical/special moves, damage,
faint, replacement and release of both viewports. Evidence is retained in
`slot-b/dungeon-runtime.log` and `slot-b/arena-battle-previews/`. Forward+ geometry
views are in `slot-b/arena-previews-forward/`; the lifecycle run used Compatibility.
