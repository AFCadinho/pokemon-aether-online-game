# Second elemental refinement batch: 15 moves

This follows the [five elemental refinements](elemental-move-refinements.md)
and the continuous 3D form approach used for Fiery Wrath. Each move has its own
choreography, palette, atmosphere and framing. These new presentations are
implemented and pending player review.

| Move | Delivery | Confirmed impact | Atmosphere |
| --- | --- | --- | --- |
| Fire Blast | Thick sculpted five-ended fire glyph with rising flame tongues | Billowing hot burst | Warm orange |
| Heat Wave | Three connected, staggered hot-air fronts with a low flame bed | Expanding floor pressure wave | Restrained amber heat |
| Eruption | Caster vent launches five molten rocks in high arcs | Target vent, rising fire and a rolling blast body | Deep volcanic orange |
| Lava Plume | Dense low ash rolls forward over a connected flame bed | Broad low fire cloud and pressure wave | Smoky copper |
| Magma Storm | Twin molten helices wrap a moving funnel | Rising flame vents around the target | Dark red-orange |
| Mystical Fire | Three entwined pink flame tongues around a small hot heart | Twisting magical flame ribbons | Pink and warm peach |
| Muddy Water | Heavy brown breaker, lower following wave and sediment | Thick splash plumes | Muted earth tones |
| Sludge Wave | Low viscous bulges merge into a folding purple lip | Thick rising poison plumes | Dim violet |
| Night Daze | Broad radial dusk shock grows from the caster across the field | Compressed dark pressure front at the target | Dark plum |
| Dragon Pulse | Small charge releases a growing energy-dragon head with snout, jaw, horns, eyes and continuous neck | Blue-violet energy burst | Violet-blue |
| Psychic | A pressure lens travels toward the target | Translucent cocoon and tightening intersecting bands | Rose-violet |
| Psyshock | Three solid psychic lances converge | Angular outward fragments and a low shock wave | Pale violet |
| Leaf Storm | A green wind funnel carries a continuous spiral and nine sculpted leaves | Spreading wind front | Cool green |
| Sandsear Storm | A dusty funnel, low sand bank and six orbiting rocks | Searing ground vents and a pressure wave | Dusty ochre |
| Bleakwind Storm | Twin leaning pale vortices with six solid ice blades | Cold pressure cloud and floor wave | Desaturated ice blue |

## Implementation boundaries

- Only the 15 keys in `elemental_batch_profiles_3d.gd` route to
  `elemental_batch_effect_3d.gd`. The earlier five moves keep their original
  choreography; the shared base exposes only palette and material-kind hooks.
- Every move has a separate drawing function. The base supplies native timing,
  captured anchors, pooling and reusable meshes. No per-frame mesh creation or
  enlarged sprite textures are introduced.
- Charge, launch, impact, recovery and surface animation use the native action
  clock. Recipe duration, launch/impact fractions, audio cues and gameplay
  fields are unchanged. Misses and blocks retain delivery but suppress extra
  impact geometry and impact lights.
- Camera shots fit fixed authored volumes and model bounds; field moves retain
  wide framing and focused attacks cut from caster to target. Recovery restores
  the user's orbit/zoom. Disabling cinematic camera motion remains supported.
- Lighting uses at most two unshadowed lights. Temporary environment tint and
  fog use the existing ownership and weather-restoration path.
- Recipe review status changes only for Heat Wave, Bleakwind Storm, Psychic and
  Psyshock. The eleven extension moves were already pending player review.

## Focused validation

Godot 4.6.2, task slot D (explicitly authorized for this task):

- `elemental_batch_check.tscn`: all 15 moves, singles/doubles and every actor
  slot; hit/miss/block; native duration; visible mesh bounds in frame; frozen
  geometry, shader clock and camera; weather; disabled camera; recovery;
  cancellation and awaited impact/recovery lifecycle. Fewer than 48 pieces in
  the sampled frames.
- `elemental_move_forms_check.tscn`: regression for the previous five moves.
- `battlefield_move_check.tscn`: twelve field routes over three arenas,
  captured aim, field coverage, outcomes and geometry budget.
- `move_recipe_3d_check.tscn`: 170 recipe routes, sound bounds, actor slots,
  three outcomes and 15,300 visual samples.
- `extended_move_3d_check.tscn`, filtered to all eleven changed extension moves
  plus Fiery Wrath and Hydro Pump: 1,560 visual samples, native audio and the
  existing eleven-camera presentation checks.
- `move_camera_choreography_check.tscn` and `move_lighting_profiles_check.tscn`:
  existing camera/lighting profiles, portrait framing, substitute targets,
  environment ownership, weather, settings and cleanup.
- `elemental_batch_preview.gd -- --moves`: GPU renders of all 15 moves with
  Dragonite/Pikachu, both directions, hit/miss/block and seven phases (630
  captures). Representative charge, delivery, impact and recovery frames are
  visually reviewed in both directions. Heat Wave, Dragon Pulse and Psychic have a second preview
  after their visual refinements.
- Recipe diff validation confirms that only the four presentation-review
  statuses changed; timing, audio and all Z-move recipes are preserved.

Logs and captures remain in the ignored task-local
`.runtime/test-logs/elemental-batch` directory. The preview reports existing
asset UID fallbacks; no script or shader errors are accepted in successful
runs. This is focused validation, not release certification. Low-end GPU
performance and player approval remain unverified.
