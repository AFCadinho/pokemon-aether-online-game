# Approved 3D bundle release v7

V7 retains all 154 v6 bundles and adds six approved normal/shiny pairs:
Unown, Darmanitan (standard form), Wishiwashi (solo form), Silvally (Normal
type), Obstagoon and Cursola. The new bundles contain 12 appearances and total
22,832,475 bytes. The content index contains all 160 bundles and is pinned in
`release/approved_3d_bundles_v7.json`.

Its immutable index object is
`optional-assets/pokemon_3d/index/approved-pokemon-3d-v7-2ef65ef3408bf2aa366fb5de5a087d0efd0db2aab89eec18b30fa49d28f6dfee.json`.
The six new archives and the v7 index have been uploaded. Public GET checks
verified all seven SHA-256 hashes (22,974,086 bytes); public HEAD checks
verified the sizes of all 161 objects required by the new index. The receipt is
`release/approved_3d_bundles_v7_r2_upload.json`. Desktop manifests remain on
v6 until a later launcher release selects v7.

The local release stage reuses v6 archives by hard link and copies the six new
archives from their individually qualified local bundles. Rebuild with:

```sh
python3 tools/package_approved_3d_release_v7.py V6_DIR SIX_BUNDLE_DIR V7_DIR release/approved_3d_bundles_v7.json
python3 tools/publish_approved_3d_bundles.py V7_DIR --metadata release/approved_3d_bundles_v7.json
```

The uploader selects only the new six archives and the v7 index. It checks that
the v6 object set is already pinned by its R2 upload receipt and that the six
new models match their appearance, battle and bundle approval evidence.
