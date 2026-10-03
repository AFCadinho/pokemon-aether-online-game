# Approved 3D catalog release v8 — local candidate

The local v8 candidate combines the 18 receipt-backed cohort indexes into one
immutable index. It contains 1,139 individually versioned bundles and 2,278
normal/shiny runtime appearances, matching every identity and hash in the
reviewed model catalog. Superseded v1 bundle records resolve to their highest
approved version, including Ogerpon cloak v2 and Skarmory flight v2.

The compact index is 766,710 bytes, below both the game and launcher 1 MiB
limits. The publisher receipts confirm each source index was uploaded and did
not activate a desktop manifest. The full R2 object HEAD audit and index
publication are still pending.

Local artifacts:

- `release/approved_3d_bundles_v8_index.json` — combined content index.
- `release/approved_3d_bundles_v8.json` — pinned index and object list for the
  desktop deployment workflow.
- `data/approved_3d_release_v8.json` and
  `launcher/data/approved_3d_release_v8.json` — matching client pins.

The launcher downloads the small index as part of its update. It does not queue
all 1,139 model archives: the game downloads an individual bundle when that
Pokémon is needed for a battle. Release workflow v8 verifies that all referenced
R2 objects exist before packaging. This candidate has not been uploaded or
selected by an active desktop manifest.

Rebuild and verify the local artifacts with:

```sh
python3 tools/package_approved_3d_release_v8.py
python3 tools/test_package_approved_3d_release_v8.py
python3 tools/publish_approved_3d_index_v8.py
```

The publisher defaults to a local validation only. Its explicit `--apply` mode
checks the 1,139 existing public bundle objects and uploads just the combined
index; it does not activate the desktop manifest.
