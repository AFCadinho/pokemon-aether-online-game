# Approved 3D bundle release v6

Release v6 retains the 83 individually versioned v5 bundles and adds the 71
normal/shiny base-form pairs approved in catalog production batch 02. It
contains 154 bundles and 308 appearances. The 71 new archives total
1,720,015,252 bytes; unchanged v5 archives are reused byte for byte.

The pinned receipt is `release/approved_3d_bundles_v6.json`. The content-index
SHA-256 is `b91f25875905128985f46f8882059d5543e7183adbeb2b3a36326b93b70c3c60`.
The immutable archives and index are staged at
`/home/adinho/Documents/3d_models/PokeAether/release-approved-bundles-v6`.
The packager checks both batch-02 approval records, the candidate indexes,
all 71 archive hashes, and every normal/shiny hash in the reviewed game
registry. The game and launcher pin this exact index. The models stay outside
the base game export; the launcher fetches the index and the game downloads
an approved model before a battle that needs it.

Rebuild the stage from the retained local sources:

```sh
python3 tools/package_approved_3d_release_v6.py V5_DIR BATCH_02_DIR FOLLOWUP_DIR V6_DIR release/approved_3d_bundles_v6.json
python3 tools/publish_approved_3d_bundles.py V6_DIR --metadata release/approved_3d_bundles_v6.json
```

The publication dry run verified all 155 staged objects and selected only the
71 new archives plus the new index for upload: 72 objects, 1,720,151,503 bytes.
R2 upload and desktop activation remain separate steps. Select `v6` and rebuild
the launcher in the desktop workflow after the public objects verify.
