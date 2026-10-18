# Rocket Hideout

Four gameplay scenes in `scenes/overworld/kanto/towns/celadon_city/` use the
artist's `Rocket Hideout B1F.tmx` through `Rocket Hideout B4F.tmx`. The matching
visuals live in `generated/tiled_visuals/rocket_hideout_b{1,2,3,4}f/` and remain
separate from editable collision and transitions. All floors use indoor lighting,
no weather, and the `kanto_rocket_hideout` access group. They are included in the
extended browser module, both world-access catalogs and Celadon City's map entry.

The Game Corner's two stair tiles at (24–25,5) enter B1F at (16,6), facing right.
B1F returns to (23,5) in the Game Corner, facing left. The city's existing Game
Corner doorway stays connected.

## Stairs and separated wings

The current stair art has moved since the Tiled connection metadata was written.
Gameplay triggers use the visible current treads/openings; reciprocal arrivals
sit beside them and outside every trigger footprint.

| Map | Stair trigger tiles | Return landing |
| --- | --- | --- |
| B1F → Game Corner | (13–14,6) | (16,6), right |
| B1F → B2F north | (23–24,5) | (22,5), left |
| B1F → B2F south | (20–21,38) | (19,38), left |
| B2F → B1F north | (32–33,7) | (31,7), left |
| B2F → B1F south | (27–28,19) | (26,19), left |
| B2F → B3F | (24–25,6) | (23,6), left |
| B3F → B2F | (21–22,6) | (20,6), left |
| B3F → B4F | (15–16,23) | (14,23), left |
| B4F → B3F | (17–18,23) | (16,23), left |

B1F's southern workroom remains separate from its upper offices and is reached
through B2F's southern staircase. B4F's western offices are reached by stairs;
its eastern offices and southern workspace are reached by lift. Collision keeps
both separations intact. Furniture, low maze partitions and statue bases are
solid. The overhead wings of the gold statues on B4F remain passable underneath,
preserving the corridor to the executive room.

## Shared elevator cabin

`rocket_hideout_elevator.tscn` imports the user-supplied **Rocket Hideout
Elevator.tmx** once. B1F, B2F and B4F use physical `ToElevator` doors rather than
separate floor menus. The cabin has 16 walkable tiles, a control panel at (3,4),
a `FromFloor` arrival at (5,6), a `FromPanel` ride arrival at (3,5), and a south
exit at (5,8). Collision and the exterior mask remain editable Godot nodes.

| Floor | Three-wide entrance centre | `FromLift` return, facing down |
| --- | --- | --- |
| B1F | (30,33) | (30,34) |
| B2F | (31,22) | (31,23) |
| B4F | (27,33) | (27,34) |

The panel offers B1F/B2F/B4F in all four locales and marks the current floor.
Canceling keeps the current context, so walking straight out returns to the
entry floor. Selecting another floor closes the doors, plays a short ride,
executes the normal authorized MapExit flow and updates the same cabin instance.
The current floor's door is the only enabled exit. Destinations are checked by
the server before accepting travel. All arrivals avoid automatic reentry.

The server persists `kanto_rocket_hideout_elevator:<user-id>:<floor>` as the
player's map ID, using the one shared scene for every floor. World applies this
context on both live travel and login. Normal teleport acknowledgement recovers
a disconnect during a ride. Position autosave cannot create a cabin, change its
floor, leave it, or enter another user's instance. Private presence authorization
isolates users and checks context changes. Staff teleport templates exclude the
cabin; staff following a player into a private cabin is rejected.

Floor entrance edits open only the two formerly blocked side cells in each
existing three-wide doorway; all other authored collision and spin markers stay
unchanged. The generated catalogs replace six direct floor-to-floor warps with
three entries, three cabin rides and three exits. For server details see the
backend `docs/rocket_hideout_elevator.md`.

## Visuals and verification

The visual importer does not currently apply Tiled `tintcolor`. These gameplay
scenes explicitly preserve Ground `#d1edc0` and GroundDetail `#daeaff` through
child-property overrides; preserve those overrides when reimporting the visuals.
Objects retain their original colours.

The elevator follow-up passes **103 account tests**, **58 Gateway presence tests**
and the focused Godot `rocket_hideout_lift_check.gd`. It exercises the actual
Player collision/appearance, cabin geometry, panel menu, current-floor exits,
real MapExit handoff, World instance configuration, success/failure/cancel paths,
input ownership, cleanup, all four locales and browser-module registration.
Godot-rendered cabin and menu previews were inspected against the source TMX.

The general `rocket_hideout_check.gd` still reports **1,419 identical static map
findings** with both the updated and unchanged original floor collision data.
These cover prior tint, geometry and arrival assumptions; the focused cabin
checks pass. The broader moderator/Guild teleport run has the same two failures
and ten errors on unchanged source/catalogs as on this branch. Catalog generation
also sees prior Celadon City/Prize Corner drift (two areas and two transitions);
those unrelated baseline entries were preserved. Full certification and a live
networked walkthrough were not performed.

## Exterior masks

B1F through B4F each use the shared black `FloorVisibilityMask`, drawn at
absolute z-index 4096. Each mask surrounds the full imported visual canvas:
B1F 1184 × 1408, B2F 1184 × 960, B3F 864 × 1120 and B4F 1056 × 1248 pixels.
The fixed floor region does not follow the player or constrain the camera.
Collision, room visibility within each canvas, stairs and lift behavior are
independent of the exterior masks.

All four scenes were rendered in Godot against a contrasting background and
visually reviewed; every outer margin renders fully black. The existing
`tests/floor_visibility_mask_camera_check.gd` passes. No live walkthrough was
performed for this visual-only change.

## Trainers, Pokémon and pickups

The four floors now contain 11 Rocket grunts (5/1/2/3), Giovanni on B4F,
eight talkable companion Pokémon and 18 one-time pickup balls. Placement uses
native TrainerNPC/OverworldPokemon/OverworldItem scenes, with collision and
Showdown portraits. The current artist geometry and painted spin layers are
unchanged. The extra Pokémon are stationary so they cannot wander onto the
conveyors or reserve a puzzle destination.

The western B4F grunt reveals the Lift Key after defeat. The server requires
this key for rides; exiting the current floor remains possible without it.
Old unkeyed B2F/B4F saves can also evacuate to B1F.
Both eastern guards must be beaten before Giovanni. His quest marker takes
precedence over the ordinary battle icon. The trusted boss victory leads to
an automatic/resumable conversation, a Silph Scope pickup and the objective to
return to Pokémon Tower. Story Trainer Progress includes each new stage.

The official reference and explicit adaptations are documented in the paired
backend's `docs/rocket_hideout_population.md`: current Aether levels/moves,
eight extra companions, original hidden items shown as balls, and TM Thief in
place of unsupported TM Snatch. No further Tower rescue chapter is introduced.

Run `tests/rocket_hideout_population_check.gd` for native actor, availability
and spin-aware reachability checks; `-- --render` additionally saves complete
Godot floor previews under `.tmp/` using the graphical rendering backend.

## Dropped keys and Giovanni's gate

The Lift Key and Silph Scope nodes start hidden in the B4F scene, including in
the editor. A live victory over the northwest grunt queues a visible drop from
his feet to the authored item position, after his accidental-drop reaction.
Solo and Adventure Party outro locks both delay this animation. The item remains
a normal one-time pickup: the animation never grants inventory. A reconnect
restores an earned, uncollected ground item without repeating the fall.

Giovanni's post-battle host drops the Scope before he notices it in dialogue.
He dismisses the lost machine as replaceable, then fades away and leaves it for
the player. Until the story acknowledges the conversation the Scope is only a
visual preview. A failed acknowledgement or
interrupted sequence restores Giovanni and hides that preview for retry. Scene
unload cancels tweens and releases only the drop's named input lock.

The pre-battle exchange alternates Giovanni's business rationale and the player's
objections. Giovanni boasts about selling valuable Cubone skulls and the Cubone
on Pokémon Tower's upper floors before issuing his challenge. After defeat he
confirms Mr. Fuji's captivity and the Scope's ability to identify ghosts. All
four locales share the same sequence. Existing quest step IDs and pickup
authorization are retained; the post-battle objective now asks the player to
speak to the defeated Giovanni instead of discovering an already revealed plan.

`GiovanniGate` spans tiles (24–25,18), across the entire corridor behind the two
guards. It checks both guards' trusted progress and opens after the second
victory/outro; one guard in either order cannot open it. Unknown progress keeps
it closed. Earned boss completion preserves access for older saves. No artist
visual, static collision, spin layer or NPC/item position was changed. Generated
Adventure Party anchors/catalogs now reflect the user's latest trainer placement.

`tests/rocket_hideout_drops_gate_check.gd` exercises the native Player's movement
through both portal cells, reachability to the boss, guard order, missing progress,
dialogue/drop/departure ordering, retry, reconnect, co-op reload and input cleanup.
Its optional `-- --render` previews cover the closed/open gate and dropped items.
The general population check still reports the same five placement findings as
an unchanged HEAD-scene geometry run (Escape Rope, Taunt, Super Potion, Max Ether,
Calcium). These predate this follow-up and were not changed with the user's maps.

## B1F lift shortcut gate

`Entities/Interactables/LiftShortcutGate` spans tiles (26–27,24), closing the
two-tile corridor between the eastern office and the lift. The entrance and the
southern workroom cannot bypass it. The first elevator approach therefore goes
through B2F's spinner maze after obtaining the Lift Key.

The shared security-gate script now accepts required trainer IDs, an optional
completed-story fallback, and a closed-dialogue localization key. B1F requires
only `kanto_rocket_hideout_b1f_grunt_3`, the grunt already placed beside the lift;
no NPCs, pickups, static collision, artist maps or generated trainer anchors were
moved. B4F retains both guards and its existing compatibility fallback. The Lift
Key and Giovanni's story progress cannot unlock B1F. Trusted first victory opens
the shortcut permanently, after the defeat dialogue; Adventure Party map reloads
wait for their pending battle outro too.

This follows the barrier behavior in the reconstructed FireRed/LeafGreen
[B1F scripts](https://github.com/pret/pokefirered/blob/master/data/maps/RocketHideout_B1F/scripts.inc).
The source calls its lift-side guard Grunt5; our current authored placement puts
Grunt3 in that role, so the gate uses that actor's existing ID and position.

`tests/rocket_hideout_b1f_gate_check.gd` checks native Player movement across both
gate cells, routes from all B1F arrivals, the guard's accessible side, unrelated
victories/story completion, unavailable progress, dialogue ordering, reconnect
and Adventure Party reload. It also checks the B2F route using production spin
logic, removing a ground pickup only after its adjacent collection position is
reachable. `-- --render` captures the actual closed/open B1F scene and B2F.
The B4F drop/gate test covers the shared-script regression. These use trusted API
probes; a live two-client multiplayer walkthrough is not part of these checks.

## Lift hint and panel follow-up

The floor door hints sit one tile south of the lift entry, on the free approach
floor. `transition_hint.gd` intentionally sets its absolute drawing layer to 7 at
runtime; a scene-only `z_index = 4096` override did not survive `_ready`, so the
old hints were covered by the lift artwork on `ObjectsTop` (2051). The shared
hint drawing policy remains unchanged. Cabin exits now have matching downward
hints; only the server-selected floor's hint is visible, and departure hides it
until doors reopen, including rejected rides.

The cabin's missing `destination_floors` property is restored to B1F/B2F/B4F.
The panel script uses the same defaults, so an editor property reset no longer
leaves an empty floor list beside three correctly configured destination exits.
The trusted current floor and authorized ride/exit paths remain mandatory.

All user-authored collision layers, collision-shape offsets, trigger positions
and door-entry timing are preserved. The focused lift check verifies native panel
input, all floor choices, authorization success/failure, hint state and movement
through the authored cabin. Its footprint assertions cover playable floor and
the immediate wall perimeter, rather than unreachable empty cells outside it.
Graphical Godot captures also compare shown/hidden hints on B1F/B2F/B4F and in
the cabin: all four visibly affect the rendered image on clear approach floor.

## Soundtrack

All four basement floors and the elevator cabin use music profile
`kanto.rocket_hideout`, resolving to
`overworld.kanto.interior.rocket_hideout_remastered_zame` in the music catalog.
The shared path lets MusicManager continue the playing track across floor and
cabin changes; its existing end-of-track handler repeats the soundtrack.

Asset: `assets/music/overworld/kanto/interiors/rocket_hideout_remastered_zame.ogg`.
User-supplied source: `Team Rocket Hideout Remastered ► Pokémon Fire Red & Leaf Green - Zame (128k).mp3`.
Converted with FFmpeg/libvorbis, quality 5, 48 kHz stereo, preserving the full
161.045354-second duration. Title and artist (Zame) are retained as OGG tags.

- Source SHA-256: `4fa1de02d0a964b12f664e0ea41d35624ba39a52dc98105dad32a0f9008326bf`
- OGG SHA-256: `1fa6cc4d539354059237ad1d85281776519953589c51db99dfbecf5d12656d70`

The new OGG is tracked with this feature, like the existing Rival soundtrack,
so local checkouts receive the asset alongside its catalog registration.
Release exports use the separately managed music pack; include this track in
the next music-pack build/publication. This task does not publish an asset pack.
`tests/map_music_profile_check.gd` verifies decoding and runtime track selection
on B1F–B4F and the cabin.
