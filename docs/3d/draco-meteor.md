# Draco Meteor

Implemented in normal 3D battles; **visually approved by the user on 6 October 2026**. The user also approved
all 23 preceding moves, including their size/audio changes and Moonblast
charge/clearance revisions, on 6 October 2026.

## Presentation

A 3.2-second presentation at normal battle speed, independent of native clip
length. A gold charge gathers clear of the attacker's body for 0.7s, rises to
an elevated point above the field, splits, then sends seven fiery meteors down.
The central meteor reaches the target at 2.05s. Six staggered satellites add
breadth, with short shock bursts, expanding ground rings, debris and smoke.
The field and Pokémon remain visible; no full-screen overlay or camera cut.

All geometry/material motion samples the native model clock. Pause, speed,
camera orbit and cancellation use existing ownership. Charge follows its live
anchor until launch, then the origin and aim remain fixed. Misses retain their
aim and use the native dodge. Hit-only effects/audio require a confirmed hit;
blocked/missed moves do not depict target damage. The first central impact
owns the existing damage/recovery beat. Subsequent stat-drop events remain in
the battle event stream; this effect never changes HP or stats itself.

## Source assets

The local SV dump's `romfs/effect/battle_ew/ew0434` contains:

| Particle container | Emitters | Selected textures |
| --- | ---: | ---: |
| `ew0434_charge.ptcl` | 9 | 4 |
| `ew0434_meteo01.ptcl` | 13 | 2 |
| `ew0434_big_meteo01.ptcl` | 16 | 3 |

Nine packaged textures retain SHA-256 provenance in
`assets/battles/moves_3d/sv_dracometeor/provenance.json`. The charge masks are
quarter masks, mirrored around both axes when rendered. Fire/shock atlases
have eight/four horizontal frames; smoke uses its two-by-two atlas and source
alpha. Source flow masks provide the meteor's hot cracks and rock variation.

This is a source-textured reconstruction. Geometry, trajectories, size and
timing are authored for Godot. Native particle simulation, embedded meshes,
compiled materials and the original TR TML timeline are not converted.
The normal map (`0x1a06`) and signed BC5 distortion mask (`0x1e02`) are not
supported. The decoder receives only explicitly selected BC4/BC5 textures;
it does not reinterpret unsupported formats. Original BNTX bytes are retained
in the offline extraction; only its decode copy has a smaller pointer table.

Audio uses edits of the existing 2D Draco Meteor WAVs (1.376s charge/ascent, 0.65s
impact), with original catalog pitch, fades and native-clock boundaries.
These are not extracted SV sounds. Duplicate 2D impact cues are deduplicated.

## Reproduce / review

Use the assigned slot and the pinned external BNTX extractor described in
[source move effects](source-move-effects.md):

```sh
python3 tools/battle_effects/extract_sv_ember.py --move dracometeor \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew/ew0434' \
  --output .tmp/draco-meteor/extracted \
  --bntx-extractor /path/to/pinned/bntx_extract.py
python3 tools/battle_effects/package_sv_fire_bubbles.py \
  --source .tmp/draco-meteor/extracted --output assets/battles/moves_3d/sv_dracometeor
```

Run Godot through the assigned `slot-env` with
`--script res://tests/draco_meteor_preview.gd -- --moves`.
The preview selects Dragonite and Draco Meteor. Hit, dodge, blocked, direction,
model, arena, camera and pause controls remain available.
`--smoke-draco` captures charge/rise/split/rain/impact, both directions, all
three outcomes and a paused camera orbit. Set `POKEAETHER_STAGE_OUTPUT` inside
the slot for its screenshots.

Focused checks: `draco_meteor_3d_check.tscn` (three native clip lengths, bounded
geometry, outcomes, stable launch, impact/recovery), `battle_move_effects_3d_check.tscn`
(all 24 routes/four slots), `move_audio_edits_check.gd`, WAV audit and
`test_draco_meteor_sources.py` (38 emitters, unchanged source hashes,
unsupported-map rejection and reproducible packaging). Frame cost on lower-end
GPUs has not been benchmarked; the mesh pool is bounded below 90 pieces.
