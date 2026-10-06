# Battlefield staging — second review batch

Earthquake, Blizzard and Bloom Doom were approved by the user on 2026-10-06.
Their existing choreography is retained and their recipe review flags now record
that approval. The nine additions below still await user visual approval.

| Move | Seconds | Field choreography |
| --- | --- | --- |
| Earth Power | 2.6 | Energy branches out from the caster into staggered ground vents |
| Heat Wave | 2.6 | Two red-hot curling flame fronts and a wake of rising embers cross the circle |
| Hurricane | 3.0 | A broad wind funnel with soft rotating ribbons and drifting clouds |
| Bleakwind Storm | 3.0 | Two opposed icy spirals with clouds circulating around the field |
| Powder Snow | 2.2 | Low powder opens into a wide, drifting front |
| Freeze-Dry | 2.5 | Frost links and crystals develop across the ground, followed by a target flourish |
| Explosion | 2.8 | Charge at the caster, expanding shockwave, faint shell and dust |
| Make It Rain | 2.8 | Gold coins rise from the caster and fall over the circle |
| Tera Starstorm | 4.0 | A large central star and constellation form overhead, descend across the field and burst into prismatic fragments and ground ripples |

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
Tera Starstorm's two sound edits were rebuilt from their existing sources for
the revised four-second clock (launch at 30%, impact at 72%). Other sound edits
are preserved. `build_recipe_edits.py --moves terastarstorm` updates only those
edits while retaining and auditing the other manifest entries. No new sound
sources were introduced.

## Heat Wave / Tera Starstorm follow-up

The user found Heat Wave too earth-like and Tera Starstorm underwhelming. Heat
Wave now also uses Ember's packaged SV flame and spark masks, shaded with dense
red/orange edges and a hot yellow center. Upright flames curl over the field and
leave rising embers behind. The mixed-alpha flame shader avoids the previous
washed-out additive dust appearance; source atlases still interpolate frames.

Tera Starstorm builds a larger central star with a soft halo, surrounding stars
and connecting light. The main star descends toward the captured aim while the
smaller stars shower across the field. The final burst adds sixteen radiating
fragments and three expanding floor ripples. Its normal duration is four
seconds; it remains within the existing 90-piece budget and uses the same
clock for effects, dodge and audio. Both revisions await visual approval.

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

The follow-up was checked with both focused Godot checks above and twelve new
captures (two moves, three phases, both sides including misses/orbit/pause).
The interactive preview now focuses on Heat Wave and Tera Starstorm. Run it
through the assigned slot with `-- --moves` to review both.
