# Flamethrower, Bubble and Bubble Beam

Implemented in normal 3D battles; all three are visually approved by the user.

| Move | Source artwork | Authored 3D presentation |
| --- | --- | --- |
| Flamethrower | SV `ew0053`, four containers / 32 emitters inspected | Sustained tapered fire stream, moving flame masks and a brief hit burst |
| Bubble | Reuses SV `ew0061` bubble artwork; no separate `ew0145` found in the local dump | Nine loose spherical bubbles, spreading and popping at confirmed contact |
| Bubble Beam | SV `ew0061`, six containers / 24 emitters inspected | Dense stream of 24 smaller bubbles per origin and one shared target splash |

These are source-textured reconstructions. Godot authors the geometry, motion,
palette and timing; native particle simulation and source timelines are not
converted. The bubble globes are sphere meshes with a source-textured highlight
and a view-dependent rim. Their world positions stay fixed when the paused
camera moves. Flame/impact artwork faces the camera. The bounded geometry
pool is at most 55 pieces, including two cannon origins and a single impact.

Charmander/shiny use the approved native breath clip for Flamethrower: launch
frame 40, impact 64, emission ends at 78 before head recovery. Other rigs use
their existing special-attack clip and generic native-clock timing. Mouth
profiles apply to all three moves; Blastoise's Bubble Beam uses both cannon
bones. Bubble still uses its mouth. Unknown models and visible Substitutes use
bounds-based origins. No contact approach is applied to these ranged moves.

Flamethrower and Bubble use their current 2D sounds once at launch. A separate
Bubble Beam animation/sample is absent from the current audio catalog, so its
3D route reuses Bubble's sound. This mapping is local to 3D and does not modify
the 2D catalog. Impact geometry requires hit evidence; misses aim at the
original target position while it dodges. Cancellation and damage/recovery
remain owned by the existing move router.

## Preview

From the workspace root, with slot-b assigned:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend \
  --script res://tests/fire_bubble_preview.gd -- --moves
```

Flamethrower/Charmander start selected. Select Bubble with Squirtle or Bubble
Beam with Blastoise to review the remaining examples. Existing outcome,
direction, pause, cancellation, arena and camera controls remain available.
`--smoke-fire-bubbles` exercises all three moves in both directions and all
three outcomes. `POKEAETHER_STAGE_OUTPUT` optionally captures screenshots.

## Offline assets

`extract_sv_ember.py --move flamethrower` reads `ew0053`;
`--move bubblebeam` reads `ew0061`. Use the external decoder and CLI described
in [the source move workflow](source-move-effects.md). Extraction requires a
new output directory and never changes the source dump. The exact inspected
R8 R/R/R/R and BC7 RGBA formats are opt-in only for Flamethrower and Bubble Beam
respectively; the external decoder already supports both. Existing BC3/BC5
opt-ins and guarded swizzles remain in place.

`package_sv_fire_bubbles.py --source EXTRACTED_MOVE --output DESTINATION`
packages four fire masks into `assets/battles/moves_3d/sv_flamethrower` or three
bubble masks into `assets/battles/moves_3d/sv_bubbles`. Each folder records PNG
and particle source hashes. Neither R8 nor BC7 is needed at runtime; only the
selected PNGs are shipped. No local dump/decoder dependency exists in-game.

## Focused checks

- `fire_bubble_3d_check.tscn`: three moves/outcomes, single/paired origins,
  geometry bounds, stable paused paths, no false impacts, shared audio,
  Charmander emission cutoff and damage bridge.
- `battle_move_effects_3d_check.tscn`: all ten routes/four slots, audio,
  Substitute, impact, replacement and cancellation.
- Rendered batch preview: mouths/cannons, native Charmander action, fixed dodge
  aim, orbit-facing sprites and cancellation for each move.
- `source_move_effects_3d_check.tscn` and `charmander_breath_check.gd`: existing
  Ember/Water Gun effects and normal/shiny breath animation regression checks.
- `test_fire_bubble_sources.py --source SV_BATTLE_EW --extracted EXTRACTED_ROOT`:
  source immutability, format/swizzle rejection and reproducible packaging.
  `test_extract_sv_ember.py --source EMBER_DIR` retains the existing decoder checks.
