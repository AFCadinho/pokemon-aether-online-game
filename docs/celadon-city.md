# Celadon City exterior

The hand-authored scene is `scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn`.
Its visual comes from `Celadon City.tmx` (80 × 70 tiles at 32 pixels per tile)
and stays in `generated/tiled_visuals/celadon_city/`.
Reimporting the artist visual must preserve the separate gameplay scene.

The east opening connects to Route 7's west road. Both arrival markers sit two
tiles beyond their return triggers. The world-access catalogs in both repositories
and the extended web-map module include this connection. Building interiors and
the western neighboring route are outside this exterior's scope.

Eight dialogue NPCs and ten ambient Pokémon use the existing NPC and follower
sprite systems. Their matching metadata and dialogues live in the backend's
`game-content/data/{npcs,overworld_pokemon,dialogues}/.../celadon_city.json` files.
Pokémon interactions are cries, with no battle or capture triggers.

`Tiles/Collision` blocks building footprints, trees, fences, the fountain, canal
and outer boundary. Bridge decks and garden gates stay open. When changing the
layout, check all three canal bridges, the gym garden gate, and the upper garden
footbridge. `tests/celadon_city_check.gd` checks actor reachability and pacing lanes
from Route 7, both transitions, arrivals, sprites, and atlas layout.
