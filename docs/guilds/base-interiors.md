# Guild Base interiors

The first playable base is Vermilion City. Its fixed main hall, two initially
empty side rooms, lift waiting room and lift cabin are separate reusable scenes
under `scenes/overworld/kanto/guild_base/`. The garden remains on the city map.

The ordinary MapExit / WorldTransitionService / authorized teleport flow owns
all doors. The account service resolves each template into a private map ID:
`guild_base:<townId>:<guildId>:<roomKey>`. Room keys are `main_hall`, `left_room`,
`right_room`, `elevator`, and `elevator_cabin`. A room scene is shared by every
Guild; no per-Guild scene files or extra purchase rows are required. Base
ownership stays on Guild.

Guild Base access requires current membership in an active Guild based in that
city. All ranks can enter. The purchase requirements remain level 10 and a
one-time 1,000,000 Guild Bank payment. Lowering the Guild's level after purchase
does not revoke its purchased base. Room changes require a nearby source door,
an idle player, and no pending teleport. Position autosave cannot establish a
new room or claim a different Guild's instance.

World presence is indexed by the full private map ID. Before publishing a
private roster, the gateway verifies both server position and current Guild
ownership through `/internal/guild-bases/presence`; internal service credentials
are required. Movement reuses that check for at most five seconds, and every
room change checks again. Public map updates do not incur this check. The HTTP
map-player fallback also excludes former members. Generic staff teleport pickers
exclude the ownerless templates.

Saved positions preserve the private instance at login. Membership loss,
disbanding or a moved/revoked base recover the player outside the old garden's
gate; the rooms also reconcile position every 15 seconds and when membership
changes. Valid owners exit normally into their town garden. A pending authorized
exit is preserved during recovery.

Visuals are generated from the artist TMXs. Keep gameplay collisions, spawn
markers and exits in the runtime scenes. Reimport the current artist versions
through the assigned slot:

```sh
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend \
  --script res://tools/import_guild_base_visuals.gd -- \
  /home/adinho/Documents/tiled_pokeaether/kanto/artist/interior/guild_base
```

The right room mirrors its visual so its entrance faces the main hall. Gameplay
coordinates stay local to the room scene. Layer names and original artist TMXs
are preserved; the lift's final foreground layer is exposed to the runtime's
existing object depth sorter. Runtime collision preserves the authored lobby
and lift layer. Empty side rooms use explicit floor masks; furniture adds its
own movement footprints without changing terrain tiles.

`Entities/Furniture` holds runtime furniture in each side room. The account
service stores both room layouts and shared inventory in `guild_base_furnishings`,
keyed by Guild. Stable placement IDs and local tile coordinates are independent
of town. The lobby and lift retain their fixed art and authored collision.

In either side room, the leader can choose **Furnish room** to open the catalog.
Select furniture and click a valid green preview to place it. **Select / move**
selects existing furniture; **Return to storage** removes it. Each click saves
on the server. **Done** or Escape restores the camera and walking controls.
Red previews reject overlaps, invisible artwork, blocked routes and occupied
player tiles. The entrance remains clear. Rugs have adjustable dimensions and
allow furniture on top; flowers and plates attach to the pointed-at tabletop
grid cell (six on small tables, eight on large tables) and follow the table
when moved. Occupied cells show a red preview instead of jumping to another
cell. Returning a table returns its decorations too.

The catalog contains 129 reusable scenes in `scenes/world/guild_base/furniture/`,
organized into ten categories. Alongside the original 24 designs, it includes
colored seating, glass and wooden tables, bookcases and dressers, single and
double beds, plants, tabletop decorations, rugs and decorative laboratory
capsules. These are decoration assets; lab displays do not provide gameplay
services. Tables and low dressers provide surface slots. Regular furniture
blocks its movement footprint; rugs remain walkable.
Each uses a `TileMapLayer` with a compact shared atlas, a movement footprint and
the existing character-blocking protocol. Tall art renders above its footprint;
the player remains sorted by feet. The original decorated TMXs are references,
not preplaced layouts. Their selected tiles can be rebuilt without editing the
artist sources. The shared indoor sheet credits Akizakura16, Shiny570 and
Ultimospriter; the catalog records this source attribution:

```sh
python tools/import_guild_base_furniture.py \
  '/home/adinho/Documents/tiled_pokeaether/kanto/artist/tilesets/inside/Indoors Tileset.tsx'
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend --import
ops/worktrees/slot-env SLOT -- godot --headless --path .worktrees/SLOT/frontend \
  --script res://tools/import_guild_base_furniture.gd
```

Keep `data/guild_base_furniture.json` byte-identical to the account-service
catalog. The first visit initializes a finite starter inventory once. Catalog
version 2 seeds missing furniture IDs on the first subsequent visit or edit,
under the same Guild lock as layout saves. It preserves existing totals,
including zero, unknown legacy inventory IDs, layouts, revisions and leases.
Both side rooms draw from the shared inventory. This version does not buy
furniture or charge the Guild Bank. Personal rooms retain their separate empty
template and do not yet use this Guild-shared editor.
The leader grants explicit decorating rights through **Decorating rights**;
Guild rank alone does not grant them. One editor per room holds a server lease,
renewed while editing. Concurrent saves in different rooms share a Guild lock,
so they cannot spend the same furniture copy. Save revisions prevent old layouts
from overwriting new ones. Revision-only world-presence notifications trigger a
fresh authorized fetch; ten-second polling also reconciles layouts after an outage.
Offline player positions covered by new furniture recover to nearby clear floor
through the existing authorized teleport flow on login.

The upper door of the waiting room enters `elevator_cabin.tscn`. A
receptionist behind its left counter opens a searchable member directory,
including **Find my room**. The cabin attendant lists assigned floors and the
ground floor in a bounded number grid. The lift search filters by an exact
floor number or a member name; ground-floor and personal-room shortcuts stay
above the scroll area, and the selected destination/travel action stay below
it. **Find my room** clears filters and scrolls to the assigned floor. The grid
adapts to the window width, with stacked shortcuts on narrow windows.
Choosing a floor opens its hallway; the ground floor opens the
waiting room. Entering a cabin from an upper hallway carries that floor in the
instance ID, so leaving without selecting another destination returns there.

`player_floor.tscn` reuses `Guild Base Player Floor.tmx` for every hallway.
Its four rooms are numbered **1–4 from left to right on each floor**. The
central door returns to the lift. `player_room.tscn` reuses the empty
`Guild Base Player Room.tmx`, retaining all four layers, with collision,
a lower return door, a visibility mask and constrained camera. Guild members
can visit occupied rooms in their own base; empty room doors report that no
member is assigned. Personal-room furnishing and leader-controlled room
reassignment remain future work.

The server lazily assigns rooms when either attendant is first visited (and
reconciles new members on later visits/room transitions). Each membership has a
nullable zero-based `base_room_slot`, unique within its Guild. Assignment holds
the Guild lock, keeps occupied slots unchanged and fills the first free slot
in join order. Departure deletes the membership/slot; other members retain
their addresses. Floor = slot // 4 + 1, room = slot % 4 + 1. Only floors with
assigned rooms appear in the lift. Migration `0325_guild_base_player_rooms`
adds this field and its unique/check constraints.

Private IDs use `guild_base:<town>:<guild>:player_floor_<floor>`,
`player_room_<slot+1>` and `elevator_cabin_<floor>` for upper cabins. The
existing `elevator_cabin` ID is the ground-floor cabin. Shared templates are
registered in the world-access catalog but excluded from staff teleport
choices. The server checks Guild membership, assigned destinations, current
room, door/NPC proximity, idle state and pending teleports. Presence retains
full instance identity; leaving a Guild revokes access to rooms and floors.

For Celadon/Saffron, add their actual city entrance/return points and registrars
before enabling purchases. Reuse the room scenes; extend the server door/return
contract and town access rather than duplicating maps per Guild or town.

Focused checks: `tests/guild_base_interior_check.gd`,
`tests/guild_base_player_floor_check.gd`, `tests/guild_base_player_rooms_check.gd`,
`tests/guild_base_furnishing_check.gd` (add `-- --screenshot` with a graphics
renderer for a visual preview), account-service `tests.test_guild_base_interiors`,
`tests.test_guild_base_furniture`, `tests.test_guild_base_player_rooms`, and gateway `tests.test_guild_base_presence`
and `tests.test_guild_base_furniture_events`. Optional account-service
`tests.test_guild_base_furniture_postgres.PostgresFurnitureTests` tests migration
and concurrency when `GUILD_FURNITURE_TEST_DATABASE_URL` points at a disposable
PostgreSQL database; it creates and drops its own randomly named test schemas.

Focused player-room PostgreSQL checks: `tests.test_guild_base_player_rooms_postgres`
uses `GUILD_ROOM_TEST_DATABASE_URL` for a disposable database and creates/drops
its own random test schema. It covers migration up/down and simultaneous first
visits.


## Guard visits

The Guild interface's **Guild Base** button enables once the Guild owns a
base. `POST /game/guild-bases/teleport` selects the member's own Guild and
town on the server and authorizes free travel to the main-hall `FromTown`
spawn. All member ranks can use it. It uses the usual departure effect, input
lock and teleport acknowledgement; busy activities, pending teleports,
detention, closed areas and above-cap parties leaving Clash block travel.
Travelling home ends any temporary request or visit to another Guild.

The guard offers a searchable town-local Guild Base directory, direct entry to
one's own base and the existing purchase flow. Leaders select **Open to
visitors** or **By request** at the **Guild Base manager** in the main hall.
Existing bases default to **By request**. Any member inside the building can
approve or decline a visitor. A five-second poll updates the request counter,
in-game notifications and the open menus. Guests receive read-only furniture
layouts and share the host's world-presence roster.

The **Guild Base manager** stands behind the upper-left counter in the shared
main-hall template. Interacting saves the player's position and opens visitor
management for that instance's Guild. The Guild leader can switch between
**Open to visitors** and **By request**; other members can approve or decline
requests. Guests cannot manage the host's visitors. A compact **Visitors**
notification below the upper-right actions appears only while entry requests
are pending, providing a shortcut from elsewhere inside the base. The room
receptionist in the lift waiting hall continues to handle member-room searches.

A request lasts two minutes and repeated requests have a thirty-second cooldown.
Approval lasts two minutes for entry through the guard; entering establishes a
visit rather than permanent membership. Doors preserve the visited Guild ID.
The lobby exit returns to the town garden, and the garden building door returns
to the host base. Crossing the garden gate to the street saves the outside
position and ends the visit. Other world travel also ends it. A dormant visit
expires after 24 hours; stale access recovers the player outside the gate.
Guests can use the lobby and the two shared side rooms. The lift, player floors,
personal rooms, decorating rights and Guild inventory mutations require Guild
membership.

Backend migration `0327_guild_base_visits` adds the Guild access policy and one
request/visit row per player. Focused checks: `tests/guild_base_visits_check.gd`,
`tests.test_guild_base_visits`, and the disposable PostgreSQL
`tests.test_guild_base_visits_postgres.PostgresGuildVisitTests`.
