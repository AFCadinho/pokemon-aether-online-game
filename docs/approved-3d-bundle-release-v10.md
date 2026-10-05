# Approved 3D catalog v10 — 58 regional and related forms

The new cohort contains 58 approved bundles and 116 normal/shiny scenes,
807,233,937 compressed bytes. Publication uses the exact files from
`regional_model_bundle_qualification.json`; no model geometry, material,
animation or battle profile changes are part of this publication task.

## Publication and activation

- `release/approved_3d_regional_58_r2_upload.json` records public GET SHA-256
  and HEAD size verification for every cohort bundle and its immutable index.
- The 809,538-byte combined v10 index preserves all 1,142 v9 bundle records and adds exactly
  the 58 cohort records. Its 1,200 bundles cover all 2,400 reviewed appearances.
- `release/approved_3d_bundles_v10_index_r2_receipt.json` records public size
  checks for all 1,200 bundles and GET hash verification for the combined index.
- Editor runs automatically select v10. Explicit launcher-provided v8/v9 indexes
  remain supported. Game and launcher share the exact v10 descriptor and pins.
- The optional full-collection planner includes all 1,200 bundles. The first-run
  collection-size snapshot includes the 58 ZIPs' actual uncompressed sizes (807,214,333 added bytes).
- The desktop workflow offers `approved_3d_release=v10` and requires
  `build_launcher=true`. Production activation requires a certified game and
  launcher release containing the v10 code and registry. Do not point older
  clients at v10: their pinned approved set does not include the new forms.

This task publishes immutable content and enables local development downloads.
It does not publish client binaries, change game/launcher versions, or replace
any active desktop manifest. Qualification receipts retain their original
historical state; publication receipts are the authority for R2 availability.

## Focused verification

```sh
python3 tools/package_approved_3d_release_v10.py
python3 tools/publish_approved_3d_index_v10.py
python3 tools/test_package_approved_3d_release_v10.py
python3 tools/test_package_approved_3d_release_v9.py
python3 tools/test_package_approved_3d_release_v8.py
python3 tools/test_launcher_download_pipeline.py
python3 tools/build_battle_visual_download_info.py --check
```

The publisher defaults to offline validation. Explicit `--apply` publishes the
immutable index after checking public bundle sizes and verifies the active
manifest is unchanged. Credentials are read in place and are never logged.

Isolated slot Godot checks cover `approved_3d_release_v10_check.gd`, the v8/v9
compatibility checks, and launcher `release_asset_bundles_v10_check.gd` with the
actual packaged descriptor. They check all 58 regional identities, exact pins,
missing/modified records, cached index reuse and the full collection plan.

All listed checks passed on 2026-10-05 with Godot 4.6.2. The launcher download
pipeline reports 10 passing tests; v8/v9 package reconstruction remains exact.
The v10 launcher check also exercises a 1,200-bundle full-download plan and
accepts the real descriptor produced by `package_launcher_release.py`.
