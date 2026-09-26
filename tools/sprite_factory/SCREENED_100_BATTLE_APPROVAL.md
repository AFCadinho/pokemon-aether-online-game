# Screened 100 cohort: battle approval

The user confirmed the earlier visual review and authorized acceptance of
models that pass the machine checks. The 61 normal/shiny technical pairs from
[`screened_100_shiny_production_results.json`](screened_100_shiny_production_results.json)
were measured with the existing flat-floor Classic and Stadium battle cameras.
Each normal GLB received a full 60 Hz native-clip pose sweep and 16 camera/HUD
views. Twelve small models received the existing minimum-readability scale rule
and were measured again. The motion baker supplied ground clearance for both
physical attacks where present, special attack, damage, sleep and faint. Its
sleep rounding now respects the runtime's exact negative-lift boundary.

**55 pairs passed placement and motion preflight.** Six remain in the review
queue because their sampled envelope intersects the battle HUD area:
Charizard, Corviknight, Gyarados, Haunter and Mewtwo. Dondozo also leaves the
camera frame. No source or renderer rework was made for these cases.

The 55 pairs then passed the real battle presenter in six groups, each over
Classic, Stadium and Classic rounds. The test exercised both variants on both
sides, attacks, faint/replacement, cache eviction, scene reload and HUD
clearance. The first performance run had transient uncovered load stalls in
four groups. The four complete repeated groups met the existing thresholds:
frame p95 at most 20 ms, load dispatch at most 16.67 ms, no uncovered hitch
over 100 ms, bounded source cache and less than 1 MiB static growth between
the last two rounds. The retained first-attempt reports remain alongside the
accepted repeats in `.tmp/screened-100-battle-approval/`.

The exact decisions, scene hashes, stress report hashes and hold reasons are in
[`screened_100_battle_qualification.json`](screened_100_battle_qualification.json).
The approval is pinned by
[`screened_100_battle_approval.json`](screened_100_battle_approval.json).
The 55 individual normal/shiny bundles and their asset index are local at
`/home/adinho/Documents/3d_models/PokeAether/screened-100-qualified-bundles-v1`.
Their total is 1,340,524,552 bytes (1,278.42 MiB). Each archive's members,
normal/shiny hashes, size and SHA-256 passed
[`screened_100_bundle_preflight.json`](screened_100_bundle_preflight.json).

The reviewed game and launcher registries now contain 76 approved pairs in
total: the previous 21 plus these 55. The screened registry retains 20
normal-only models: the six battle placement holds and 14 earlier
source/material holds. The original 75-normal local catalog remains usable and
now resolves each entry against its current reviewed or screened status.

Focused post-approval checks passed: the original 75-entry local catalog
loaded its remaining screened cases; the reviewed-model admission check kept
hash and fallback protections; Garchomp, Hydreigon and Volcarona passed three
more battle rounds against the promoted registry; Garchomp and Volcarona also
loaded from scenes extracted from their new archives. Rebuilding the existing
21-bundle v2 release produced the same index SHA-256. Twenty-two relevant
Python tests passed.

This run is a local approval and bundle preparation. The new archives and
content index are not on R2, and the desktop launcher still selects the v2
21-species release. Desktop release certification and a new content index are
separate work. The 60 Hz sweep and sampled battle views do not prove every
interpolated pose or every camera angle; individual bundles permit a later
targeted correction if a visible issue is reported.
