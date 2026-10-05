# Ember: SV source-effect conversion pilot

## Result and boundary

The full local SV ROMFS contains the Ember source components in
`romfs/effect/battle_ew/ew0052`. Their VFXB version is 22. Extraction works:

| Component | Emitters including children | Referenced textures |
| --- | ---: | ---: |
| `ew0052_fire_muzzle.ptcl` | 3 | 4 |
| `ew0052_bullet.ptcl` | 4 | 6 |
| `ew0052_hit.ptcl` | 6 | 5 |

The 15 texture entries include duplicates between components. All use BC4
single-channel masks with R/R/R/R swizzles. The pilot preserves the masks as
single-channel PNGs and samples red in a Godot spatial shader. Flame textures
include horizontal animation atlases, rather than complete rendered move clips.

This is **partial asset conversion with a reconstructed preview**, not native
SV animation playback. The extractor recovers texture bindings, emitter names,
constant colors and color/alpha key tables. The preview uses a subset of the
flame textures and each selected emitter's first color value. It does not yet
replay those source color curves. It uses camera-facing quads in the 3D world.

Still not converted:

- Native emitter simulation: spawn rates, particle lifetimes, motion, scale,
  UV behavior, child-emitter triggering and exact blending.
- The embedded projectile mesh (`G3PR`, 12,880 bytes of payload) and native
  compiled shader sections (`GRSN`). In particular, the mesh-based
  `p_fireball` emitter is not recreated in this preview.
- `ew0052.trtml` timeline event semantics, frame timing, attachment rules and
  camera tracks. Audio event names are inventoried as strings only.

The preview authors travel, scale, emission and atlas playback explicitly in
`tests/ember_sv_effect_pilot.gd`. It follows the existing move/model clock,
anchors, hit/miss result and cancellation lifetime. It retains the existing
move sounds. Native SV audio has not been extracted or substituted.

Conclusion: reusing source artwork is feasible. One-click conversion of all
2,304 move particle files is **not established** by this pilot. Further work
should separate importing reusable textures from decoding native simulation
and timelines. No live battle renderer or move catalog was changed, and there
is no player-facing change for the changelog yet.

## Reproduce the extraction

Run development only in an assigned frontend slot. The source ROMFS is read-only;
output must be a new directory, preferably the assigned slot's `.tmp` directory.
The command intentionally refuses to overwrite an existing output directory.
Python 3 and Pillow are required.

Obtain an external checkout of
[BNTX-Extractor](https://github.com/aboood40091/BNTX-Extractor/tree/2c08e8e55fcc666ba6568a102f36dabd6c584e25)
at commit `2c08e8e55fcc666ba6568a102f36dabd6c584e25`. The CLI requires
`bntx_extract.py`, `dds.py`, and `swizzle.py` from that checkout. It is GPL-3.0
software used as an external offline tool, not vendored into the game runtime.
The importer does not download or install dependencies.

From the assigned frontend worktree:

```bash
python3 tools/battle_effects/extract_sv_ember.py \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew/ew0052' \
  --output ../.tmp/ember-sv-pilot \
  --bntx-extractor ../.tmp/ember-sv-source/bntx_extract.py

python3 tools/battle_effects/test_extract_sv_ember.py \
  --source '/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew/ew0052'
```

The original external extractor misreads BRTI byte 16 as tile mode (`9` in these
files), and therefore fails with `KeyError: 9`. The pilot creates a separate
compatibility input: flags/dimension/tile-mode fields are translated to the old
extractor's layout and enum. Original embedded BNTX files are retained unchanged
as `source.bntx`. Dimensions, format, data pointers and texture data are untouched.
Only inspected 2D BC4/RRRR textures and VFXB v22 are accepted. Other formats fail
explicitly instead of producing an apparently valid conversion.

The output contains per-component BNTX, DDS, PNG, decoder logs and a manifest
with source/decoder hashes, emitter metadata and explicit incomplete-conversion
flags. These extracted assets remain local; no ROMFS files or source-derived
textures are committed by this pilot.

## Open and compare

From the workspace control root, for the current slot-b assignment:

```bash
ops/worktrees/slot-env slot-b -- godot \
  --path .worktrees/slot-b/frontend \
  --script res://tests/ember_sv_preview.gd -- \
  --moves \
  --sv-source=/home/adinho/Desktop/pokemonaetheronline/game/.worktrees/slot-b/.tmp/ember-sv-pilot
```

Ember is selected automatically. Use **Afspelen** and the **SV-bronmateriaal**
switch to compare the next playback with the previous procedural Ember. The
switch takes effect on the next attack. Models, direction, outcome and arena
controls are inherited from the existing offline move preview. The ordinary
battle path never loads this pilot, and it never starts a server battle.

Add `--smoke-sv-ember` for the focused visual check: both directions, hit/miss/
blocked, paused clock, camera orbit while paused, cancellation and cleanup.
Set `POKEAETHER_STAGE_OUTPUT` to an existing local directory to save flight,
impact and orbit screenshots. A 60-second watchdog fails stalled checks.

## Validation performed

- Actual-source extraction of all three files: 13 emitters, 15 referenced
  texture entries; all decoded textures inspected in a contact sheet.
- Parser checks: expected named emitter-to-texture bindings, unchanged source
  bytes, truncated inputs, wrong version, invalid section links and unsupported
  tile mode (18 rejected invalid inputs).
- Rendered Godot battle preview with Dragonite and Pikachu: both directions,
  three outcomes, shared-clock pause, orbit-facing sprites, cancellation,
  no remaining pilot nodes/audio after cleanup. Flight and impact screenshots
  inspected. Existing scene resource UID fallback warnings remain unrelated.

## Format references

- [Switch-Toolbox PCTL.cs](https://github.com/KillzXGaming/Switch-Toolbox/blob/9fe41401d246d31c99fcbfdd0a7fe4253a95b31f/File_Format_Library/FileFormats/Effects/PCTL.cs):
  VFXB sections, v22 emitter color/sampler offsets and GTNT texture descriptors.
- [BntxLibrary structs](https://github.com/KillzXGaming/BntxLibrary/blob/e5c8d20cb5aed9262b16d7be9e0e48e0f9c43987/BntxLibrary/BntxFile.cs)
  and [enums](https://github.com/KillzXGaming/BntxLibrary/blob/e5c8d20cb5aed9262b16d7be9e0e48e0f9c43987/BntxLibrary/Enums.cs):
  current BRTI flags/dimension/tile fields and Optimal/Linear enum.
- [BNTX-Extractor v0.6](https://github.com/aboood40091/BNTX-Extractor/tree/2c08e8e55fcc666ba6568a102f36dabd6c584e25):
  offline Tegra deswizzling and DDS output.
