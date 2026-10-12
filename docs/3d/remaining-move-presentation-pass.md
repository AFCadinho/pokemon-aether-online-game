# Remaining catalogue presentation pass

This pass accounts for **all 901 gameplay moves**. It refines the remaining
**821 catalogue presentations** through their existing choreography, with shared
construction for related shapes and each recipe's own element, colour, dimensions,
counts, trajectory and timing. It does not claim 821 completely bespoke storyboards.

The [per-move inventory](remaining-move-presentation-pass.csv) lists every key,
renderer, motif, treatment and recipe camera/lighting configuration. Dedicated
camera/lighting profiles take precedence over those recipe fields.

| Route | Count | Treatment |
| --- | ---: | --- |
| Extended catalogue | 693 | Smooth surfaces, continuous wakes, elemental impacts, restrained support effects |
| Original staged recipes | 121 | Replace ordinary source-sprite accents; simplify beams, trails, rushes, clouds, auras and pulses |
| Remaining battlefield recipes | 7 | Smooth supporting volumes/materials; retain cracks, coins, ice, wind and stars |
| Dedicated original moves | 24 | Retain existing individual choreography and attachments |
| Z-moves | 35 | Retain cinematic finales and per-move staging |
| Recent elemental refinements | 20 | Retain their individual forms, camera and environment |
| Fiery Wrath | 1 | Retain its continuous crimson flame wall |

## Visual treatment

- Beams keep a small emitter cross-section and widen along the existing path.
  Ordinary staged beams lose their orbiting sprite chains; continuous cores and
  soft outer shafts supply the volume. Reviewed emission cutoff markers still win.
- Projectiles use a continuous taper behind their captured path, including arcing
  bombs. The tail length cannot exceed the distance already travelled.
- Elemental rushes carry one actor-following wake. Physical attacks retain their
  native contact motion and a short compressed hit shape.
- Psychic/dark pulses use fewer fronts with soft depth instead of stacks of bright
  crossed crescents. Returning drains have a continuous return trail.
- Confirmed ranged hits bloom into connected volumes. Rock, ground, metal and ice
  use a joined fracture crown; larger burst/Max motifs get more room and volume.
  Misses and blocks never receive this added impact.
- Eruptions distinguish fire vents, curling roots and jagged joined rock ridges.
  Vortices have flowing bands across one funnel rather than a barely visible dome.
- Powder and mist cast as three overlapping low cloud volumes. Heals and boosts
  use broad curved auras, with fewer supporting healing symbols. Screens, hearts,
  cages, threads, hazards, terrain marks and named motifs remain recognisable.
  Will-O-Wisp retains the violet ghost-flame colour of its previous source art.
- Ranged camera profiles frame the charge and target on the same side of the
  action axis; fixed bounds include impacts and projectile arcs. Quick/contact
  moves keep the overview. Five single-target bursts use tighter target framing.
- Added ordinary cinematic backgrounds use 45% of the existing full backdrop
  strength. Status lighting stays subtle; neutral physical moves stay neutral.
  Z-moves, Fiery Wrath and recent individually authored elemental profiles retain
  their existing intensity.

`move_cinematic_forms_3d.gd` and `move_cinematic_surface_3d.gdshader` provide reusable
geometry/material construction. They do not own timing, Pokémon motion, damage,
status, healing, persistent weather or terrain. Meshes and shader code are shared;
material instances belong to each effect and are released with it. Shader motion
uses the native move clock, with no `TIME`, random emission or per-frame mesh build
in the new helper.

The original native duration, launch/impact fractions, audio, source references,
attachment rules, recipe counts, dimensions and gameplay outcomes were retained.
The new camera recovers to the player's orbit/zoom and respects camera-motion
settings. Temporary atmosphere continues to restore the owning weather/environment.

## Validation

Focused slot checks cover the changed catalogue, not a full release certification:

- `remaining_move_presentation_check`: all 821 changed routes, 19,704 samples;
  singles/doubles, hit/miss/block, actual solid bounds, native pause, camera opt-out,
  recovery, no ordinary source-sprite shaders, material release and cleanup.
  The inventory also has exactly 901 unique supported keys.
- `extended_move_3d_check`: all 707 extensions, 84,840 samples, four actor slots,
  both directions, three outcomes, native audio and bounded geometry/light counts.
- `move_recipe_3d_check`: all 170 original recipes, 15,300 samples, timing, audio,
  routing, self targets and lifecycle.
- `completed_move_staging_check`: translated/elevated arenas, double emitters,
  native pause and captured targets; 124 staged originals and 34 Z routes.
  The fixture now compares visible world bounds for swept meshes whose vertices
  already store world coordinates, and reads the Z renderer's actual captured fields.
- Existing camera, lighting, battlefield, five-move/15-move elemental and 35-Z
  cinematic regressions remain part of the focused checks for shared code.
- `remaining_moves_preview.gd`: GPU captures of all 901 moves at charge, delivery
  and impact, alternating attack directions; representative visual inspection of
  all 110 remaining renderer/motif combinations. A 15-move pilot additionally
  captures both directions and all three outcomes. Refined funnels/bursts receive
  an additional both-direction/outcome capture pass. The final 167-move refinement
  capture covers changed wakes, bursts, eruption and funnel surfaces.

GPU captures are automated coverage; visual inspection is representative, not a
claim that every move, species and camera combination was manually watched.
Native anatomy/animation choices still depend on the existing attachment catalogue.
Low-end/mobile GPU performance has not been benchmarked. This revision remains
**pending player review**; earlier approval records are historical.

Artifacts and logs stay in the assigned slot at
`.runtime/test-logs/remaining-moves/`. Example reproduction from the workspace root:

```sh
ops/worktrees/slot-env slot-b -- godot --headless --path .worktrees/slot-b/frontend res://tests/remaining_move_presentation_check.tscn
DISPLAY=:0 POKEAETHER_STAGE_OUTPUT=/absolute/slot/output ops/worktrees/slot-env slot-b -- godot --path .worktrees/slot-b/frontend --script res://tests/remaining_moves_preview.gd --resolution 1280x720 -- --moves --catalogue
```

Omit `--catalogue` for both directions and three outcomes. `POKEAETHER_TEST_MOVES`
accepts a comma-separated key list for a focused preview.
