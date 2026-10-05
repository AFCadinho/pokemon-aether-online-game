# Larger native move effects

All 23 implemented 3D moves have authored world-space size multipliers in
`move_effect_3d.gd`. Moonblast and Flash Cannon use 2.5x dimensions, other ranged
moves use 1.6–2.2x, and contact accents use 1.2–1.35x. This changes visible
silhouettes, beam width and impact size, not Pokémon model size or camera zoom.
The same source textures, timing, audio, particle counts and move paths remain.
These values are presentation choices, not recovered native SV scale values.

Scaling happens around each mesh/sprite's own center. Beam/cone length is
explicitly preserved so mouth/cannon origins and target endpoints do not move.
Contact patterns scale through their target radius, including tooth and claw
spacing, instead of enlarging individual teeth twice. Moonblast's larger moon
also sits slightly higher above the emitter to separate it from the orb.

Scale is independent of camera orbit, avoiding size changes while rotating.
The existing bounds-based contact sizing still applies to Pokémon/Substitutes;
ranged effects retain their authored world-space size. Geometry counts do not
increase. Larger transparent surfaces can increase GPU overdraw.

The user approved these 23 moves, their size adjustments and the later Moonblast
charge/clearance revisions on 6 October 2026. Use the assigned slot's `slot-env` to open
`res://tests/move_scale_preview.gd -- --moves`. Its move picker contains all
23 supported moves. `--smoke-move-scale` captures before/after sizes at the same
frozen animation frame for ten representative moves, including Moonblast and
Flash Cannon charge/flight/impact. Set `POKEAETHER_STAGE_OUTPUT` to a directory
inside that slot. The before views set only the presentation multiplier to 1.

Focused checks cover beam/cone endpoints, contact spacing, all 23 move routes,
the ten-move batch, source Ember/Water Gun and contact effects. The optional
historical Ember parity check compares the original recipe at scale 1.
