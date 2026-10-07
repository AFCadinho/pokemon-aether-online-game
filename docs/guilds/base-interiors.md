# Guild Base interiors

The first playable base is Vermilion City. Its fixed main hall, two initially
empty side rooms and lift waiting room are separate reusable scenes under
`scenes/overworld/kanto/guild_base/`. The garden remains on the city map.

The ordinary MapExit / WorldTransitionService / authorized teleport flow owns
all doors. The account service resolves each template into a private map ID:
`guild_base:<townId>:<guildId>:<roomKey>`. Room keys are `main_hall`, `left_room`,
`right_room`, and `elevator`. A room scene is shared by every Guild; no per-Guild
scene files or extra purchase rows are required. Base ownership stays on Guild.

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
existing object depth sorter. Runtime collision is an explicit floor mask, with
blocked footprints for fixed lobby and lift furnishings.

`Entities/Furniture` is the insertion point for later Guild-owned furniture.
Future placement storage should use `(guild_id, room_key)` with stable room-local
tile coordinates, server-validated footprints, edit permissions and revisions.
The current feature does not include furniture placement or personal rooms.
The lift waiting room is reachable; its upper lift door stays closed until a
personal-room selector and server-authorized player room instances are added.

For Celadon/Saffron, add their actual city entrance/return points and registrars
before enabling purchases. Reuse the room scenes; extend the server door/return
contract and town access rather than duplicating maps per Guild or town.

Focused checks: `tests/guild_base_interior_check.gd`, account-service
`tests.test_guild_base_interiors`, and gateway `tests.test_guild_base_presence`.
