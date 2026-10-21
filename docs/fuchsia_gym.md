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

`Tiles/Collision` is deliberately empty and editable. Static collision remains
owned by the user. This scene introduces no trainers, leader or Gym puzzle.

`tests/fuchsia_gym_check.gd` checks doorway trigger coverage, arrival separation,
scene/catalog endpoints, camera configuration, door animation setup and visual
atlas integrity. It does not prescribe static collision or walkable routes.
