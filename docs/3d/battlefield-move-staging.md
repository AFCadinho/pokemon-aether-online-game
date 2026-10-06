# Battlefield staging: Earthquake, Blizzard and Bloom Doom

These three pilots use the battle circle to build a move from the attacker's
side, across the arena, into the target climax. They replace their previous
target-local renderers. Visual approval of this revision is still pending.

| Move | Normal duration | Presentation |
| --- | --- | --- |
| Earthquake | 2.8 s | Dust at the caster, travelling ridges, jagged floor fractures and scattered lifted rocks |
| Blizzard | 3.0 s | Snow moving through the circle, curved wind streams and transient frost on the ground |
| Bloom Doom | 3.8 s | A field of flowers grows across the circle; light gathers from it into a soft column and petals at the target |

## Coordinates and lifecycle

`experimental_battle_3d._move_field()` derives the center from the resting single
or double battle spawn positions, including the arena's origin and surface
height. Its minimum radius is 5.8 meters, matching the stadium's painted outer
circle. It expands if necessary to contain the resting spawns plus a margin.
This is an effect footprint, not a collision or terrain boundary query.

`battlefield_move_effect_3d.gd` captures that field, attack direction and target
once. Camera orbit only changes source-sprite facing. Dodging cannot drag the
field or its endpoint after launch. Temporary floor planes do not modify arena
meshes, persistent terrain effects, weather or gameplay state. They fade and
are freed with the normal move lifecycle. The effect keeps the existing shared
attack/audio clock and pause/cancellation behavior. Confirmed-hit flashes remain
gated; a miss still completes the cast at its original aim while the defender
dodges. Wide scenery does not introduce additional damage events.

The implementation reuses the existing packaged SV dump masks from these
recipes. The floor shader, flowers and choreography are authored Godot effects,
not a conversion of Nintendo's original animation simulation. Bloom Doom keeps
its recorded 2D inspiration and shared grass masks. Existing audio source edits
are retained; cue onsets follow each move's updated launch/impact timing.

## Validation and preview

- `tests/battlefield_move_check.tscn`: dispatch, translated/elevated arenas,
  singles/doubles, hit/miss/block, fixed aim, geometry on both sides of the field,
  finite coordinates and a maximum of 90 pooled pieces.
- `tests/move_recipe_3d_check.tscn`: all 170 recipe moves, four slots, three
  outcomes, timing/lifecycle and geometry bounds (15,300 samples).
- `tests/z_move_choreography_check.tscn`: 35 Z-moves including Bloom Doom's new
  dispatch, source hashes, timing, contact restoration and audio markers.
- `tools/battle_effects/test_move_recipe_sources.py`: packaged source provenance.
- `tests/battlefield_move_preview.gd -- --moves --smoke-field`: 18 captures across
  three phases, three moves, forward hits and reverse misses; camera orbit while
  paused, followed by completion and cleanup.

For interactive review, run the same preview with `-- --moves` through the
assigned slot environment. Choose the move/outcome/attacking side, play or pause,
and orbit the camera. Rendered visual inspection covers the stadium; field
placement on translated and elevated arenas is checked programmatically.
Other move families remain on their existing presentations pending this pilot's
visual review.
