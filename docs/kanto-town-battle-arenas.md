# Pallet Town, Viridian City and Pewter City arenas

## Map identity and source art

The three outdoor maps now select their own 3D arena automatically:

| Map ID | Land environment | Water environment |
| --- | --- | --- |
| `kanto_pallet_town` | `pallet_town` | `pallet_town_water` |
| `kanto_viridian_city` | `viridian_city` | `viridian_city_water` |
| `kanto_pewter_city` | `pewter_city` | No outdoor water encounter area |

The layouts were composed from the actual generated pixel visuals:
`pallet_town_compact`, `viridian_city` and `pewter_city`. They interpret the maps
at battle scale, with clear space for both fighters and the complete camera orbit.

- **Pallet:** two teal-roofed homes, Oak's larger orange-roofed timber lab,
  garden fences, northern terrace stairs, dense woodland and a fishing pier.
  The southern/southwestern shore explicitly opens onto the ocean toward
  Cinnabar. This is an open sea to the horizon, not a closed pond. The coast
  shader and terrain use the same shoreline function. Hills and vegetation
  stop at the shoreline; no enclosing cliff or tree wall crosses the ocean.
- **Viridian:** green-roofed homes, elevated Gym and stairs, clock-front trainer
  school, Pokémon Center, paved paths, lamps, planted gardens and a southwestern
  pond, backed by western mountains and surrounding woodland. The western EV
  training strip has dense tall grass, white fencing, north/south entrances
  and an EV sign, matching the existing gameplay field.
- **Pewter:** stone plaza, raised Gym/museum terrace with steps, large clock-front
  museum, fountain, blue-roofed homes, Pokémon Center, central tree garden,
  excavation plot and surrounding rocky shelves. Planter rims contain the
  flower beds on the paved plaza.

The map IDs come from the real map scripts/scenes. Explicit environment
overrides, manual arena selections and PvP keep their previous priority.
Gym interiors, homes and Oak's lab remain separate maps. In particular,
Pewter's outdoor arena does not replace its recently added indoor gym arena.

Water encounter types (surf and all fishing rods) and `player_on_water` select
the water presentation in Pallet/Viridian. Their water origins are respectively
`(-32, 0, 29)` and `(-32, 0, 27)`. Ground contact is kept 0.22 units below the
surface using the existing shallow-water actor contract. Land contact remains
at the established `BASE_HEIGHT`. The ordinary grass/water images remain the
2D fallbacks. No encounter chances, progression, battles or Pokémon assets change.

## Assets and presentation

The builders reuse the shared mesh terrain, weak caches, environment pool,
forest art pack, bundled nature details and outdoor day/night lighting.
New original mesh landmarks are in `shared/kanto_city_landmarks.gd`; the town
helper adds city paving and planter borders. No external download, extra native
addon or new model bundle is required. The ocean mesh extends well past the
terrain grid so its edge cannot appear during a normal camera orbit.

## Focused checks

Run Godot through `ops/worktrees/slot-env SLOT -- ...`:

- `tests/kanto_cities_arena_check.gd`: all five profiles, map/terrain resolution,
  override precedence, interior isolation, both rendering passes, landmarks,
  spawn contact, water depth, stair landings and repeated arena-switch cleanup.
  Set `POKEAETHER_FOREST_MANIFEST` to exercise geometry and the render pool.
  With a GPU renderer it also counts the actual grass instances inside the EV
  field; the dummy headless renderer does not retain MultiMesh transforms.
- `tests/routes_1_22_orbit_check.gd -- pallet_town pallet_town_water viridian_city viridian_city_water pewter_city`:
  432 camera positions per arena; terrain sightlines, tree and landmark
  clearance, and continuous scenery or the intentionally open Pallet ocean.
- `tests/battle_arena_contract_check.gd`
- `tests/battle_environment_resolver_check.gd`
- `tests/gym_arenas_check.gd`: retain the separate gym interiors and trainer
  overrides after adding their surrounding outdoor city.

GPU review uses `tests/routes_1_22_orbit_preview.gd` with those same five IDs,
`SUMMARY_MODEL_CATALOG`, `POKEAETHER_FOREST_MANIFEST` and an ignored
`POKEAETHER_STAGE_OUTPUT` directory. It captures the actual Dragonite/Roaring
Moon battle renderer in eight directions at day/night and both camera pitch
limits with maximum zoom distance. These are offline focused checks; no live
backend battle or full release certification is part of this scenery task.
