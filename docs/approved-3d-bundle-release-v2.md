# Prepared 3D bundle release v2

The user visually accepted all 14 normal/shiny pairs in catalog batch 01 on
26 September 2026. The exact 28 scene hashes and their shared motion profiles
are now in the reviewed game and launcher registries. The four shiny holds
(Ampharos, Larvitar, Pineco and Slowbro) remain outside this release.

`release/approved_3d_bundles_v2.json` pins the local v2 content index and 21
individual bundles. The first seven archive object keys, sizes and SHA-256
digests are identical to v1. The new bundles are Charmeleon, Dunsparce,
Flaaffy, Houndoom, Houndour, Igglybuff, Mareep, Persian, Phanpy, Skiploom,
Slowking, Stantler, Teddiursa and Ursaring. The archives total 538,924,475
bytes and the index is 18,804 bytes, for 538,943,279 bytes in all. A player
with v1 already installed needs only the 14 additions.

The local release files are under
`/home/adinho/Documents/3d_models/PokeAether/release-approved-bundles-v2`.
Regenerate them from the checked-in approval, the retained v1 files and the
retained batch-01 candidate bundles with
`python3 tools/package_approved_3d_release_v2.py V1_DIR BATCH_DIR NEW_OUTPUT_DIR NEW_RECEIPT`.
The command requires new output paths. Verify the pinned
files without uploading with:

```sh
python3 tools/publish_approved_3d_bundles.py \
  /home/adinho/Documents/3d_models/PokeAether/release-approved-bundles-v2 \
  --metadata release/approved_3d_bundles_v2.json
```

The local v1-to-v2 launcher test planned exactly 14 new downloads, retained all
seven previous archives, loaded all 42 normal/shiny scenes from the installed
store, then passed no-op, corrupt-update rollback and restart checks. A rendered
real battle loaded all 14 new pairs from that installed store without script or
renderer errors. The existing seven-bundle launcher check also passed.

## Release boundary

The deployment workflow still defaults to v1. A future authorized v2 release
must first upload and publicly verify the 22 pinned objects, then select `v2`
and rebuild the launcher in the desktop workflow. The workflow checks that all
objects exist at the expected public URLs before constructing the manifest.
Final desktop certification, promotion, upload, push and deployment remain
separate steps; this local package has not performed them. The model archives
are not in the base game build.
