# Seven additional battle forms

Task: `battle-forms-next-seven`, assigned paired slot `slot-a`.

The user approved the appearances of Mimikyu Busted, Palafin Hero,
Eiscue Noice, Aegislash Blade, Wishiwashi School, Morpeko Hangry and
Darmanitan Zen, including normal and shiny. Their final battle presentation
still requires user approval. A final image audit found Ice Face meshes
enabled in Eiscue Noice; its corrected bare-head selection needs renewed
appearance approval. Nothing in this task has been activated or published.

## Resume from accepted assets

`tools/sprite_factory/catalog_battle_forms_next_seven_checkpoint.json` pins
accepted GLBs and their real animation durations. Use that checkpoint for
staging, rather than replaying an older preview stage. It records appearance
approval separately from battle approval and admission.

The ignored evidence root is `.tmp/battle-forms-next-seven-v1` in the assigned
frontend worktree. The original import tool is an intake/export tool; it is not
an admission tool and does not include all later appearance corrections.

- Darmanitan uses rig `pm0555_12` from `pm0555_11_12.blend`.
  Its mirrored source shader must be baked over UV 0..1; remove the doubled
  exported albedo transform after substituting that atlas. The checkpoint
  records the bake recipe and input hashes. Reproduce the two approved atlases
  with `catalog_battle_forms_darmanitan_bake.py --work ROOT --output NEW_DIR`.
  The separate `_12_31` source is Galar Zen, not Unova Zen shiny.
- Eiscue shares Ice Face and Noice meshes in one source bank.
  `catalog_battle_forms_eiscue_noice.py` disables seven Ice Face/fragment
  meshes and retains the bare head, eyes, body and straight antenna, without
  changing any rig, clip, material or geometry buffer.
- Morpeko uses the corrected SCVI Hangry body/eye mesh selection with imported
  own-species clips, not the earlier visually rejected legacy candidate.
- Wishiwashi has no identified native sleep or faint bank in this export.
  Its reviewed sleep is the swimming idle; its faint proposal is own-rig
  damage followed by an authored constant endpoint hold. Keep that limitation
  explicit. Its scale is reduced for battle framing, pending visual approval.
- Darmanitan retains its native faint start and gets a constant endpoint hold
  instead of looping the entire down animation. The reusable
  `catalog_battle_forms_faint_hold.py SOURCE NEW_GLB` preserves materials,
  geometry and all other clips.

## Focused review steps

1. `catalog_battle_forms_next_seven_stage.py` verifies asset hashes and actual
   GLB clip durations against the checkpoint, then writes a new conversion
   stage and battle catalog with Dragonite as comparison control.
2. Convert with `prepare_battle_3d_runtime.gd` via `slot-env slot-a`.
   Complete pose channels and standalone reload checks are required.
3. Measure using `catalog_batch_battle_review.gd` with margin 0.035.
4. `catalog_battle_forms_next_seven_calibrate.py` builds review-only
   readability and clearance candidates. Scale changes apply equally to
   normal and shiny. Sleep clearance raises a pose only when needed;
   it does not lower naturally floating models to the floor.
5. Independently validate those candidates at 120 Hz using the same battle
   renderer and `POKEAETHER_PHASE5_CANDIDATES`. A complete report, no floor
   penetration, both sides/cameras and no framing/HUD conflict are required.
6. `catalog_battle_forms_next_seven_review.py --report BATTLE_REPORT
   --catalog CATALOG --output NEW_DIR` makes one page for all seven pairs.
7. After user battle approval, run final runtime/performance admission,
   produce individual bundles, commit and merge into local development.
   R2 publication needs explicit user authorization.

Use new output directories; preserve earlier evidence and rejected previews.
