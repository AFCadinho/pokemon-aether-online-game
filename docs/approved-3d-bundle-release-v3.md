# Approved 3D bundle release v3

The 55 newly approved normal/shiny species pairs passed the recorded battle
qualification and bundle preflight. Release v3 combines them with the 21
previously approved v2 species, for 76 individually versioned bundles.

The local archives total 1,879,449,027 bytes. The new v3 content index is
pinned in `release/approved_3d_bundles_v3.json` and has SHA-256
`0316830bf92f37eb9df8ddaa60b93314103b25f905482a53aabae2ef5e300d59`.

## R2 upload (26 September 2026)

The 55 new bundle objects and the v3 index were uploaded to the existing R2
bucket. The 21 unchanged v2 bundle objects were reused. A public GET of all 56
new objects returned the pinned sizes and SHA-256 hashes (1,340,591,932 bytes
verified). Details are in `release/approved_3d_bundles_v3_r2_upload.json`.

This upload did not activate the v3 index in the desktop manifest. The launcher
still selects v2 until a separate desktop release is certified and published.
The model bundles remain outside the base game build.
