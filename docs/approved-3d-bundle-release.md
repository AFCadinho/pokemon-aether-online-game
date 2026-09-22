# Approved desktop 3D bundle release

This release boundary contains exactly seven independently versioned base-form
bundles: Arcanine, Articuno, Dragonite, Lucario, Pikachu, Roaring Moon and
Snorlax. Each bundle contains its approved normal and shiny scenes. The local
75-model screened catalog is not accepted by this flow.

The desktop manifest points to one immutable content index. The launcher
downloads that index, plans only the seven pinned asset IDs, uses the existing
resumable downloader and installs archives through `AssetBundleStore`. It then
passes the generated active runtime catalog to the game through the existing
`POKEAETHER_MODEL_CATALOG` environment boundary. The game remains the final
authority: its checked-in approval registry and byte-hash checks still run
before a scene is admitted.

## R2 layout

```text
optional-assets/pokemon_3d/index/
  approved-pokemon-3d-v1-<index-sha256>.json
optional-assets/pokemon_3d/<species>/base/
  v<version>-<archive-sha256>.zip
```

The pinned publication receipt is
`release/approved_3d_bundles_v1.json`. It records the index and all seven object
keys, sizes and SHA-256 digests. Build the files from an approved portable/local
catalog with:

```sh
python3 tools/package_approved_3d_release_bundles.py APPROVED_CATALOG OUTPUT_DIR
python3 tools/publish_approved_3d_bundles.py OUTPUT_DIR
```

The publisher is a dry-run unless `--apply` is passed with the existing R2
credentials. Publication is deliberately separate from the desktop deployment.
The deployment workflow refuses to publish a manifest until all eight pinned
objects already exist at the expected public URLs and sizes.

The first deployment containing this integration must rebuild/publish the
launcher (`build_launcher=true`), because older launchers ignore the new nested
index. Later game-only releases can preserve that updated launcher normally.

## Cleanup safety

The existing R2 pruner now verifies referenced content-index bytes against the
desktop manifest, protects every nested bundle object, lists only the new
`optional-assets/` allowlisted prefix, and treats each species/form as its own
rollback family. Unknown paths remain outside its deletion allowlist.

## Local release evidence

The v1 cohort contains 168,602,540 bundle bytes; the index adds 6,408 bytes.
The complete initial network transfer is therefore 168,608,948 bytes
(160.80 MiB). The game/export repository contains only the small publication
receipt and integration code; none of the bundle archives or model scenes are
part of the desktop export source.
The transactional launcher/store check proves a seven-bundle clean install,
14 normal/shiny appearances, a zero-download second plan, restart stability,
a Dragonite-only update, corrupt-update rollback and rejection of a screened
eighth species.

The existing rendered production-registry stress test was run on the generated
bundle-store catalog. Across three real immersive battles it completed 36
mixed-team switches, 21 normal duplicate/faint checks, 21 shiny variant
switch/faint/replacement checks and three battle replays. No model was read from
the old monolithic pack during that test.

No R2 upload, manifest publication, push or production deployment is performed
by these implementation/tests.
