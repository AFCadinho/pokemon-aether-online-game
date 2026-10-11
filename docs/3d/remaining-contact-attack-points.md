# Final missing contact origins

Task `remaining-attack-points`, 2026-10-11. See the
[evidence report](remaining-contact-attack-points.json).

| Form / move | Origin | Native action / timing |
| --- | --- | --- |
| Hisuian Avalugg / Rock Smash | A projected surface point at the front ice plate, bound to `left_feeler_a`. The stationary foreleg is not the striking surface in this motion. | `physical_attack_2`, launch .25, impact .43 |
| Alolan Raichu / Double Kick | Lifted left toe, bound to `left_foot_index`. Both toe points are calibrated; the move explicitly selects `left_foot`. | `physical_attack_2`, launch .28, impact .43 |

Avalugg thrusts its closed front plates forward. Raichu's second physical clip
raises its left leg for a forward kick; its first physical clip spins on its
tail. Double Kick retains the existing two strike accents. This does not author
a new two-kick skeletal animation.

Normal and shiny share each form's profile. Existing mouth and hand points are
preserved. No model payload, shared geometry pack or backend change is needed.

## Checks

- Marker sheets: four native actions, three front poses and one side pose each.
- Actual stage effects: two moves, normal/shiny, trainer/wild, two views and
  eight fractions (.25, .35, .40, .43, .46, .50, .56, .65); eight sheets total.
- All four trainer/wild pairs have byte-identical images and identical capture
  metadata except the battle-kind label.
- Native binding check: four models, 1,176 point samples, zero errors; normal
  and shiny pose results match. All configured points are sampled 21 times per
  native action, including the existing mouth/hand points.
- `move_attachments_3d_check.tscn`: includes regression assertions for both
  appearances, exact part/bone selection, clip/timing selection, moving bone
  updates and preservation of mouth routes.
- `move_attachment_choreography_3d_check.tscn`: passed.
- Fresh full learnset metadata audit: 1,200 forms, 30,646 supported move/form
  pairs, 8,335 configured bone-bound routes, **zero missing anatomical routes**.

The two routes are outside the earlier 295-form cohort. Its historical counts
remain separate. Procedural body/orb origins are intentionally excluded from
missing bone-point counts.

## Scope and reproduction

These are offline checks of the actual stage, native animation, contact approach
and effects. Live server encounter setup was not tested. Exact target-contact
spacing, oversized impact art and continuous clearance across every frame and
target size remain outside this origin review.

Retained evidence is under `.tmp/remaining-attack-points` in slot-c. The native
catalog is `.tmp/repaired-model-attachments/catalog.json`; source scenes are
read in place. Reuse `attack_attachment_preview.gd`,
`attack_attachment_move_preview.gd`, `check_calibrated_move_attachments.gd` and
`audit_move_attachment_learnsets.gd` through the assigned slot's `slot-env`.
Refresh the backlog with `summarize_attack_attachment_families.py` after the
learnset audit. The report pins source, image and capture hashes. Effect captures
precede addition of review metadata; runtime offsets, routes and timing are the
same as the final checked profile.
