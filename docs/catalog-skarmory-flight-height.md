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

## Approved local revision2

The user approved the higher normal/shiny flight on2026-10-01. Final SCNs
use the standard compressed delivery format; exact geometry/animation parity
with the reviewed scenes passed. The v2 bundle is7146179bytes (6.82MiB).
Fresh installation, actualv1-to-v2 update, no-op and restart passed. Three
installed real-battle functional passes in classic/stadium/classic passed,
including swaps and faint replacement, without errors.

A first real-battle pass exposed brief HP overlap while the panel eased upward
to the newly revealed higher model. `immersive_hud.gd` now moves upward
immediately to its safe target while retaining downward easing. The original
battle assertions and existing immersive layout check passed. No tests or
clearance thresholds were weakened. Frame-rate certification remains separate
under the current concurrent Godot load.

The active local game and launcher registries now accept v2. Existing v1 hashes
remain valid: placement, native timing and clearance offsets are unchanged,
and conservative bounds enclose both revisions. A post-admission check verified
both old/new hashes, matching registry files, exactly one123-bone skeleton,
three meshes, non-null materials and rejection of unapproved hashes.
The catalog count remains807 ordinary species plus Mega Dragonite.

`catalog_skarmory_flight_height_qualification.json` binds the v2 bundle index
and checks. R2 and release publication remain pending.
