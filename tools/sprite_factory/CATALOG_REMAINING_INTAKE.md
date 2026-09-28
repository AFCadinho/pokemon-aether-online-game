# Remaining base-species 3D intake — 2026-09-28

This intake attempted every base species outside the existing catalog and Batch
04. It does **not** add runtime entries, approve visual quality, create shiny
variants, build bundles, or publish content. The locally generated diagnostics
are under `frontend/.tmp/catalog-remaining-*` in slot-a.

## Exact scope

- The backend has 1,025 National Dex base identities. Eleven are represented
  only by form-named files; `catalog_remaining_intake.py` pins their default
  choices rather than dropping them from the count.
- The current catalog and Batch 04 cover 479 base species plus Mega Dragonite.
  This includes Batch 04's 200 still-unapproved candidate bundles.
- **546 base species remain.** Biochao Gen 1–8 archives contain a default-form
  `.blend` candidate for 525; 21 have no matching base source in those archives.

The 21 without a Biochao base source are Unown, Darmanitan Standard,
Wishiwashi, Silvally, Obstagoon, Cursola, Dipplin, Poltchageist, Sinistcha,
Okidogi, Munkidori, Fezandipiti, Ogerpon, Archaludon, Hydrapple, Gouging Fire,
Raging Bolt, Iron Boulder, Iron Crown, Terapagos and Pecharunt. A numeric `pm`
directory in the SCVI/ZA dumps is not accepted as species identity: their
resource IDs can differ from National Dex numbers. The pinned SCVI catalog has
no default-form identity entry for these 21.

## Technical run

`catalog_remaining_intake.py` mapped archive members using the Gen 6–8 developer
number CSVs, then inspected all 525 candidates in isolated Blender sessions with
embedded scripts disabled. **484 sources opened; 41 were held** because the
default rig cannot be isolated with unambiguous texture evidence or the scene
contains unsupported multi-rig content.

The old action matcher expected a filename extension. Later Biochao `.blend`
files use extensionless native action names. The matcher now accepts either form
with exact token boundaries; 271 initially empty action reports were rechecked.
The final source reports offer **300 possible normal exports** using the six
actions required by the current battle runtime. A native faint loop is included
when unambiguous; otherwise the battle controller keeps the last faint pose.
Second physical attacks are included only when the source action is unique and
belongs to the selected animation bank.

The normal export pass produced **297 GLBs**. Three remained blocked:

- Bulbasaur: its existing hash-bound visibility repair covers seven actions but
  not the newly selected second physical attack; that combination needs review.
- Liepard: the source has missing texture dependencies.
- Stakataka: its chosen sleep action is empty.

The other 225 Biochao candidates consist of 41 source holds and 184 incomplete
or ambiguous native action sets. The status files retain one reason per species.
The 297 GLBs are direct-material diagnostics; material parity and shiny assets
are not established. A previous Bulbasaur seven-action export is preserved as a
separate local diagnostic and is not counted among the 297.

Standalone Godot conversion used `catalog_remaining_normal_runtime.py` in the
assigned slot. **All 297 GLBs became independent SCNs with zero conversion
errors.** The per-species result is in
`.tmp/catalog-remaining-normal-runtime/status.json`. Exact source, GLB and SCN
hashes, actions and hold reasons are pinned in
`catalog_remaining_normal_candidates.json` (297 technical candidates, 228 review
holds, 21 missing sources). These scenes still need
normal/shiny production, material and visibility review, scale/grounding,
rendered motion checks, battle review and individual bundle qualification.

## Bulk shiny continuation — 2026-09-28

The complete 546-species remainder was sent through a conservative local shiny
material pass. Biochao source hashes, the existing normal GLB hashes, official
normal/rare material tables, and embedded normal pixels are checked before a
rare texture is used. The eight plain-albedo cases were exported by
`catalog_remaining_shiny_glb.py`. The audited review route in
`catalog_remaining_shiny_review.py` attempted the other material-backed cases
and retained explicit warnings when the older Biochao shader lacks an input
for an official rare parameter. Exact geometry and native animation parity is
required for every exported shiny GLB.

**156 normal/shiny pairs now have standalone Godot scenes**: eight simple
substitutions and 148 audited source exports. All 148 new shiny scenes
converted without Godot errors; the earlier eight also converted without
errors. Seventy-five of the 156 pairs have one or more unrepresented rare
shader parameters and need particular attention to eyes, glow, and material
colour. All 156 pairs remain technical candidates, not visually or battle
approved. The pinned per-species status, hashes, source limitations, and
remaining holds are in [catalog_remaining_shiny_results.json](catalog_remaining_shiny_results.json).

The remaining 390 consist of **141 shiny-material holds**, **228 prior source
or native-action holds**, and **21 missing base sources**. Of the 141 material
holds, 121 have no corresponding official normal/rare material tables in the
available SCVI dump. The other 20 failed explicit rare-settings, source-pixel,
or distinct-variant checks. These holds do not change any approved catalog.

Normal and shiny scenes were rendered at six poses each, 1,872 captures with
zero render errors. The local one-page visual overview is
`.tmp/catalog-remaining-156-review-2026-09-28/index.html` in slot-a. It uses
auto-fit framing; battle size, grounding, and placement still need separate
qualification. The GLBs, SCNs, captures, and run logs remain ignored local
artifacts in the assigned slot. No registry, bundle, R2 index, release, or
game default was changed.

## Reproduce or resume

Run the three scripts from the assigned frontend slot, passing its paired
backend, the Biochao archive directory and an output directory under `.tmp`:

1. `catalog_remaining_intake.py --frontend ... --backend ... --archives ... --output ... --probe`
2. `catalog_remaining_normal_export.py --inventory ... --probe-status ... --output ...`
3. `catalog_remaining_normal_runtime.py --export-status ... --frontend ... --slot-env ... --output ...`

All three write per-species receipts and resumable status files. They never
update `reviewed_model_catalog.json` or the launcher content index.
