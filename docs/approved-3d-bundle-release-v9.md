# Approved 3D catalog v9 — Galarian legendary birds

On 2026-10-05, the three approved Galarian bird bundles (normal and shiny,
67,397,765 bytes combined) and their immutable cohort index were uploaded to
R2. Every new object was downloaded through the public CDN and verified by
SHA-256 and size. See `release/approved_3d_galar_birds_r2_upload.json`.

The combined v9 index preserves every one of the 1,139 v8 records unchanged
and adds exactly Articuno Galar, Zapdos Galar and Moltres Galar. It contains
1,142 bundles and 2,284 appearances, covering the reviewed registry exactly.
The 768,804-byte index remains below the clients' 1 MiB limit. All 1,142 public
bundle sizes were checked before publication, and the new index was downloaded
and hash-verified. See `release/approved_3d_bundles_v9_index_r2_receipt.json`.

## Client selection

- Local editor runs select the published v9 project index without environment
  changes. A valid explicit launcher-provided v8 index still selects v8.
- The launcher accepts the exact v9 descriptor and hashes and can plan the full
  collection or only install the index. Earlier v8/v7 descriptors remain valid.
- The desktop release workflow now offers `approved_3d_release=v9`. Select it
  with `build_launcher=true` when publishing the next certified game/launcher
  pair. Game and launcher code must both include the new reviewed registry and
  pins before activation; current production binaries must not be pointed at
  the expanded index prematurely.
- No desktop manifest, binary, game version or launcher version was published
  by this task. Production remains on its existing content descriptor. Normal
  release certification, promotion and deployment are separate next steps.

The existing first-run collection-size snapshot was extended using the three
verified local ZIP central directories. Old bundle records and sprite packs
are unchanged; the additional installed size is 67,396,751 bytes.

## Focused checks

- `python3 tools/test_package_approved_3d_release_v9.py`: deterministic pins,
  unchanged v8 assets, exact three additions, actual launcher packaging
  descriptor, and rejection of a modified hash.
- `python3 tools/test_package_approved_3d_release_v8.py`: historical v8 still
  reconstructs identically. Its validation permits later registry additions
  while checking all original identities and hashes.
- `python3 tools/test_launcher_download_pipeline.py`: 10 checks pass.
- `python3 tools/build_battle_visual_download_info.py --check`: updated totals.
- Game `tests/approved_3d_release_v9_check.gd` and v8 equivalent: exact pins,
  normal/shiny Galar identity selection, explicit v8 support and automatic v9
  editor selection.
- Launcher `tests/release_asset_bundles_v9_check.gd`: exact set, tamper rejection,
  cached index reuse, and actual packaged descriptor acceptance without a full
  collection download; v8 equivalent also passes.

Godot checks ran in isolated slot-c with Godot 4.6.2. Installation, visual,
battle and performance qualification of the exact six model files remains
recorded in `catalog_galar_birds_bundle_qualification.json`; those files were
not rebuilt or changed for publication. One initial new launcher test had a
local-variable naming collision, corrected before all final checks passed.

## Reproducible commands

```sh
python3 tools/package_approved_3d_release_v9.py
python3 tools/publish_approved_3d_index_v9.py
python3 tools/test_package_approved_3d_release_v9.py
```

Publication scripts default to offline validation. `--apply` publishes only
immutable objects and checks that the active desktop manifest stays unchanged.
Credentials are read in place or from the environment; never copied or logged.
