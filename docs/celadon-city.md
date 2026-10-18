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
and Game Corner also connect to the city (see below), along with Celadon Gym.
Other building interiors and the western neighboring route are not connected yet.

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

## Celadon Game Corner

`scenes/overworld/kanto/towns/celadon_city/game_corner.tscn` uses the active
`Celadon Game Corner.tmx` (28 × 21 tiles), with the generated visual stored in
`generated/tiled_visuals/celadon_game_corner/`. The city entrance covers the
visible door at **(39,27)** and returns to **(39,29)**. Inside, the full south
threshold **(12–14,18)** returns outside; arrival **(13,16)** faces north and
avoids the exit trigger.

Collision follows the current drawing layers. The forty low blue cushions stay
walkable and render below players. Machine banks, sofas, plants, the counter,
walls and the enclosed staff space stay solid. The Rocket Hideout staircase
at (24–25,5) now connects to B1F, returning to (23,5).
The machines are scenery in this scene. See [rocket-hideout.md](rocket-hideout.md)
for the four basement maps and lift.

The interior shares Celadon City access settings, uses indoor lighting without
weather, and is included in the extended browser map module and both world-access
catalogs. `tests/celadon_game_corner_check.gd` verifies the public routes, all
forty standing spots, collision, safe doorway travel, atlas layout and registration.
Account-service tests check the authoritative city/interior round trip. A live
player walkthrough has not been performed.

The Game Corner has a black `FloorVisibilityMask` around its 896 × 672 canvas.
Host Iris can be approached across the reception counter; Bram stands on a
walkable cushion, and Ava, Niels and Faye patrol separate short lanes.
Meowth and Pikachu wander independently while Porygon watches a screen.
All eight added visitors have dialogue in English, Dutch, Brazilian Portuguese
and Simplified Chinese. Their lanes avoid the entrance, guard and hideout
approaches. `tests/game_corner_population_check.gd` verifies the mask polygons,
reception interaction, artwork, access and actual patrol movement; game-content's
`tests/test_game_corner_population.py` checks localized catalog resolution.

Iris also operates the Casino Token counter. The existing `casino_tokens`
wallet balance is credited at a fixed rate of ₽100 per token, with 10/50/100/500
bundles and no membership or volume discount. This phase only sells tokens;
games, prize redemption and a reverse exchange are not provided. Tokens stay
in the account wallet rather than inventory or trade slots.

`PlayerWalletService` calls `/game/casino/tokens` and its `/purchase` endpoint,
updates the authoritative wallet and retains uncertain purchase request IDs for
safe retry. The NPC saves the player's position before opening its themed
counter. Account-service checks Iris's map/position, current activity, reserved
trade money and the token balance cap. Purchases use the existing
`NpcMarketPurchase` receipt table and a user/wallet lock; money, tokens, receipt
and activity history commit together. No schema migration is needed.

Focused checks: `tests/casino_token_vendor_check.gd` and account-service's
`tests/test_casino_tokens.py`, alongside the existing Game Corner population and
guard checks. PostgreSQL concurrent execution has not been exercised by the
SQLite service tests; they cover receipt replay and the post-lock replay branch.

## Celadon Gym

The active artist `Celadon Gym.tmx` is imported into
`generated/tiled_visuals/celadon_gym/`; its gameplay scene is
`scenes/overworld/kanto/towns/celadon_city/celadon_gym.tscn`. The city door at
**(11,48)** enters the Gym at **(20,62)**, facing up. The full three-tile south
threshold at **(19–21,64)** returns to the city forecourt at **(11,50)**, facing
down. Both arrivals avoid immediate re-entry.

The Gym shares Celadon City's access group, uses indoor lighting without weather,
and selects the shared `gym.interior` music profile. The browser module and both
world-access catalogs register its canonical scene and reciprocal doorway travel.
The existing Celadon region-map entry already lists the Gym.

Collision follows the current V4 garden layout. Hedges, flowers on every drawing
layer, trees, benches and fountains block movement. All eleven pergolas retain
two open middle columns; the three middle stair columns remain walkable. The
stage and entrance gardens remain physically enclosed, including their isolated
decorative floor cells. All 25 garden rooms, both fountain courts and the leader
position at (20,10) are reachable from the entrance. The shortest route is 120
tiles across 730 reachable public tiles. The flower clues retain their original
pink → white → yellow artwork. Both fountains retain all 24 animation frames and
100 ms timing on every part.

`tests/celadon_gym_check.gd` covers those routes and collision, enclosed gardens,
free circulation around the fountains, animation timing, safe arrivals, atlas
layout and browser/server registration. Account-service tests cover the round
trip and denied entry to a closed Gym. Canonical Godot resource compositions
were visually reviewed; a live player walkthrough has not been performed.


## Celadon Prize Corner

`celadon_prize_corner.tscn` imports the artist `Celadon Prize Corner.tmx`
(16 × 17 tiles, 32 px) into `generated/tiled_visuals/celadon_prize_corner/`.
The supplied preview is the matching visual reference; no source art is changed.
The small city door immediately east of Game Corner is at **(44,27)**,
returning to **(44,29)**. Inside, **(7–8,14)** is the complete two-tile
exit and **(7,12)** is the arrival, facing north, clear of the return trigger.

Hand-authored collision follows the artist footprint handoff: 66 connected
public tiles and 10 isolated staff tiles. The counter, sofas, plants and
cutaway perimeter stay solid. A black FloorVisibilityMask covers the exterior
of the 512 × 544 canvas. Indoor lighting, disabled weather, Celadon access
grouping and the extended browser module match the other city interiors.
The three service counters remain scenery pending a separate prize-service task.

`tests/celadon_prize_corner_check.gd` checks actual player movement predicates,
public circulation, boundary collision, the full exit aperture, safe reciprocal
arrivals, runtime mask initialization, imported layer counts and atlas layout.
Account-service tests check canonical travel and denied-entry preservation.
Native Tiled and Godot renders were inspected; no live server walkthrough was
performed.

Regenerating the paired access catalogs also synchronizes the already saved
Celadon arrival-marker edits (city, Department Store, Game Corner and Hideout
B1F). The second Department Store exit now has its own
`kanto_celadon_department_store__to_outside_east` transition ID, resolving the
previous duplicate without moving either exit.

The native Tiled render exactly matches the supplied preview. The Godot render
has the same geometry; alpha blending differs by at most one RGB level on
4,778 of 278,528 pixels. Prize Corner's browser selection/exclusion is checked.
The general browser partition check still reports the same 15 pre-existing
unlisted maps as the task base; a full web export was not run.
