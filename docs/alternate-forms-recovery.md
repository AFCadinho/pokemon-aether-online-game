# Alternate-form recovery

This is a continuation of the 109 holds from `alternate_forms_batch_result.json`.
The previous 120 approved pairs and their receipt are immutable. New approvals
have their own `alternate_forms_recovery_qualification.json` and
`release/approved_3d_alternate_forms_recovery_index.json`.

The selected model release and R2 are not changed by this task. A prepared pair
becomes downloadable only after a separately authorized model release.

## Result

56 of the 109 held forms now have complete normal/shiny pairs prepared locally.
The remaining 53 retain individual reasons in the recovery result. The earlier
120 approved pairs are unchanged, bringing that 229-form batch to 176 prepared
pairs and 53 holds.

| Evidence | Result |
| --- | ---: |
| New pairs / appearances | 56 / 112 |
| Compressed pair packs | 237,642,096 bytes |
| Native scenes before pair packing | 397,063,123 bytes |
| Exact-pixel comparison frames | 1,320 |
| Animation transition switches | 6,478 |
| Source visibility samples | 207,252 |
| Measured battle views | 2,952 |
| Actual-game checks after catalog admission | 56 |

Packing saves 159,421,027 bytes (40.15%) versus these native scenes. These are
new locally prepared assets; the selected release and current R2 storage are
unchanged.

## Repairs

- **Unown B–Z, ! and ? (27):** use each form's own geometry and actions. Bake
  the archived material graph at the source texture resolution. Where an
  archive omitted its shiny switch, reuse the source-pinned common Unown
  palette after proving the common image bytes match. Preserve the form's
  own AO and UV mapping. I and U have a different eye-switch input. The ?
  archive incorrectly marks its shared eye layer mask as sRGB; treating this
  data mask as Non-Color restores its pupil. Both failed pupil trials remain
  in the diagnostic workspace. Q and R also receive a 0.001 world-unit
  conservative root-height margin: the independent 120 Hz measurement found
  minima just below the 0.025 clearance target between the 60 Hz samples.
  The correction includes idle and is measured again at 120 Hz.
- **Silvally types (17):** compare every bone, mesh, skin and animation against
  the base source before binding base-prefixed actions to the typed rig.
  Preserve the type-specific eye and body accent textures. Reconstruct the
  shared shiny body using the existing reviewed Silvally conversion. These
  archives use centimetres; appearance review framing accounts for that.
- **Squawkabilly Blue, White and Yellow (3):** bind their own sleep animation
  from bank 0 alongside their battle animations from bank 2. Apply the native
  colour slot only to the meshes named by the source; the lower eyelid keeps
  its original material despite sharing a material name with the body.
- **Pumpkaboo and Gourgeist sizes (6):** use the complete native Z-A resources.
  Apply the centre of each source configuration's size interval: 0.8 for
  Small, 1.4 for Large, 1.0 for Super. Super already has twice-sized native
  geometry. A single family-wide readability multiplier (3 for Pumpkaboo,
  2 for Gourgeist) preserves these ratios in battle; individual automatic
  minimum-size corrections are not used for these six forms. This retains
  distinct sizes without changing vertices or textures.
  The [source schema](https://github.com/pkZukan/PokeDocs/blob/main/SV/Flatbuffers/model/trpokecfg.fbs)
  defines the minimum and maximum size fields used by this placement policy.
- **Sawsbuck Summer, Autumn and Winter (3):** assign deterministic priorities
  to the opaque surfaces only. Transparent eyes retain their original
  materials. This fixes nondeterministic overlap ordering during the strict
  original-versus-packed pixel comparison. The source contract reconstructs
  and verifies this exact operation in addition to visibility sampling.

## Qualification

The recovery uses the existing own-rig export, native scene, transition,
appearance, 120 Hz battle-clearance and lossless pair-pack checks. Scene
comparison checks the complete resource signature after the declared
visibility-sampling and Sawsbuck-order operations. Source texture dimensions
are retained. Models are never substituted with a different form merely to
avoid 2D fallback.

The visual review inspects front, back, side, attack, sleep and faint poses for
normal and shiny. Battle contacts cover both cameras and both sides. Automated
battle measurements cover every configured action. Pack checks compare decoded
resources and rendered pixels, then load each pair through the actual game,
including team preview and shiny selection. Final checks repeat against the
admitted registries. These are local Linux/Godot 4.6.2 checks.

## Remaining evidence gaps

`alternate_forms_recovery_result.json` accounts for all original 109 forms and
is the authoritative result. An unresolved entry does not mean that no usable
model exists anywhere. The owner confirmed that the inspected Biochao, SCVI
and Legends Z-A archives are all currently available sources.

- Minior's native colour and scalar emission slots can be decoded, but the
  archived core export also shows meteor shell pieces. Matching visibility
  animation is absent from the inspected source route. Its rendered trial is
  rejected, not used as evidence of a correct core form.
- Cramorant's three source skeletons are identical and sleep can be bound,
  but the archived trial renders both prey models. Skeleton compatibility
  alone is insufficient; these candidates are rejected pending the matching
  visibility and eye channels.
- Ash Greninja has its own archive and rig. The remaining problem is the
  incomplete animation set, superseding the earlier mapping hold.
- Castform weather forms, Eternamax, Ultra Necrozma and the Primal forms lack
  required own-source clips in the inspected routes. No unrelated animation
  is relabelled as recovered native motion.
- Totems and starter/shared-base identities require verified identity and
  scale mappings. Ogerpon Tera and the Artisan/Masterpiece tea forms also
  require positive variant bindings.
- Costume Pikachu and Spiky-eared Pichu require matching source models not
  found in the inspected archives.
- Burmy/Wormadam cloaks and Cherrim Sunshine need verified shiny material
  reconstruction. Necrozma fusions need matching effect animation. Rotom Fan
  needs separate sampling of its detailed base/mask textures; resizing one
  to make the existing single-texture reconstruction pass is not accepted.
  Zygarde 10% and neutral Xerneas retain their probe/state-material holds.

## Reproducing the task

Use an assigned slot and its environment wrapper. Source archives remain
read-only. `.tmp/alternate-forms-recovery-v1` contains candidates, failed
revisions, images and receipts; it is independent of the earlier batch.

1. Prepare source probes and extract the required Z-A resources, using the
   pinned source inventory and the recovery probe worker.
2. Run `alternate_forms_recovery.py setup`, then `materials`, `runtime`,
   `appearance` and `battle` with explicit `--only` subsets. Waiting queues
   require their producer to finish every selected name.
3. Review contacts and record only actually inspected approvals. The contact
   generators deliberately leave `reviewed: false`.
4. Run `delivery`, the recovery source contract, then
   `alternate_forms_recovery_admission.py admit` and `finalize` for qualified
   pairs. Run `alternate_forms_recovery_review.py result` to account for all
   original holds. Admission validates evidence before changing registries.
5. Run focused Python and Godot checks, commit and integrate into local
   `development`. Publication remains a separate release operation.

## Focused regression checks

All 21 Python regression tests, the form-alias check and the motion-placement
check passed. All 56 pairs also passed the actual-game check after admission.

```sh
PYTHONPATH=tools/sprite_factory python3 -m unittest \
  test_alternate_forms_batch test_alternate_forms_recovery \
  test_therian_models test_urshifu_models -v
../../../ops/worktrees/slot-env slot-c -- godot --headless --path . \
  --script res://tests/alternate_model_aliases_check.gd
../../../ops/worktrees/slot-env slot-c -- godot --headless --path . \
  --script res://tests/model_motion_placement_check.gd
```

The source-contract negative check substitutes an incorrect runtime hash and
requires exit status 2 without producing a success receipt. The catalog
regression also checks that the distinct size forms retain their source scale
ratios and increasing battle heights. Super's own idle animation has a different
duration and envelope, so its animated height is not assumed to be exactly twice
Small's unscaled animated height.
