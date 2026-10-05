# Tackle, Scratch and Bite

The three contact effects are implemented in `contact_move_effect_3d.gd` and
selected by the normal 3D battle renderer. Visual approval is still pending.
Ember and Water Gun retain their approved source-textured recipes; Water Gun's
previous preview-only gate has been removed following the user's approval.

| Move | Source | 3D presentation |
| --- | --- | --- |
| Tackle | `ew0033_at_srash01`, `ew0033_df_hit` | Short body rush accent followed by the source impact atlas and expanding ring |
| Scratch | `ew0010_hit` | Three tapered curved claw trails, source flow/blur masks and a blue-white contact flash |
| Bite | `ew0044_tooth`, `ew0044_df_hit` | Two curved rows of volumetric teeth closing at impact, source arcs and an orange contact flash |

These are source-textured reconstructions. Native particle simulation, native
TR TML timelines and compiled shaders are not replayed. Bite's embedded G3PR
BFRES teeth are present in the dump but not converted by the bounded extractor;
its curved tooth geometry is authored in Godot. Texture provenance and hashes
are recorded in `assets/battles/moves_3d/sv_contact/provenance.json`.
Nine PNGs ship with the client; runtime has no local ROMFS/tool dependencies.

Pokémon retain their existing native physical actions and reviewed per-model
family selection. No new skeletal clips or speculative family mappings are
introduced: Charmander's second physical clip is a tail sweep, not a claw swipe.
All three moves now approach the selected target, reach contact just before the
impact marker, and return before the native clip ends. Horizontal displacement
uses both models' bounds, preserves grounding and keeps the original aim during
a dodge. Facing turns toward the selected opponent, including cross-slot attacks.
The HP panel stays at the actor's home position while effects and status visuals
follow its live pose. Pausing freezes the approach; effect cancellation, actor
replacement and stage shutdown restore placement immediately. Visible Substitutes
use the same approach. This is a procedural dash over the native attack pose,
not a newly imported run/walk cycle.

Tackle's short shock follows the approaching body. Scratch and Bite show contact
graphics at the target, rather than firing claws or teeth from the attacker.
Existing hand and mouth attachment profiles remain available to emitting moves.

All three share the existing native action clock, playback cap, audio plan,
impact/damage bridge and cancellation. Existing 2D move sounds play at contact.
Only event-confirmed hits create contact flashes. On a miss the trainer's
Dodge command precedes playback, and the target sidesteps while the graphics
keep aiming at its original position. Blocked/immune results do not create a
false hit. Camera-facing artwork resamples the camera even while paused; the
clock, geometry and target position stay frozen. Each effect uses at most
16 pooled mesh instances in the focused sweep, with no per-frame mesh/material
allocation.

## Reproduce and review

From the assigned frontend slot:

```sh
# Repeat for scratch/ew0010 and bite/ew0044, using new output folders.
python3 tools/battle_effects/extract_sv_ember.py --move tackle \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew/ew0033' \
  --output ../.tmp/contact-moves/tackle \
  --bntx-extractor ../.tmp/ember-sv-source/bntx_extract.py
python3 tools/battle_effects/package_sv_contact_textures.py \
  --source ../.tmp/contact-moves --output assets/battles/moves_3d/sv_contact
```

The existing external decoder and its revision are documented in
[the Ember source investigation](ember-sv-effect-pilot.md). Scratch adds an
explicit opt-in for inspected BC3 sRGB/RGBA, preserving all channels; unknown
formats/swizzles remain rejected. Ember's BC4 and Water Gun's BC5 paths are
unchanged. Source files are opened read-only.

From the workspace control root:

```sh
ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend \
  --script res://tests/contact_moves_preview.gd -- --moves
```

Select Tackle, Scratch or Bite, attacker species, direction, and hit/miss/block.
The preview uses the production renderer and existing 2D move sounds. Pause
and orbit are available. `--smoke-contact` checks Charmander/Arcanine versus
Pikachu, three moves, both directions, all outcomes, approach/return, fixed HUD,
pause/orbit and cancellation.
`POKEAETHER_STAGE_OUTPUT` optionally captures hit/miss screenshots.

Focused checks: `contact_move_effects_3d_check`, `battle_move_effects_3d_check`,
`battle_dodge_3d_check`, `battle_3d_impact_pacing_check`,
`move_attachments_3d_check`, and `source_move_effects_3d_check` with the historical
Ember extraction for exact recipe parity. The extractor test's `--contacts`
argument points to `romfs/effect/battle_ew` and verifies six containers/29
emitters, malformed inputs, opt-in BC3, and unchanged sources. The contact check
also covers approach in all four slots, pause, ground height, fixed dodge aim,
return, cancellation, Substitute and actor replacement.
