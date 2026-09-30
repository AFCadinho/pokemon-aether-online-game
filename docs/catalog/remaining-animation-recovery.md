# Remaining animation recovery (2026-09-30)

This is a diagnostic recovery checkpoint, not catalogue admission or release.
The reviewed catalogue remains 710 base species plus Mega Dragonite; 315 of
1025 base species remain unapproved. Alternative forms are outside this count.

## Re-probe results

170 previous `missing_or_ambiguous_native_actions` holds were re-probed against
the connected Biochao archives using the current action parser:

- 41 complete native action sets exported and converted into standalone scenes.
- 114 still have missing native actions.
- 15 still have competing action sets.

The selector first narrows to the proven source rig, then prefers battle idle
over default idle within the same rig and numeric bank. It never combines
competing banks. Resuming an export requires unchanged source, action mapping,
and exported bytes.

Of the 129 remaining animation holds, file-presence screening found 50 with
coherent native motion candidates in the ZA archive. These are **not** yet
identity-validated or imported. The inspected SCVI motion folder did not offer
complete replacement sets for these 129.

## Appearance preparation

41 normal scenes and 23 shiny scenes are prepared for appearance review:

- 19 pairs reconstructed from matching SCVI normal/rare material tables.
- 4 pairs reconstructed from ZA material tables: Buneary, Lopunny, Mime Jr,
  Drampa.
- 18 normals reconstructed from their own Biochao shader graphs. Shiny sources
  remain unresolved for these 18. This includes Roselia: its ZA reconstruction
  was withheld after an incorrect forehead marking was found.

Native shader cloning preserves authored group instance inputs. Base colour
and alpha are baked from the connected Principled shader graph. Spurious mask
emission is removed only when its native emission output is proven zero by baking its connected graph; nonzero
emission cases remain held. A Principled/emission mix is supported only when
that emission bake is zero. Geometry and animation
accessors must remain identical. This does not infer shiny colours.

The review page requires captures matching the exact standalone scene hashes,
rejects rendering errors or incomplete poses, and marks missing shiny variants
and missing second physical attacks explicitly. Diagnostic captures do not
certify battle scale, grounding or eye state (including closed eyes at sleep).

## Reproduce

Run from the assigned frontend slot, with the external source drive mounted:

```sh
python3 tools/sprite_factory/catalog_animation_recovery.py \
  --frontend "$PWD" --backend ../backend \
  --archives /home/adinho/Documents/3d_models/Biochao \
  --output .tmp/remaining-animation-recovery-new --workers 2 --export
```

Material reconstruction and standalone conversion use the existing material
probe and runtime tools. `catalog_animation_native_colour.py` takes pinned
candidate/source hashes and a new output directory. Never overwrite the source
archives or reuse captures from a different scene hash.

Local checkpoint artifacts live under `.tmp/remaining-animation-recovery` in
slot-a. The portable receipt in `tools/sprite_factory/` records the exact source,
GLB and scene hashes. No reviewed catalogue, release index or R2 content was
changed. Next: appearance review, repair outstanding shiny materials, then
battle qualification and individual bundles for accepted pairs.

## Appearance feedback: Sandslash and Toucannon

Both remain pending visual approval. Sandslash's black pupil channel has a
maximum decoded mask value of 29/255. The diagnostic correction increases only
that authored black-pupil channel to full coverage (gain 255/29), preserving the
other eye layers, body materials, geometry and animations. This is a visual
calibration candidate, not a claim that the original game shader uses this gain.
Both normal and shiny use the same correction and retain exact geometry parity.

Toucannon's Biochao mesh uses a different material/UV arrangement from the SCVI
texture set. Its normal is now reconstructed from its own connected source
shader graph. Its prior shiny reconstruction is withheld; a compatible shiny
source is still needed. The normal correction preserves geometry and motions.
