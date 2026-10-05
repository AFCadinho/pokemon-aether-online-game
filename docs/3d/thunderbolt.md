# Thunderbolt

Available in normal 3D battles, awaiting user visual approval.

The SV `ew0085` source contains five particle containers with 51 emitters:
start, beam, initial hit, sustained hit and ending hit. The offline extractor
inspects all five with explicit BC3/BC5 opt-ins using the existing decoders.
Four BC4 masks are packaged with source/PNG hashes in
`assets/battles/moves_3d/sv_thunderbolt/provenance.json`.

The runtime uses Thunderbolt's own 16-frame lightning strip, eight-frame body
arcs, flash and eight-frame burst. Three intersecting ribbons carry the bolt
through 3D space; body/impact sprites face the camera. Ribbon geometry and
atlas phase stay fixed while paused, including during camera orbit. The pool
is bounded at 11 pieces. This is an authored reconstruction using source
artwork; native SV emitter simulation and timeline are not converted.

Pikachu/shiny use the existing special-attack pose with launch frame 20 and
impact frame 48 of 120. The origin follows `spine_02`, as for Thunder Shock.
Other species retain the body/bounds fallback, and a visible Substitute owns
its origin. The move is ranged and does not approach the opponent.

The two existing 2D sounds retain separate beats: `Thunderbolt2` at launch,
`Thunderbolt1` at impact. Other species use the same split with their native
clip's generic launch/impact timing. Source audio plans remain unmodified.
Only confirmed hits receive a burst/corona; misses keep the original aim while
the opponent dodges. The shared event bridge handles damage and recovery.

## Reproduce

From the workspace root with slot-b assigned:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend \
  --script res://tests/thunderbolt_preview.gd -- --moves
```

Thunderbolt starts selected with Pikachu against Charmander. The preview has
species, direction, hit/dodge/block, pause and camera controls.
`--smoke-electric` exercises Pikachu and Dragonite against Charmander in both
directions. `POKEAETHER_STAGE_OUTPUT` optionally captures flight/impact PNGs.

From the assigned frontend worktree, using the existing external decoder:

```sh
python3 tools/battle_effects/extract_sv_ember.py --move thunderbolt \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew/ew0085' \
  --output ../.tmp/thunderbolt-source/extracted \
  --bntx-extractor ../.tmp/ember-sv-source/bntx_extract.py
python3 tools/battle_effects/package_sv_thundershock.py \
  --source ../.tmp/thunderbolt-source/extracted \
  --output assets/battles/moves_3d/sv_thunderbolt
```

Extraction requires a new output directory and never modifies sources. The
packager selects the electric move from its inspected manifest. Runtime does
not need ROMFS files or the external decoder.

## Focused validation

- `thunderbolt_3d_check.tscn`: hit/miss/block, geometry bound, pause/orbit,
  separate sound beats, normal/shiny attachment selection and damage bridge.
- `battle_move_effects_3d_check.tscn`: seven moves/four slots, live routing,
  audio, lifecycle, Substitute and cancellation.
- Rendered electric preview: three species, both directions, outcomes,
  paused billboards, fixed dodge aim and clean cancellation.
- `battle_3d_impact_pacing_check.tscn`: ordered damage/recovery and Ground/Electric
  Gem activation before attacks, with Thunderbolt audio enabled when VFX exist.
- `thundershock_3d_check.tscn`: existing electric move regression check.
- `test_extract_sv_ember.py --source EMBER_DIR --thunderbolt EW0085_DIR`:
  five containers/51 emitters, explicit formats, malformed input rejection
  and unchanged sources, alongside existing Ember checks.
