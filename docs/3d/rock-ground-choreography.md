# Rock and ground choreography

Six catalogue moves use `rock_ground_forms_3d.gd` through the existing Extended
renderer. Rock Slide keeps its approved choreography; its faceted stone mesh
and materials are reused without changing that move.

| Move | Delivery and impact |
| --- | --- |
| Rock Tomb | Four tall blocks fall into an enclosure with an opening toward the camera. |
| Stone Edge | An advancing ground fault leads into a broad fan of seven sharp blades. |
| Rock Blast | Five tumbling rocks grow from a narrow launch into a staggered volley. |
| Ancient Power | Six substantial stones levitate around the caster and converge along arcs. |
| Bulldoze | A wide, low front of soil slabs travels with connected trailing dust. |
| Precipice Blades | A volcanic fault raises dark pinnacles and a tall crown with heated edges. |

The existing duration, launch/impact markers, audio and gameplay targeting are
unchanged. The first projectile/block arrives at native impact; secondary
arrivals and debris fit inside the existing recovery. Confirmed impact forms
are omitted for misses and blocks. Captured aim and terrain anchors do not
follow a dodging victim. Geometry uses world dimensions and full transformed
mesh bounds to keep low projectiles and tumbling debris above the arena floor.

All geometry, fades, light and recoil follow native time. Camera shots use fixed
envelopes, respect the existing camera setting and recover to the overview.
Materials, meshes and pooled pieces belong to the effect and are released on
cancellation. No sprites or independent particle simulations are used.

Focused check: `res://tests/rock_ground_3d_check.tscn`. It exercises all six moves
in singles/doubles, all slots, three outcomes, camera framing and settings,
native pause/recovery, cancellation, translated floors, low/flying anchors and
captured aim. The selected-move extended and remaining-presentation checks cover
audio/timing contracts and environment cleanup. Native arena previews use
`tests/elemental_batch_preview.gd` with `POKEAETHER_TEST_MOVES` set to these keys.

Player review is pending; Android hardware performance has not been measured.
