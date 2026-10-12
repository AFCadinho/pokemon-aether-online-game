# Five elemental move refinements

This pass applies the continuous-form approach of Fiery Wrath to five ordinary
special attacks. These new presentations are implemented and pending player
review. The previously approved Fiery Wrath and Z-move effects are unchanged.

| Move | Main form and delivery | Confirmed impact | Atmosphere | Duration |
| --- | --- | --- | --- | --- |
| Dark Pulse | Compact charge becomes a dense, folded violet pressure front with a connected wake | Front expands and disperses at the target | Dark violet, brief pale-violet impact light | 1.8 s |
| Surf | Rising water mass travels along the floor with a rolled lip and continuous foam edge | Curl collapses with five connected splash plumes | Cool cyan; low, wide side view | 1.4 s |
| Blizzard | Three overlapping soft snow volumes sweep across the field; eight ice slivers indicate wind direction | Low frost pressure wave | Desaturated cold blue, distant haze | 3.0 s |
| Earth Power | A branching heated seam travels along the ground | Seven lifted rock slabs, rising energy vents and a low pressure wave | Restrained amber, brighter on rupture | 2.6 s |
| Overheat | Five rising flame tongues gather around the caster, releasing a compact growing fire mass | Billowing blast body, hot core and rising flames | Orange-red heat with a warm impact light | 1.65 s |

## Runtime boundaries

- `elemental_move_effect_3d.gd` owns only these five keys. It is routed before
  the existing field, staged and extension renderers. Other moves keep their
  existing implementations.
- Native launch, impact, duration and audio recipes are preserved. The effect
  uses the native animation clock for mesh transforms and shader motion; pause
  also freezes the surface animation and camera.
- Geometry is authored in world metres, independent of emitter magnification.
  Capture the field/ground once and the source/aim through launch, so a camera
  change or dodge cannot drag the released attack.
- Delivery remains visible on misses and blocks. Extra impact geometry and
  impact lights require a confirmed hit. No gameplay state is written.
- The normal camera setting remains respected. Fixed framing envelopes avoid
  camera pumping as the geometry expands. Recovery returns to the user's orbit
  and zoom before cleanup.
- Colour, background fog and at most two unshadowed lights belong to the
  existing temporary move atmosphere; active weather and the original arena
  environment are restored on completion/cancellation.
- Meshes and materials are created once per effect and pooled during playback;
  no sprites or per-frame mesh generation are used. Fewer than 32 draw pieces
  are needed in the exercised frames.

## Validation

Focused Godot 4.6.2 checks in slot B:

- `elemental_move_forms_check.tscn`: five moves, singles/doubles, every actor
  slot, hit/miss/block, native duration, effect bounds in frame, frozen mesh
  transforms/shader time/camera, weather preservation, camera toggle, recovery,
  cancellation and awaited impact/recovery lifecycle.
- `battlefield_move_check.tscn`: all twelve field routes across three arenas,
  captured positions, both halves of the field and geometry budget.
- `move_camera_choreography_check.tscn`: eleven existing camera profiles,
  portrait framing, substitute targets, settings, ownership and recovery.
- `move_lighting_profiles_check.tscn`: existing ten lighting profiles, weather,
  environment ownership, pause, disabled cinematic camera and cleanup.
- `move_recipe_3d_check.tscn`: 170 recipe routes, sound bounds, four actor slots,
  three outcomes and 15,300 visual samples. Its manual actor fixture now includes
  the radius used by the existing Skystrike implementation.
- `extended_move_3d_check.tscn` with `POKEAETHER_TEST_MOVES=surf,overheat,fierywrath,hydropump`:
  the two changed extensions, approved Wrath reference and beam regression,
  plus the existing presentation checks for eleven camera profiles.
- `elemental_move_forms_preview.gd -- --moves`: GPU preview with Dragonite and
  Pikachu, both directions, three outcomes and seven phases (210 captures).
  Representative charge, travel, hit and decay frames were reviewed visually.
- Recipe diff check: only the three original presentation-review statuses
  changed; all timing/audio values, extensions and Z recipes are unchanged.

Ignored logs and preview captures are retained in the assigned slot under
`.runtime/test-logs/elemental-forms`. This is focused validation, not a complete
release certification. Preview asset UID fallbacks are unrelated to the new
geometry; no script/shader errors are accepted. Low-end GPU performance and
player approval remain unverified.
