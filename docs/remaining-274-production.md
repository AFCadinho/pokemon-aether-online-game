# Remaining 274 base Pokémon — production checkpoint

## Current checkpoint — 1 October 2026

883 ordinary species plus Mega Dragonite are approved and their complete
884-profile index is published on R2.142 ordinary species remain. The next
recovery run has12 technically exported normal candidates:8 awaiting appearance
review and4 needing further visual repairs. No new pairs have been admitted.
See `docs/catalog-remaining-142-production.md` and
`tools/sprite_factory/catalog_remaining_142_checkpoint.json`.

## Historical checkpoint — 30 September 2026

As of 2026-09-30, this production run started with 751 approved base species
plus Mega Dragonite and 274 remaining base species. The first 56 pairs are now
approved locally and individually bundled: 807 base species plus Mega Dragonite
are ready; 218 base species remain. All 56 new bundles are published to R2 and publicly verified; see
`release/approved_3d_remaining_56_r2_upload.json`.

## Current results

| State | Species |
| --- | ---: |
| Approved ZA normal/shiny pairs with installed individual bundles | 56 |
| Native Biochao normal colours restored; shiny still pending | 76 |
| Native material reconstruction held | 10 |
| DLC models located; native motion assets absent | 15 |
| Other source identity or animation recovery pending | 117 |
| Total | 274 |

The 56 pairs have 112 standalone Godot scenes with exact per-pair mesh, skin,
skeleton, transform and animation parity. The user approved their appearance,
including the corrected Panpour/Simipour eyes and the clearer Aggron view.
Battle clearance checks at 120 Hz passed for all 56 pairs. Their actual normal and
shiny camera images were visually approved by the user ("Allemaal goed"). Shiny clearance is reused
only after exact actual-SCN pair parity; every shiny camera image is rendered.

Venusaur passed its independent 120 Hz recheck (minimum clearance 0.025 m). Its native attack hid parked vines via TRACM;
those source visibility tracks are now retained. The original GLB bone hierarchy
also distorted the evaluated vine movement in Godot. Flattening the exported bone
hierarchy preserves the native movement. A fresh recovery run reproduced both
corrected GLB hashes exactly. The source Blend and source motion files are intact.
The corrected attack and battle placement were visually approved.

The 76 restored normals converted successfully to standalone scenes. Nine other
native material bakes require explicit emission reconstruction; Arctovish needs
handling a material without a base colour texture. None is admitted automatically.
Herdier's material snapshot check now compares socket position, name and type:
Blender renumbered an internal socket identifier when copying the graph, while
all actual settings and socket layouts remained unchanged. The corrected real
source bake and standalone conversion passed.

All 41 old source probe holds were reprobed. Their multiple rigs still require
explicit default-form identification. Six of these have now been recovered via
separate matching ZA default models; they are included in the 56 above.

The 15 DLC identities were matched by visually inspecting their native dump
folder icons. The model folders exist in the local SCVI dump. The available
`SV Every File/romfs/pokemon/data` dump has no corresponding motion folders.
Do not infer developer numbers from National Dex numbers or fabricate native
animation coverage.

## Evidence and reproduction

- `tools/sprite_factory/catalog_remaining_274_progress.json` records all 274
  statuses and pins current scene and evidence hashes. The first 56 entries are approved; the remaining 218 are not.
- `tools/sprite_factory/catalog_remaining_274_za_intake.json` records 56 explicit
  developer-number/default-form mappings from the historical source intake.
- Local artifacts remain under `.tmp/remaining-274-production` in slot-a.
- The appearance page is served at
  `http://127.0.0.1:8781/appearance-56-v1/index.html`.
- The intake CLI requires a fresh output directory; per-species import failures
  become holds and do not stop unrelated candidates.

Run from the assigned frontend task slot, after extracting only the mapped ZA
default-form files into a disposable source directory:

```sh
python3 tools/sprite_factory/catalog_remaining_za_production.py \
  --inventory tools/sprite_factory/catalog_remaining_274_za_intake.json \
  --source-root .tmp/remaining-274-production/za-source \
  --output .tmp/remaining-274-production/za-pairs-rerun --workers 2
```

The appearance review includes bounded source material corrections:
Vanillish restores its Fresnel layer colour/emission using the same treatment
as the approved Vanilluxe; Skarmory bakes the connected native colour/alpha
graph and applies matched official rare BaseColor input differences. Shadow
colours are outside the albedo bake. Both variants preserve geometry/motion.
Their script accepts a production root containing the original `za-pairs`:

```sh
python3 tools/sprite_factory/catalog_remaining_za_material_recovery.py \
  --production-root .tmp/remaining-274-production \
  --output .tmp/remaining-274-production/za-repairs-rerun
```

Panpour and Simipour preserve the full-resolution source expression atlas instead
of downsampling it to the constant 32-pixel eye albedo. Their geometry and native
motion remain identical. The recovery script checks the original GLB, table and
texture hashes before rebuilding either palette.

Reproduce Venusaur in a fresh disposable directory:

```sh
python3 tools/sprite_factory/catalog_remaining_venusaur_recovery.py \
  --production-root .tmp/remaining-274-production \
  --output .tmp/remaining-274-production/venusaur-rerun
```

All 56 bundles (308,385,521 bytes; 294.10 MiB) passed transactional installation,
no-op update and restart checks. Three actual battle-presenter rounds each loaded
all 56 normal/shiny pairs and exercised faint replacement in classic/stadium
arenas. Frame p95 was 16.84–16.87 ms; existing memory/stall limits passed.
`catalog_remaining_56_bundle_qualification.json` binds the complete evidence.

All 56 bundles and their immutable index were published and checked via public
GET SHA-256 and HEAD size. A complete 808-profile index also includes the newly
published Sandslash/Toucannon versions; the other 750 bundles were retained.
See `docs/approved-3d-bundles-808.md`.

Next: further recovery of the remaining 218 species. The active download manifest
and desktop release are unchanged.
