# Extended native 3D move presentations

The local gameplay summary has 919 records and **901 unique normalized names**.
The original 24 dedicated effects and 170 recipes cover 194 names. The extension
adds explicit profiles for the other **707**, including status, weather, legacy,
and Max moves. Coverage describes the checked-in gameplay catalogue; it does not
add moves to learnsets or enable unsupported battle mechanics.

The original 194 retain their renderer/data ownership and approval record. All
707 additions are marked `implemented-pending-player-review`. Technical coverage
and smoke captures do not constitute individual player approval or certification.
See [the complete per-move inventory](extended-move-coverage.csv).

## Construction and integration

- `data/battle_move_extensions_3d.json`: explicit names, 45 authored construction
  motifs, timing, attachment, count, size, colour, audio and optional camera/light
  settings. There is no runtime name/type fallback for unknown future moves.
- `extended_move_effect_3d.gd`: solid fists, feet, teeth, horns, hammers, crescents,
  projectiles, tapered beams, wave crests, cages, healing symbols, shields, rooms,
  weather and field attacks. Related moves share construction routines. They are
  individually tunable profiles, not 707 independently bespoke renderers.
- Signature details include Fire Blast's five-ended glyph, returning Bonemerang,
  three coloured Tri Attack orbs, distinct Max attack silhouettes, small-source
  Hydro Pump/Cannon, aerial contact arcs and two calibrated Blastoise cannons.
- Eleven new profiles use existing charge/target camera fitting: Aura Sphere,
  Blood Moon, Energy Ball, Eternabeam, Fire Blast, Hydro Cannon, Hydro Pump,
  Meteor Beam, Prismatic Laser, Roar of Time and Spacial Rend. Camera settings
  remain respected. Other moves retain the overview.
- Temporary lights sample the same native clock, including projectile arcs and
  beam cutoff. The extension caps each sample at three shadowless lights.
  Arena/weather resources are never mutated, and cleanup restores overrides.
- 18 physical/special duplicate Z names account for the summary's additional
  records. Explicit ID aliases also route their gameplay IDs to the original
  approved Z presentations.
- Animation, audio and light timing use the actor's clock. Impact art and impact
  sound require a confirmed hit. Misses retain the original aim. Status/healing
  visuals do not alter HP, conditions, weather or other gameplay state.

## Source and sound provenance

The supplied Pokémon model dump remains the model/pose source. The separate
`SV Every File/romfs/effect/battle_ew` dump contains particle files for **485** of
these added names; 222 have no particle files in the indexed numbered directory.
Each profile records the directory and particle filenames as a reference inventory.
This extension's geometry and shader motion are authored in Godot: it does not
convert SV textures, particle simulation, timelines or audio, and the file list
is not a claim of a frame-for-frame reproduction of each source move.

`Audio/SE/Anim` supplied **968 short Ogg cues**: 503 moves matched sounds under
their own normalized name, while 204 explicitly reuse a related motif sound.
`assets/battles/moves_3d/audio_extensions/manifest.json` records the source file,
SHA-256, exact/shared selection, trim/fade/limiter filter, duration and output hash.
The sounds are bounded edits of that library, not original SV soundbank extraction.
They never boost loudness automatically. Anatomical release/impact timing overrides
recipe defaults when forming the runtime cue plan. No dump paths are runtime
requirements; new assets occupy approximately 12 MiB including import sidecars.

## Rebuilding

In the assigned frontend slot, create a small metadata snapshot from the paired
backend's installed `pokemon-showdown/dist/data/moves.js` `Moves` export. Retain
`num`, `name`, `target`, `flags`, `category`, `multihit`, and `type`, keyed by move ID.
Then run:

```sh
python3 tools/battle_effects/build_extended_move_catalog.py \
  --metadata .runtime/test-logs/move-metadata.json \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew'
python3 tools/battle_audio/build_extension_audio.py \
  --source /home/adinho/Documents/move_animation/Audio/SE/Anim
```

The catalogue builder intentionally clears cues; run the audio builder afterward.
Use `--output` on the catalogue builder to audit regenerated profiles separately.
Neither builder downloads files or writes to the source dumps. A new gameplay
name without an explicit motif assignment causes generation to fail.

## Focused verification and review

Through `ops/worktrees/slot-env SLOT --`:

- `tests/extended_move_3d_check.tscn`: all 707 additions, four slots, both
  directions, three outcomes, 84,840 geometry/light samples, clock pause,
  actor/field targeting, router/audio lifecycle and native timing. Additional
  camera/light checks cover singles/doubles, weather, hybrid mode, cancellation,
  paired emitters and anatomy-specific audio markers.
- Existing `move_recipe_3d`, `move_camera_choreography`, `move_lighting_profiles`
  and `solid_move_forms` check scenes protect the previously implemented effects.
- `python3 tools/battle_effects/test_extended_move_catalog.py`: coverage for all
  919 IDs, ownership, audio provenance hashes and ffprobe duration bounds.

The offline preview picker includes all 901 moves. For repeatable GPU captures:

```sh
ops/worktrees/slot-env SLOT -- env DISPLAY=:0 \
  POKEAETHER_STAGE_OUTPUT=/absolute/path/to/slot/.runtime/test-logs/extension-review \
  godot --path .worktrees/SLOT/frontend \
  --log-file /absolute/path/to/slot/.runtime/test-logs/extension-review.log \
  --script res://tests/extended_move_preview.gd -- \
  --moves --capture-extensions --representatives
```

`--representatives` captures 58 moves spanning all 45 motifs in both directions,
at charge, travel and impact. Omitting it captures all 707 additions at a travel
sample. `--caster=Blastoise` changes the source model. These are offline captures;
no backend, account session or production access is needed.

Remaining review scope: individually judging all 707 presentations against the
player's aesthetic expectations, every species/arena combination, device
performance and original-source visual fidelity. Cast effects for transformation,
copying, delayed, charging and persistent-state moves leave those outcomes to
the existing event presentation; they do not implement new battle mechanics.
