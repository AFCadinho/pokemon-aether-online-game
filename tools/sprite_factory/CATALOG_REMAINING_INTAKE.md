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

## Reproduce or resume

Run the three scripts from the assigned frontend slot, passing its paired
backend, the Biochao archive directory and an output directory under `.tmp`:

1. `catalog_remaining_intake.py --frontend ... --backend ... --archives ... --output ... --probe`
2. `catalog_remaining_normal_export.py --inventory ... --probe-status ... --output ...`
3. `catalog_remaining_normal_runtime.py --export-status ... --frontend ... --slot-env ... --output ...`

All three write per-species receipts and resumable status files. They never
update `reviewed_model_catalog.json` or the launcher content index.
