# Close Combat — 2D-inspired 3D combo

Close Combat now follows the existing 37-frame 2D storyboard over 2.6 seconds.
The recipe records its source path/hash and fourteen original strike accents,
including their frame, pattern and offsets. The 2D files remain unchanged.

The attacker advances by frame 3, stays at contact distance through frame 31,
and returns by frame 35. The attacker shifts weight and turns through the barrage, staying behind the
contact boundary, then draws back before the final blow. Each original accent
now leads an overlapping left/right pair: 26 large fists and one closing palm.
The fists alternate saturated red and blue, with matching source-mask flashes
and punch trails. The final palm combines both colors, including alternating
impact rays and red/blue ground rings.
Curved trails, broad knuckle rows and stronger source-textured flashes emphasize
the combination, followed by a larger closing palm/impact
at frame 28. A translucent blue floor spotlight recalls the original background
while preserving the arena and free camera. This is authored geometry using
packaged SV effect masks, not imported 2D strike sprites or a new native rig clip.

Five sound repetitions retain the original frames (3, 6, 11, 13, 16) and pitches
(100, 85, 110, 100, 65). Two extra repeats reuse the original cues at frames 21 and 24, and the final
blow reuses the last heavy cue at frame 28.
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

- `close_combat_3d_check.tscn`: storyboard hash and 14 source accents, eight cues,
  all four slots and hit/miss/block, early dodge, bounded contact weight shifts and cancellation;
  94 pieces at the highest sampled frame (budget 120).
- `move_recipe_3d_check.tscn`: all 170 recipes, audio bounds and lifecycle.
- `battle_dodge_3d_check.tscn`: existing dodge/audio/cancellation behavior.
- `test_move_recipe_sources.py` and `build_recipe_edits.py --check`: provenance,
  audio references, hashes, fades and clipping checks.
- `close_combat_preview.gd -- --moves --smoke-combo`: 22 rendered frames across
  both attacking sides, including miss, pause and camera orbit.

Interactive preview: `tests/close_combat_preview.gd -- --moves` through the
assigned slot. The user approved the red/blue barrage on 2026-10-06
(implementation `1c94c71e0`, development merge `d9e620079`). The symbolic
hands are shared across species; native species attack poses are retained.
