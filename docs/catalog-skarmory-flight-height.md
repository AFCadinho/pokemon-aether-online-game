# Skarmory flight height review

The previously approved Skarmory pair flies with its lowest idle point only
0.025m above the floor. This passes floor clearance but looks too low.

The candidate adds0.7m on a separate visual parent for idle, attacks and damage.
Faint retains that height for0.4s and descends to the original height by1.4s;
sleep and faint loop retain the original grounded placement. Model scale,
gameplay root, original animation keys, clip clocks and bone poses are intact.

Both actual scenes passed120Hz all-clip clearance and16 camera views each.
Native preservation checks verified820 original tracks and21 fresh bone poses
per variant. Normal/shiny geometry and animation structure match exactly.
The floor threshold was unchanged.

The candidate wrapper clears existing PackedScene instance paths before packing,
preventing an inherited source instance from duplicating the skeleton. A first
prototype failed the native pose-count gate and is superseded; the corrected
pair passes the original gate. Original packed resources are included to make
the candidate standalone. Final compression and installed runtime checks are
still required after visual approval.

The user comparison is at
http://127.0.0.1:8781/skarmory-flight-v1/review-v1/index.html.
Evidence and full authored recipes are bound in
`tools/sprite_factory/catalog_skarmory_flight_height_candidate.json`.
No active game/launcher registry or R2 bundle has been changed.
