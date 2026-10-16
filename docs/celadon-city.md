# Celadon City exterior

The hand-authored scene is `scenes/overworld/kanto/towns/celadon_city/celadon_city.tscn`.
Its visual comes from `Celadon City.tmx` (80 × 70 tiles at 32 pixels per tile)
and stays in `generated/tiled_visuals/celadon_city/`.
Reimporting the artist visual must preserve the separate gameplay scene.

The east opening connects to Route 7's west road. Both arrival markers sit two
tiles beyond their return triggers. The world-access catalogs in both repositories
and the extended web-map module include this connection.

The northeastern Pokémon Center uses the shared Center template, with its own
healing/respawn identity, four visitors and four companion Pokémon. Nurse Joy’s
respawn payload targets the canonical `Spawns/HealNPC` marker. Celadon Condominiums
also connects to the city (see below). Other building interiors and the western
neighboring route are not connected yet.

Eight dialogue NPCs and ten ambient Pokémon use the existing NPC and follower
sprite systems. Their matching metadata and dialogues live in the backend's
`game-content/data/{npcs,overworld_pokemon,dialogues}/.../celadon_city.json` files.
Pokémon interactions are cries, with no battle or capture triggers.

`Tiles/Collision` blocks building footprints, trees, fences, the fountain, canal
and outer boundary. Bridge decks and garden gates stay open. When changing the
layout, check all three canal bridges, the gym garden gate, and the upper garden
footbridge. `tests/celadon_city_check.gd` checks actor reachability and pacing lanes
from Route 7, both transitions, arrivals, sprites, and atlas layout.

## Celadon Condominiums

Five independent gameplay scenes (`celadon_condominiums_{1f,2f,3f,roof,roof_room}.tscn`)
use the corresponding artist TMXs in `interior/celadon_city/`. Their imported
visuals remain separate from editable gameplay collision and transitions. All
five maps belong to the Celadon City world-access group and extended browser map
module; server catalogs register each floor and every transition in both directions.

The front entrance uses the visible city door at **(40,12)**, returning to
**(40,14)**. The hidden rear entrance is on the upper western side at **(37,7)**,
returning west to **(36,7)**. Transition hints mark both entries. The narrow
western approach at x=36, y=7–14 is open; the city art is unchanged.

The front hall and rear stairwell stay isolated on 1F, 2F and 3F. On the roof,
the front staircase reaches the main terrace, while the rear staircase reaches
the enclosed courtyard and rooftop room. There is no crossover through the
walls or roof railing. Interior lighting/weather apply indoors; the roof uses
outdoor lighting and weather. Collision follows the current edited furniture,
not the older artist check reports.

The Tiled connection metadata predates several stair-art moves. Gameplay uses
the current steps: 1F up at (8,5)/(18,5), 2F up at (3,5)/(13,5), 2F down at
(8,4)/(18,4), and 3F up at (8,5)/(18,5). Reciprocal arrivals were moved with them;
other source connection coordinates are preserved. Each arrival is clear of
all transition footprints to prevent bounce-back.

`tests/celadon_condominiums_check.gd` verifies complete floor reachability,
isolated access zones, furniture/wall collision, safe reciprocal arrivals,
city access from Route 7, atlas layout and browser/server registration. Account
service tests cover authoritative travel through both stairwells and the rooftop
room. A live player walkthrough remains useful for visual movement review.
