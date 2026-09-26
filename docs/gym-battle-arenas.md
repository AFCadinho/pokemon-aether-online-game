# Pewter and Cerulean Gym battle arenas

## Selection

| Map | Environment / arena | Battles |
| --- | --- | --- |
| `kanto_pewter_city_gym` | `pewter_city_gym` | Brock, Hiker Flint, Youngster Stone |
| `kanto_cerulean_city_gym` | `cerulean_city_gym` | Misty, Swimmer Luis, Picnicker Diana, Swimmer Briana |

The auto arena setting resolves the actual indoor map IDs. Explicit overrides
and PvP keep their existing precedence. Indoor wild/water contexts retain the
gym hall. Surrounding cities and routes keep their own environments.

Brock and Misty have explicit scene overrides because the shared gym leader
script otherwise selects `pvp_stadium`. Cerulean's three support trainers now
explicitly select their gym instead of the generic water arena. Trainer metadata
and the editor's override enums support the new IDs. No battle rules, trainer
teams, progression, music or Pokémon materials are changed.

## Art and layout

Both interiors are authored from the bundled pixel gym maps:

- **Pewter:** warm coursed stone walls, tiled perimeter, sandy marked court,
  low irregular rock clusters and small plants, boulder gardens, stone piers,
  amber lanterns, raised Brock dais, Boulder Badge relief, entrance guardians.
- **Cerulean:** turquoise pool hall with high framed windows, yellow timber
  walkways, blue/yellow lane floats, red/white life rings, benches, starting
  blocks, raised Misty dais with a blue/white parasol, Cascade Badge relief
  and entrance guardians. A level tiled battle island keeps grounded Pokémon
  above the decorative pool surface.

The new architecture, props and surface/water shaders are original repository
assets, built from Godot meshes. They need no external asset download, forest
art pack or native extension. Both the normal and material-response viewport
build the same deterministic layout. Each hall has four walls and a ceiling;
all camera yaw, pitch and zoom limits remain inside the room. The existing
neutral actor lighting is retained. Enclosure meshes do not cast directional
shadows over the battle area; the fighters still cast their normal shadows.
Indoor lighting does not follow outdoor time or weather.

The existing cave/water backgrounds remain the 2D fallback for Pewter/Cerulean.
These changes supply new **3D** arenas only.

## Focused verification

Run through `ops/worktrees/slot-env SLOT -- godot --headless --path FRONTEND`:

- `--script res://tests/gym_arenas_check.gd`: map and real NPC metadata selection,
  profile fallbacks, dry spawn contact, indoor camera bounds and unobstructed
  fighter sightlines at 648 camera positions per gym.
- `--script res://tests/battle_arena_contract_check.gd`
- `--script res://tests/battle_environment_resolver_check.gd`
- `--script res://tests/cerulean_gym_trainers_check.gd`
- `--script res://tests/gym_leader_alpha_hub_check.gd`

For GPU visual review use `tests/routes_1_22_orbit_preview.gd` with arguments
`-- pewter_city_gym cerulean_city_gym`, `SUMMARY_MODEL_CATALOG` pointing to the
approved local catalog, and `POKEAETHER_STAGE_OUTPUT` to an ignored output
folder. No forest manifest is needed. It renders Dragonite and Roaring Moon
from eight yaw angles in daylight, at night, and at both camera pitch limits
with maximum zoom distance. Inspect the contact sheets as well as full-size
frames for surface overlap, foreground obstructions and exposed sky.
