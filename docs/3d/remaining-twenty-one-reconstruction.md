# Remaining 21 forms: authored reconstruction previews

The user authorized reconstructing missing geometry, animation and effects after
confirming that Biochao, SCVI and Legends Z-A are the available sources. This
checkpoint provides normal and shiny local previews for all 21 forms. It does
**not** admit them to the reviewed catalog. The original audit still has 208
restored forms and 21 open forms. No game assets, launcher registry, approved
release index or R2 object changes are part of this task.

## What was recovered or authored

| Forms | Work in this preview |
| --- | --- |
| Castform Rainy, Sunny, Snowy | Isolate source rigs; recover available named clips; bake source surface graphs over the exported UV domains; author missing clips and shiny palette proposals. Snowy's shell opacity and visibility are reconstructed. |
| Ash-Greninja | Recover five real battle clips from individual slots within the source's single layered Action. Repaint absent image references in the original UV layout, including eyes, limb pads and head marking. Author sleep. |
| Eternamax | Retain source geometry, bake source surfaces, author generic battle-motion and shiny proposals. Use a review-only 0.01 scale. |
| Primal Groudon/Kyogre | Import source geometry and available clips; rebuild source-table colours and emission; author missing sleep. |
| Necrozma Dawn Wings/Dusk Mane/Ultra | Retain source geometry and available clips; add authored effect or missing-motion/palette proposals. |
| Four Ogerpon Tera forms | Bind a frozen source mask pose to the body head bone; hide auxiliary source branches; reconstruct crystal/layer effects and generic body motion. Wellspring uses its distinct source mesh names. |
| Spiky-eared Pichu; six Cosplay Pikachu forms | Use animated native bases and new bone-bound ear/costume geometry. Reconstruct the female black tail tip. |

Native animation recovery does not imply pixel parity with the original game.
Several models need artistic refinement. In particular, costume fit, Ogerpon
effect intensity/transparency, Primal palettes, newly painted Ash markings,
older shiny palettes, sleep eyes and generic authored motions need review.
Passing geometry checks must not be interpreted as artistic approval.

## Local evidence

`tools/sprite_factory/remaining_twenty_one_result.json` records the exact 42
scene identities, code/evidence hashes, unchanged registry hashes, renderer,
sample counts and limitations. Its approval flags remain false.

The retained slot-c artifact directory is
`.tmp/remaining-twenty-one-v2/review-v5/`. Open `index.html` there for all 21
normal/shiny pairs, seven still poses per appearance and inspection movies.
Movies contain a 24-sample turntable followed by 12 evenly spaced samples per
clip; they do not represent original playback speed. All recordings use the
Linux Compatibility renderer and source-scale autoframing, not battle cameras.

The reviewer checks finite posed bounds, required clips, timing, reverse-order
pose reset and bone attachment transforms. The collector separately rejects
engine errors, missing or duplicate appearances, missing mask attachments,
missing output frames and mismatched hashes even if Godot exits successfully.
Earlier failed/rejected attempts remain separate in the same task directory.

## Reproduction in an assigned slot

These tools depend on the pinned source intake from the earlier alternate-form
audit, the source archives on the external drive, the slot-local SCVI importer
and its Python dependencies. They do not download additional source models or
copy caches between slots. Keep native import receipts and source hashes.

From the frontend slot, run these host Python phases with `POKEAETHER_SLOT`
set to that slot. Blender uses the existing isolated Flatpak worker wrapper;
it must not inherit the Godot slot XDG paths.

```sh
python tools/sprite_factory/remaining_twenty_one.py native
python tools/sprite_factory/remaining_twenty_one.py legacy
python tools/sprite_factory/remaining_twenty_one_bake.py castform-sunny castform-rainy castform-snowy eternatus-eternamax
python tools/sprite_factory/remaining_twenty_one_materials.py native
python tools/sprite_factory/remaining_twenty_one_materials.py legacy
python tools/sprite_factory/remaining_twenty_one.py stage
python tools/sprite_factory/remaining_twenty_one.py review-project
```

Run Godot through `ops/worktrees/slot-env SLOT -- COMMAND`, using the generated
`runtime-project` and a fresh absolute output directory. First run
`res://tools/sprite_factory/remaining_twenty_one_build.gd -- STAGE_JSON OUTPUT`.
Then set `POKEAETHER_PHASE5_REVIEW=OUTPUT` and run
`res://tools/sprite_factory/remaining_twenty_one_review.gd` with a rendering
display. Keep logs as `build-vN.log` and `render-vN.log`, beside `review-vN`.
Do not overwrite a completed preview's catalog or review.

Finally run `remaining_twenty_one_result.py OUTPUT` to validate evidence, encode
inspection movies with ffmpeg, and generate the local gallery and receipt.
Run the focused Python reconstruction tests and the existing fourteen-form
qualification regression. Do not run a full release gate for this preview.

## Admission remains a separate step

Review and refine the new art first. Accepted appearances still need closed-eye
sleep states, battle framing/motion qualification, instance/material isolation,
package round-trip checks and the existing shared normal/shiny bundle contract.
Only then can an additive admission change reduce the remaining-form count.
Publishing or replacing R2 assets is outside this preview checkpoint.
