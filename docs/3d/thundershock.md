# Thunder Shock

Implemented and available in normal 3D battles; visually approved by the user.
Ember, Water Gun, Tackle, Scratch and Bite are also approved.

`electric_move_effect_3d.gd` uses the inspected SV `ew0084_thunder` and
`ew0084_thunder_hit` textures: the electrical pulse mask, eight-frame spark
atlas and central flash. The two containers contain ten emitters. Three
single-channel PNG masks ship in `assets/battles/moves_3d/sv_electric` with
source and packaged hashes in `provenance.json`.

The bolt paths, travel and spatial impact arrangement are authored in Godot;
this is a source-textured reconstruction, not native SV emitter/timeline
playback. The move uses the existing Pokémon special-attack clip and existing
2D Thunder Shock sound. Pikachu and shiny Pikachu use the previously inspected
120-frame discharge pose: launch frame 20, impact frame 48. The frame count
and non-looping clip guards preserve generic timing for different model clips.

Pikachu's discharge origin follows `spine_02` (the moving upper body). This
avoids emitting from below Pikachu when its special attack jumps. The
`electric_body` attachment is used by Thunder Shock and Thunderbolt, so its approved Tackle
and other moves retain their existing origins. Other species and visible
Substitutes use the established body/bounds fallback. There is no contact
approach for this ranged electric move.

A compact body charge and two jagged world-space branches travel toward the
target. The impact uses short arcs and a small flash only on event-confirmed
hits. Misses aim at the original position while the target dodges. Blocked or
immune outcomes do not show a hit. Every visual and audio cue uses the native
move clock. Bolt noise is deterministic per clock tick; pause freezes the
paths while textured artwork continues to face an orbiting camera. The
geometry pool remains bounded at 46 pieces in the focused sweep. All temporary
geometry is owned by the normal move lifetime and cancellation guards.

## Offline review

From the workspace root with slot-b assigned:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend \
  --script res://tests/thundershock_preview.gd -- --moves
```

Thunder Shock starts selected with Pikachu against Charmander. Existing
species, outcome, direction, pause and camera controls remain available.
`--smoke-electric` exercises Pikachu/Dragonite against Charmander in both
directions, hit/miss/block, flight and impact, pause/orbit and cancellation.
`POKEAETHER_STAGE_OUTPUT` optionally captures screenshots.

## Extraction

From the assigned frontend worktree, using the external decoder documented in
[the Ember investigation](ember-sv-effect-pilot.md):

```sh
python3 tools/battle_effects/extract_sv_ember.py --move thundershock \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew/ew0084' \
  --output ../.tmp/thundershock-source/extracted \
  --bntx-extractor ../.tmp/ember-sv-source/bntx_extract.py
python3 tools/battle_effects/package_sv_thundershock.py \
  --source ../.tmp/thundershock-source/extracted \
  --output assets/battles/moves_3d/sv_electric
```

Extraction requires a new output folder and reads sources without modification.
The containers include BC3 RGBA textures; their decoder support is explicitly
opted into, as for Scratch. Only the selected BC4 masks are packaged. There is
no ROMFS or offline tool dependency in the runtime.

## Focused checks

- `thundershock_3d_check.tscn`: three outcomes, bounded geometry, no premature
  visuals or false impacts, pause/orbit invariance, guarded normal/shiny timing,
  audio launch, damage bridge and absence of contact approach.
- `move_attachments_3d_check.tscn`: moving upper-body origin and unchanged
  Tackle fallback, alongside existing mouth/cannon and Substitute checks.
- `battle_move_effects_3d_check.tscn`: all six routes/four slots, audio,
  lifecycle, Substitute, impact and cancellation.
- `battle_dodge_3d_check.tscn`: existing Dodge command/clock ordering and fixed aim.
- `source_move_effects_3d_check.tscn` with the earlier Ember extraction: exact
  approved Ember visual parity and unchanged source Water Gun.
- `test_extract_sv_ember.py --source EMBER_DIR --electric EW0084_DIR`: two
  electric containers/ten emitters, explicit BC3, malformed input rejection,
  source immutability and the existing Ember checks.
