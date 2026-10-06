# Battlefield staging — second review batch

Earthquake, Blizzard and Bloom Doom were approved by the user on 2026-10-06.
Their existing choreography is retained and their recipe review flags now record
that approval. The nine additions below still await user visual approval.

| Move | Seconds | Field choreography |
| --- | --- | --- |
| Earth Power | 2.6 | Energy branches out from the caster into staggered ground vents |
| Heat Wave | 2.6 | Three layers of fire and heat advance across the circle |
| Hurricane | 3.0 | A broad wind funnel with soft rotating ribbons and drifting clouds |
| Bleakwind Storm | 3.0 | Two opposed icy spirals with clouds circulating around the field |
| Powder Snow | 2.2 | Low powder opens into a wide, drifting front |
| Freeze-Dry | 2.5 | Frost links and crystals develop across the ground, followed by a target flourish |
| Explosion | 2.8 | Charge at the caster, expanding shockwave, faint shell and dust |
| Make It Rain | 2.8 | Gold coins rise from the caster and fall over the circle |
| Tera Starstorm | 3.0 | A constellation forms overhead and sends colored stars across the battlefield |

These cover the remaining nine ordinary `area` recipes. This does not change
every remaining move family or mark the whole catalog approved.

## Rendering and source material

The effects share the first batch's captured world field coordinates, normal
move clock, outcome gating, pooling and cancellation. Field staging is visual;
it does not add targets, damage events, persistent weather or terrain. Ground
decoration follows the arena origin/surface height. Other arenas still use the
same inferred circle footprint, without obstacle clipping.

All source masks come from the existing packaged SV dump assets. The choreography,
wind ribbons, crystals, stars and coins are authored in Godot. They are not the
original Nintendo animation simulation. Inspection showed several automatically
selected shock masks were star-shaped; large copies did not read as wind or dust.
`SHARED_CAST_ART` explicitly selects the already packaged Powder Snow cloud mask
for Earth Power, Explosion, Hurricane and Bleakwind Storm, and Pyro Ball fire masks
for Heat Wave. Original hit masks remain available where appropriate. No external
assets or newly generated bitmap art were added.

Wind uses smoothly sampled, reusable ribbon meshes with feathered opacity instead
of a few sharp line segments. Explosion uses a faint rim shader and a finer ring
to avoid a large solid dome. Tera Starstorm uses pointed, faceted stars instead
of crossed cylinders. All effects remain within the 90-piece pool budget.
Existing sound edits are preserved; cue onsets use the updated launch/impact
clock. No new sound sources were introduced.

## Checks and review

- `battlefield_move_check.tscn`: all twelve registered field moves, three arenas,
  singles/doubles, hit/miss/block, stable aim and geometry on both sides of the
  field; finite coordinates and bounded geometry.
- `move_recipe_3d_check.tscn`: all 170 recipe moves and their renderer dispatch,
  timing, lifecycle, outcome handling and geometry budget.
- `test_move_recipe_sources.py`: packaged provenance and sound mappings.
- `battlefield_move_preview.gd -- --moves --smoke-field`: 54 rendered captures
  across nine moves, three phases and both attacking sides, including misses,
  camera orbit and pause. Visual review covers the stadium; alternate arena
  placement is checked programmatically.

The interactive preview now lists these nine moves. Run it through the assigned
slot with `-- --moves` to review them, including both attack directions and misses.
