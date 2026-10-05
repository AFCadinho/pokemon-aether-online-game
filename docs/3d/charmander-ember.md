# Charmander's Ember movement

Ember now selects `special_attack_2` for the exact normal/shiny Charmander
revisions recorded in `resources/battle/model_animations/charmander_breath.json`.
Other moves retain their existing selection. Unknown revisions retain the
ordinary special-attack fallback.

The previous `00450_rangeattack01` bends deeply forward in the source Blender
review as well as Godot. The alternate native `rangeattack02` sequence faces
forward with an open mouth. This is a model-specific clip choice; the approved
animated mouth attachment remains unchanged.

## Source and timing

Source resource: SCVI `pm0004_00_00`, with these original 60 Hz clips:

| Component | Source suffix | Native frames |
| --- | --- | --- |
| Preparation | `00460_rangeattack02_start` | 40 |
| One emission cycle | `00461_rangeattack02_loop` | 38 |
| Recovery | `00462_rangeattack02_end` | 60 |

The combined non-looping clip has 138 frames. Four-frame boundary blends retain
the same clock. Ember and its existing sound start at frame 40; impact is frame
64. Playback uses the existing 1.25-second maximum attack presentation. The
resource contains only bone position/rotation/scale tracks, all 68 bones have
complete channels, and each actor gets its own library. Materials, mesh, other
clips and downloaded bundle hashes are retained.

The client-shipped addition follows the existing Gliscor/Mega Garchomp animation
mechanism. It requires no separate model-bundle publication. Both original
runtime hashes are pinned; a future model revision must be checked again.
The measured clearance curve is merged into the existing placement profile.
The stable existing HUD envelope is retained across the attack.

## Rebuild and checks

1. `export_charmander_breath.py` runs in isolated Blender with read-only source,
   importer/dependencies and native motion files. Its CLI takes source Blend,
   importer, Python dependencies, motion directory and a new output GLB. It
   verifies the prepared-source and three native-motion hashes before export.
2. `build_charmander_breath_library.gd` takes the pinned carrier GLB, approved
   normal runtime scene and output `.res`. It checks bone names, parents, rest
   transforms and animation paths before composing the three parts.
3. `measure_charmander_breath.gd` takes the approved normal runtime and output
   JSON. It samples skinned geometry at 120 Hz and generates clearance at 60 Hz
   for the existing approved scale/lift. Store bounds/motion in the JSON above.

Run Godot using the assigned slot environment. Focused checks:

- `charmander_breath_check.gd`: normal/shiny routing, revision guard, independent
  actor libraries, complete clips, boundaries, fallback and audio/launch timing.
- `charmander_ember_preview.gd -- --moves --check-breath`: actual normal/shiny
  models, hit/miss, upright mouth, pause/orbit and recovery.
- Existing move effects, source effects, attachment and impact-pacing checks.

Interactive review: `--script res://tests/charmander_ember_preview.gd -- --moves`.
Normal Charmander is on the left and shiny on the right; use the right-attacker
checkbox to inspect both. Optional `POKEAETHER_STAGE_OUTPUT` saves smoke images.
