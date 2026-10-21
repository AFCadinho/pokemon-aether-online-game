# Fuchsia City Gym

The artist source is `kanto/artist/interior/fuchsia_city/Fuchsia Gym.tmx`.
Import it with `addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd`
and visual ID `fuchsia_gym`. The runtime scene is
`scenes/overworld/kanto/towns/fuchsia_city/fuchsia_gym.tscn`.

The one-floor interior uses indoor lighting, disabled weather, the Gym music
profile and the shared floor camera mask. Its map ID is `kanto_fuchsia_gym`.

The artist connection markers define both arrivals: interior tile (14, 29),
facing up, and city tile (31, 35), facing down. The three-tile southern exit
returns to `FromGym`; city `ToGym` enters at `FromFuchsiaCity`. City `Door76`
is enabled and prepares its animation when returning from the Gym.

`Tiles/Collision` contains the user-authored room/furniture collision and remains
owned by the user. This scene introduces no trainers or leader. The invisible-wall puzzle lives
separately in `Entities/Interactables/InvisibleWalls`.

`tests/fuchsia_gym_check.gd` checks doorway trigger coverage, arrival separation,
scene/catalog endpoints, camera configuration, door animation setup and visual
atlas integrity. It does not prescribe static collision or walkable routes.

## Invisible-wall puzzle

Reference: the FireRed/LeafGreen Gym, not the different HGSS Janine layout.
The wall pattern was read from the [original FRLG map image](https://archives.bulbagarden.net/wiki/File:Fuchsia_Gym_FRLG.png)
and the [pret map data](https://github.com/pret/pokefirered/blob/master/data/layouts/FuchsiaCity_Gym/map.bin),
with its [15×23 layout definition](https://github.com/pret/pokefirered/blob/master/data/layouts/layouts.json).
Only invisible wall/pillar positions inform the puzzle; no original graphics,
trainer rosters or event scripts are included.

The middle thirteen columns retain their tile spacing, translated seven columns
right. The outer column expands to the artist room edge. Two repeated straight
corridor rows are collapsed so the original 3×3 leader podium aligns with the
artist podium. The northern crossing runs below the benches. A hidden perimeter
prevents shortcuts around the side-anchored maze through the larger room.
The intended journey is entrance → east corridor → north crossing → west-side
turns → central chamber → return through the same maze. `MazeCenter` marks the
future leader position at the podium's center, tile (14, 17).

The `InvisibleWalls` TileMapLayer is hidden in play and uses the existing map
blocker discovery path. Toggle its visibility in Godot to inspect/paint it, and
hide it again before saving. Any occupied cell blocks; erasing a cell opens it.
`blocking_enabled` can disable the puzzle without erasing its cells. It never
writes to `Tiles/Collision` or to the imported visual.

`tests/invisible_wall_layer_check.gd` uses a small independent fixture to check
world-coordinate transforms, blocker discovery, real player movement, disabling
and live edits. The authored Gym route and perimeter were reviewed with a
one-off runtime probe; they are intentionally not frozen in release assertions.

Reference map.bin SHA-256: `8f465f6950e687f0e56954c55d4571202eee500e3c41b9014db7610a396893f0`.
