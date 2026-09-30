# Approved 3D content on R2 — 30 September 2026

The immutable content catalogue contains **808 profiles / 1,616 appearances**:
807 base species plus Mega Dragonite, with normal and shiny in individual bundles.

The full current registry was matched against approved bundle appearances and
source indices. An authenticated R2 HEAD audit found 750 current bundles already
present and 58 missing: the latest 56 recovered pairs plus the qualified
Sandslash/Toucannon versions. Only those 58 bundle objects were uploaded
(366,634,054 bytes; 349.65 MiB).

## Verification

- Existing 750 bundles: fresh public HEAD size checks.
- New 58 bundles: pinned local ZIP/scene hashes, public GET SHA-256 and HEAD size.
- Complete 808-profile index: launcher `AssetBundleIndex.validate` passed;
  public GET SHA-256 and HEAD size passed.
- The active desktop manifest hash remained unchanged.

[Complete immutable content index](https://updates.pokeaether.com/optional-assets/pokemon_3d/index/approved-pokemon-3d-808-20260930-e8a09ce480495f484506a67051871ca2127152905906fdddb29f4e858ede3732.json)

Index SHA-256: `e8a09ce480495f484506a67051871ca2127152905906fdddb29f4e858ede3732`; size: 714,737 bytes.

## Receipts

- `release/approved_3d_bundles_808_index.json`
- `release/approved_3d_bundles_808_r2_upload.json` (full audit and publication)
- `release/approved_3d_remaining_56_r2_upload.json` (56 new pairs)
- `release/approved_3d_recovery_pair_r2_upload.json` (Sandslash and Toucannon)

Qualification snapshots remain unchanged; publication is recorded separately.
The publisher validates approved registry bindings and ZIP scene hashes, skips
objects already present with correct public content, and never activates a game
or launcher manifest. Example local verification:

```sh
python3 tools/publish_qualified_3d_bundles.py BUNDLE_DIRECTORY \
  --qualification tools/sprite_factory/catalog_remaining_56_bundle_qualification.json \
  --expected-count 56 --receipt-prefix approved_3d_remaining_56
```

A later desktop release can select this complete index. No game release,
launcher activation, promotion to main, or push was performed by this upload.
