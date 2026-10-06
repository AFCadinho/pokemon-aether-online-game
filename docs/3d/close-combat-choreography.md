# Close Combat — 2D-inspired 3D combo

Close Combat now follows the existing 37-frame 2D storyboard over 2.6 seconds.
The recipe records its source path/hash and fourteen original strike accents,
including their frame, pattern and offsets. The 2D files remain unchanged.

The attacker advances by frame 3, stays at contact distance through frame 31,
and returns by frame 35. Rounded 3D fist/palm silhouettes alternate around the
opponent, with sharp source-textured flashes and a larger closing palm/impact
at frame 28. A translucent blue floor spotlight recalls the original background
while preserving the arena and free camera. This is authored geometry using
packaged SV effect masks, not imported 2D strike sprites or a new native rig clip.

Five sound repetitions retain the original frames (3, 6, 11, 13, 16) and pitches
(100, 85, 110, 100, 65). The final blow reuses the last heavy cue at frame 28.
`build_recipe_edits.py --moves closecombat` rebuilds the bounded source edit and
cue train reproducibly; ordinary recipe generation no longer deduplicates this
combo to a single impact sound. All contact sounds require a confirmed hit.

The intermediate flashes are choreography, not additional damage events. Damage
handoff stays at the final impact. On a miss, dodge starts before the first blow
and holds through the finisher; the original aim remains fixed. Miss/block
suppress contact flashes and audio. Native-clock pause and cancellation remain
in charge of the entire sequence, including restoring contact/dodge offsets.
Other moves retain their existing approach and dodge timings.

Validation:

- `close_combat_3d_check.tscn`: storyboard hash and 14 source accents, six cues,
  all four slots and hit/miss/block, early dodge, contact hold and cancellation;
  35 pieces at the highest sampled frame (budget 90).
- `move_recipe_3d_check.tscn`: all 170 recipes, audio bounds and lifecycle.
- `battle_dodge_3d_check.tscn`: existing dodge/audio/cancellation behavior.
- `test_move_recipe_sources.py` and `build_recipe_edits.py --check`: provenance,
  audio references, hashes, fades and clipping checks.
- `close_combat_preview.gd -- --moves --smoke-combo`: 22 rendered frames across
  both attacking sides, including miss, pause and camera orbit.

Interactive preview: `tests/close_combat_preview.gd -- --moves` through the
assigned slot. This revision awaits the user's visual approval. The symbolic
hands are shared across species; native species attack poses are retained.
